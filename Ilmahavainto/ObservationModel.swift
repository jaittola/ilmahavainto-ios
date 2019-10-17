//
//  ObservationModel.swift
//  Ilmahavainto
//
//  Created by Jukka Aittola on 15/10/2019.
//  Copyright © 2019 Jukka Aittola. All rights reserved.
//

import Foundation
import MapKit
import RxSwift

class ObservationModel {
    struct Observation {
        let locationId: String
        let stationName: String
        let time: Date
        let coordinates: CLLocationCoordinate2D
        let windSpeed: Double?
        let windSpeedGust: Double?
        let windDirection: Double?
        let airTemperature: Double?
        let amountOfCloud: Double?
        let visibility: Double?
        let precipitationAmount: Double?
        let relativeHumidity: Double?

        private static let tenMinutesInSeconds = 10 * 60

        init?(_ locationId: String, _ receivedObservation: Dictionary<String, String>) {
            guard let lat = Double(receivedObservation["lat"] ?? "") else { return nil }
            guard let lon = Double(receivedObservation["long"] ?? "") else { return nil }
            guard let stationName = receivedObservation["stationName"] else { return nil }

            self.locationId = locationId
            self.coordinates = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            self.stationName = stationName
            self.windSpeed = Double(receivedObservation["windSpeed"] ?? "")
            self.windSpeedGust = Double(receivedObservation["windSpeedGust"] ?? "")
            self.windDirection = Double(receivedObservation["windDirection"] ?? "")
            self.airTemperature = Double(receivedObservation["airTemperature"] ?? "")
            self.amountOfCloud = Double(receivedObservation["amountOfCloud"] ?? "")
            self.visibility = Double(receivedObservation["visibility"] ?? "")
            self.precipitationAmount = Double(receivedObservation["precipitationAmount"] ?? "")
            self.relativeHumidity = Double(receivedObservation["relativeHumidity"] ?? "")

            if let ts = receivedObservation["time"], let tsDouble = Double(ts) {
                self.time = Date(timeIntervalSince1970: tsDouble)
            } else {
                self.time = Date()
            }
        }

        var isExpired: Bool {
            get {
                return time < Date(timeIntervalSinceNow: TimeInterval(-ObservationModel.Observation.tenMinutesInSeconds))
            }
        }
    }

    struct ObservationStreams {
        let observations: Observable<[String: [Observation]]>
        let modelStatus: Observable<ModelStatus>
        let errors: Observable<String>
    }

    enum ModelStatus {
        case Ready
        case Querying
        case RegionNotAvailable
    }

    struct CoordinateBoundaries {
        let north: Double
        let east: Double
        let south: Double
        let west: Double

        init(north: Double,
             east: Double,
             south: Double,
             west: Double) {
            self.north = north
            self.east = east
            self.south = south
            self.west = west
        }

        init(center: CLLocationCoordinate2D, viewSpan: MKCoordinateSpan) {
            south = center.latitude - viewSpan.latitudeDelta / 2
            north = center.latitude + viewSpan.latitudeDelta / 2
            west = center.longitude - viewSpan.longitudeDelta / 2
            east = center.longitude + viewSpan.longitudeDelta / 2
        }

        func isEntirelyOutside(_ region: CoordinateBoundaries) -> Bool {
            return east < region.west ||
                west > region.east ||
                north < region.south ||
                south > region.north
        }

        func restrictTo(_ region: CoordinateBoundaries) -> CoordinateBoundaries {
            return CoordinateBoundaries(north: min(north, region.north),
                                        east: min(east, region.east),
                                        south: max(south, region.south),
                                        west: max(west, region.west))
        }

        func contains(_ coordinates: CLLocationCoordinate2D) -> Bool {
            return coordinates.latitude >= south &&
                coordinates.latitude <= north &&
                coordinates.longitude >= west &&
                coordinates.longitude <= east
        }
    }

    private let boundariesSubject: PublishSubject<CoordinateBoundaries>
    private let pausedSubject: BehaviorSubject<Bool>
    private let observationsSubject: BehaviorSubject<[String: [Observation]]>
    private let errorsSubject: PublishSubject<String>
    private let modelStatusSubject: BehaviorSubject<ModelStatus>
    private let querying: BehaviorSubject<Bool>
    private let disposeBag: DisposeBag

    private let backgroundScheduler = ConcurrentDispatchQueueScheduler.init(qos: .background)

    init() {
        boundariesSubject = PublishSubject()
        pausedSubject = BehaviorSubject(value: true)
        observationsSubject = BehaviorSubject(value: [:])
        modelStatusSubject = BehaviorSubject(value: ModelStatus.Ready)
        querying = BehaviorSubject(value: false)
        errorsSubject = PublishSubject()

        disposeBag = DisposeBag()

        let polling = pausedSubject
            .distinctUntilChanged()
            .flatMapLatest { isPaused -> Observable<Bool> in
                return isPaused ?
                    Observable.just(true) :
                    Observable.concat(Observable.just(false),
                                      Observable<Int>.interval(.seconds(600), scheduler: self.backgroundScheduler).map { _ in false } ) }
        Observable.combineLatest(boundariesSubject, polling) { (boundaries, pollingPaused) in (boundaries, pollingPaused) }
            .filter { (_, pollingPaused) in !pollingPaused }
            .map { (boundaries, _) in boundaries }
            .subscribe(onNext: self.onBoundariesUpdate)
            .disposed(by: disposeBag)

        Observable
            .combineLatest(querying, boundariesSubject) { (isQuerying, boundaries) -> ModelStatus in
                if (isQuerying) {
                    return ModelStatus.Querying
                } else {
                    if (boundaries.isEntirelyOutside(ObservationModel.supportedQueryRegion)) {
                        return ModelStatus.RegionNotAvailable
                    } else {
                        return ModelStatus.Ready
                    }
                }
        }
        .distinctUntilChanged()
        .subscribe(onNext: self.modelStatusSubject.onNext)
        .disposed(by: disposeBag)
    }

    func pause() {
        pausedSubject.onNext(true)
    }

    func resume() {
        pausedSubject.onNext(false)
    }

    func observations() -> ObservationStreams {
        return ObservationStreams(observations: observationsSubject.asObservable(),
                                  modelStatus: modelStatusSubject.asObservable(),
                                  errors: errorsSubject.asObservable())
    }

    func viewLocationChanged(center: CLLocationCoordinate2D, viewSpan: MKCoordinateSpan) {
        boundariesSubject.onNext(CoordinateBoundaries(center: center, viewSpan: viewSpan))
    }

    func observation(forLocationId: String) -> Observable<[ObservationModel.Observation]> {
        return observationsSubject
            .map { observations in observations[forLocationId] ?? [] }
            .observeOn(MainScheduler.instance)
    }

    private func onBoundariesUpdate(boundaries: CoordinateBoundaries) {
        if (boundaries.isEntirelyOutside(ObservationModel.supportedQueryRegion)) {
            observationsSubject.onNext([:])
        } else {
            let url = queryURL(boundaries.restrictTo(ObservationModel.supportedQueryRegion))!
            Swift.print("=> Loading observations after map region change from URL \(url)")
            let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
                self.querying.onNext(false)
                if let localizedDescription = error?.localizedDescription {
                    self.errorsSubject.onNext(localizedDescription)
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.errorsSubject.onNext("Response is not a HTTPURLResponse")
                    return
                }
                switch (httpResponse.statusCode) {
                case 200...299:
                    break;  // Ok
                case 400...499:
                    print("Got reply with response code \(httpResponse.statusCode)")
                    return
                default:
                    self.errorsSubject.onNext("Getting observation data failed. Response code \(httpResponse.statusCode)")

                }
                if let dataValue = data {
                    let rawj = try? JSONSerialization.jsonObject(with: dataValue, options: JSONSerialization.ReadingOptions(rawValue: 0)) as Any?
                    if let obsStations = rawj as? [ String:[ Dictionary<String, String> ] ] {
                        self.observationsSubject.onNext(
                            obsStations
                                .reduce(into: Dictionary<String, [Observation]>()) { (results, keyvalue) in
                                    let (stationId, observationDictionaryArray) = keyvalue
                                    let observationValues = observationDictionaryArray
                                        .compactMap { (obs) in Observation(stationId, obs ) }
                                        .sorted { (a, b) in a.time <= b.time }
                                    results[stationId] = observationValues
                            }
                            .compactMapValues { !$0.isEmpty ? $0 : nil }
                        )
                    }
                    else {
                        self.observationsSubject.onNext([:])
                        self.errorsSubject.onNext("Bad JSON data received")
                    }
                }
            }
            self.querying.onNext(true)
            task.resume()
        }
    }

    private func queryURL(_ boundaries: CoordinateBoundaries) -> URL? {
        return URL(string: String(format: ObservationModel.apiURLFormat,
                                  boundaries.south,
                                  boundaries.north,
                                  boundaries.west,
                                  boundaries.east))
    }

    private static let supportedQueryRegion = CoordinateBoundaries(north: 70.1,
                                                                   east: 31.6,
                                                                   south: 59.35,
                                                                   west: 19.1)
    private static let apiURLFormat = "https://ilmaproxy.herokuapp.com/1/observations?lat1=%.3f&lat2=%.3f&lon1=%.3f&lon2=%.3f"
}
