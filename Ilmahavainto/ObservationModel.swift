//
//  ObservationModel.swift
//  Ilmahavainto
//
//  Created by Jukka Aittola on 15/10/2019.
//  Copyright © 2019 Jukka Aittola. All rights reserved.
//

import Foundation
import MapKit

protocol ObservationModelDelegate {
    func onError(_ message: String)
    func onDisplayObservations(_ observations: [String: [ObservationModel.Observation]])
}

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

    private let delegate: ObservationModelDelegate
    private var observations: [String: [Observation]] = [:]

    init(_ delegate: ObservationModelDelegate) {
        self.delegate = delegate
    }

    func loadObservations(center: CLLocationCoordinate2D, viewSpan: MKCoordinateSpan) {
        let boundaries = CoordinateBoundaries(center: center, viewSpan: viewSpan)
        if (boundaries.isEntirelyOutside(ObservationModel.supportedQueryRegion)) {
            self.handleObservationDataResponse("{}".data(using: .utf8)!)
        } else {
            let url = boundaries.restrictTo(ObservationModel.supportedQueryRegion).queryURL()!
            Swift.print("=> Loading observations after map region change from URL \(url)")
            let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
                if let localizedDescription = error?.localizedDescription {
                    self.delegate.onError(localizedDescription)
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.delegate.onError("Response is not a HTTPURLResponse")
                    return
                }
                switch (httpResponse.statusCode) {
                case 200...299:
                    break;  // Ok
                case 400...499:
                    print("Got reply with response code \(httpResponse.statusCode)")
                    return
                default:
                    self.delegate.onError("Getting observation data failed. Response code \(httpResponse.statusCode)")

                }
                if let dataValue = data {
                    self.handleObservationDataResponse(dataValue)
                }
            }
            task.resume()
        }
    }

    func observation(forLocationId: String) -> [Observation]? {
        return observations[forLocationId]
    }

    private func handleObservationDataResponse(_ data: Data) {
        let rawj = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: 0)) as Any?
        if let obsStations = rawj as? [ String:[ Dictionary<String, String> ] ] {
            observations = obsStations
                .reduce(into: Dictionary<String, [Observation]>()) { (results, keyvalue) in
                    let (stationId, observationDictionaryArray) = keyvalue
                    let observationValues = observationDictionaryArray
                        .compactMap { (obs) in Observation(stationId, obs ) }
                        .sorted { (a, b) in a.time <= b.time }
                    results[stationId] = observationValues
            }
            .compactMapValues { !$0.isEmpty ? $0 : nil }
        }
        else {
            observations = [:]
            delegate.onError("Bad JSON data received")
        }

        DispatchQueue.main.async {
            self.delegate.onDisplayObservations(self.observations)
        }
    }

    private func roundTo3(_ v: Double) -> Double {
        return Double(round(1000 * v) / 1000)
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

        func queryURL() -> URL? {
            return URL(string: String(format: ObservationModel.apiURLFormat, south, north, west, east))
        }
    }

    static let supportedQueryRegion = CoordinateBoundaries(north: 70.1,
                                                           east: 31.6,
                                                           south: 59.35,
                                                           west: 19.1)
    static let apiURLFormat = "https://ilmaproxy.herokuapp.com/1/observations?lat1=%.3f&lat2=%.3f&lon1=%.3f&lon2=%.3f"
}
