//
//  MapViewController.swift
//  Ilmahavainto
//
//  Created by Jukka Aittola on 03/08/15.
//  Copyright (c) 2015-2019 Jukka Aittola. All rights reserved.
//

import UIKit
import MapKit
import RxSwift

class MapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var locateButton: UIButton!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var outsideBoundsLabel: UILabel!
    @IBOutlet weak var timestampLabel: UILabel!
    @IBOutlet weak var timeSelector: UIStepper!

    @IBAction func handleLocateButtonPress(_ sender: Any) {
        guard let mv = mapView else { return }
        mv.setCenter(mv.userLocation.coordinate, animated: true)
    }

    @IBAction func onObservationTimeSelected(_ sender: Any) {
        setSelectedTimestampFromIndex(Int(timeSelector.value))
    }

    private let defaultCenter = CLLocationCoordinate2D(latitude: 60.2, longitude: 25.0)
    private let defaultCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0.6, longitudeDelta: 1.0)

    private var locationManager: CLLocationManager? = nil
    private var modelSubscriptions: DisposeBag? = nil
    private var boundsSubject: BehaviorSubject<ObservationModel.CoordinateBoundaries>? = nil
    private var selectedObservationTimestamp = BehaviorSubject<Date>(value: Date.distantPast)
    private var observationTimestampsSubject = BehaviorSubject<[Date]>(value: [])

    override func viewDidLoad() {
        super.viewDidLoad()
        boundsSubject = BehaviorSubject(value: ObservationModel.CoordinateBoundaries(center: defaultCenter, viewSpan: defaultCoordinateSpan))
        mapView.delegate = self
        timestampLabel.text = ""
        timeSelector.maximumValue = 0
        mapView.setRegion(MKCoordinateRegion(center: defaultCenter, span: defaultCoordinateSpan),
                          animated: false)
        setupLocationUpdates()
    }

    override func viewWillAppear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(true, animated: false)
        modelSubscriptions = subscribeToObservations()
        locationManager?.startUpdatingLocation()
    }

    override func viewWillDisappear(_ animated: Bool) {
        locationManager?.stopUpdatingLocation()
        modelSubscriptions = nil
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch (status) {
        case .authorizedAlways, .authorizedWhenInUse:
            locateButton.isEnabled = true
        default:
            locateButton.isEnabled = false
            break
        }
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        boundsSubject?.onNext(ObservationModel.CoordinateBoundaries(center: mapView.region.center, viewSpan: mapView.region.span))
    }

    func mapView(_ mapView: MKMapView, viewFor: MKAnnotation) -> MKAnnotationView? {
        guard let observationAnnotation = viewFor as? ObservationAnnotation else { return nil }
        if let windSpeed = observationAnnotation.observation.windSpeed,
            let windDirection = observationAnnotation.observation.windDirection {
            return createWindBarbAnnotation(observationAnnotation,
                                            barbImage: createWindBarbImage(windSpeed: windSpeed, windDirection: windDirection))
        } else {
            return createPinAnnotation(observationAnnotation)
        }
    }


    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        performSegue(withIdentifier: "ShowObservationStation", sender: view)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowObservationStation" {
            if let annotation = (sender as? MKAnnotationView)?.annotation as? ObservationAnnotation,
                let destination = segue.destination as? ObservationDataViewController,
                let timestamp = try? selectedObservationTimestamp.value() {
                destination.setObservationDetails(stationId: annotation.observation.locationId, timestamp: timestamp)
            }
        }
    }

    private func setupLocationUpdates() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.requestWhenInUseAuthorization()
        locationManager?.startUpdatingLocation()
    }

    private func subscribeToObservations() -> DisposeBag {
        let subscriptions = DisposeBag()
        let modelItems = Globals.model().observations()
        modelItems.modelStatus
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: onModelStatusChanged)
            .disposed(by: subscriptions)
        modelItems.errors
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: onError)
            .disposed(by: subscriptions)
        let observationsInView = modelItems.observations
            .withLatestFrom(boundsSubject!) { (observations, bounds) in
                observations
                    .filter { (key, obsArray) in
                        if let coordinates = obsArray.first?.coordinates {
                            return bounds.contains(coordinates)
                        } else {
                            return false
                        } } }
        observationsInView
            .map { [[ObservationModel.Observation]]($0.values).flatMap { $0 } }
            .map { observationArr in Array(Set(observationArr.map { $0.time })).sorted() }
            .withLatestFrom(selectedObservationTimestamp) { timestamps, selectedTimestamp in (timestamps, selectedTimestamp) }
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { (timestamps, selectedTimestamp) in
                let c = max(timestamps.count - 1, 0)
                self.timeSelector.maximumValue = Double(c)
                self.observationTimestampsSubject.onNext(timestamps)
                if let idx = timestamps.firstIndex(of: selectedTimestamp) {
                    self.timeSelector.value = Double(idx)
                    self.setSelectedTimestampFromIndex(idx)
                } else {
                    self.timeSelector.value = Double(c)
                    self.setSelectedTimestampFromIndex(c)
                } })
            .disposed(by: subscriptions)
        Observable.combineLatest(observationsInView, selectedObservationTimestamp) { (observationsDict, timestamp) in
            observationsDict.values
                .flatMap { observations in observations.filter { $0.time == timestamp } } }
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: onDisplayObservations)
            .disposed(by: subscriptions)
        selectedObservationTimestamp
            .map { timestamp in
                if (timestamp != Date.distantPast) {
                    let date = DateFormatter.localizedString(from: timestamp,
                                                             dateStyle: DateFormatter.Style.short,
                                                             timeStyle: DateFormatter.Style.short)
                    let obsTitle = NSLocalizedString("Observations at", comment: "")
                    return "\(obsTitle) \(date)"
                } else {
                    return ""
                } }
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { self.timestampLabel.text = $0 } )
            .disposed(by: subscriptions)
        boundsSubject?.subscribe(onNext: { Globals.model().viewLocationChanged($0) })
            .disposed(by: subscriptions)
        return subscriptions
    }

    private func setSelectedTimestampFromIndex(_ index: Int) {
        _ = observationTimestampsSubject
            .take(1)
            .map { dates in
                (!dates.isEmpty && (0..<dates.count).contains(index)) ?
                    dates[index] : Date.distantPast }
            .subscribe(onNext: selectedObservationTimestamp.onNext)
    }

    private func createWindBarbAnnotation(_ observationAnnotation: ObservationAnnotation,
                                          barbImage: UIImage?) -> MKAnnotationView {
        func createOrReuseBarbAnnotationView(_ observationAnnotation: ObservationAnnotation) -> MKAnnotationView {
            let reuseIdentifier = "BarbView"
            if let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) {
                annotationView.annotation = observationAnnotation
                return annotationView
            } else {
                return MKAnnotationView(annotation: observationAnnotation, reuseIdentifier: reuseIdentifier)
            }
        }

        let annotationView = createOrReuseBarbAnnotationView(observationAnnotation)
        annotationView.canShowCallout = true
        let rightButton = UIButton(type: UIButton.ButtonType.detailDisclosure)
        annotationView.rightCalloutAccessoryView = rightButton
        annotationView.image = barbImage
        return annotationView
    }

    private func createPinAnnotation(_ observationAnnotation: ObservationAnnotation) -> MKAnnotationView {
        let reuseIdentifier = "PinView"
        if let pinAnnotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) as? MKPinAnnotationView {
            pinAnnotationView.annotation = observationAnnotation
            return pinAnnotationView
        }

        let av = MKPinAnnotationView(annotation: observationAnnotation, reuseIdentifier: reuseIdentifier)
        av.canShowCallout = true
        let rightButton = UIButton(type: UIButton.ButtonType.detailDisclosure)
        av.rightCalloutAccessoryView = rightButton
        return av
    }
    
    private func createWindBarbImage(windSpeed: Double, windDirection: Double) -> UIImage? {
        func barbImage(windSpeed: Double) -> String {
            let idx = Int((windSpeed / 2.5).rounded())
            switch (idx) {
            case ..<0:
                return "wind_speed_00"
            case 0:
                return "wind_speed_01"
            case 1...12:
                return String(format: "wind_speed_%02d", idx)
            default:
                return "wind_speed_12"
            }
        }

        return UIImage(named: barbImage(windSpeed: windSpeed))?.rotate(degrees: windDirection - 90.0)  // The barb images point to east
    }

    private func onError(_ message: String) {
        showAlert(message)
    }

    private func onDisplayObservations(_ observations: [ObservationModel.Observation]) {
        let newAnnotations = observations
            .map { observation in
                return ObservationAnnotation(title: makeObservationText(observation),
                                             subtitle: observation.stationName,
                                             observation: observation) }
            .compactMap { $0 }
        let newAnnotationsMap = newAnnotations.reduce(into: [String: ObservationAnnotation]()) { (dict: inout [String: ObservationAnnotation], annotation: ObservationAnnotation) in
            dict[annotation.observation.locationId] = annotation
        }

        struct AnnotationModifications {
            var toRemove: [ObservationAnnotation] = []
            var idsToRetain: [String] = []
        }

        let currentAnnotations: [ObservationAnnotation] = mapView.annotations.map { annotation -> ObservationAnnotation? in annotation as? ObservationAnnotation }.compactMap { $0 }
        let annotationModifications = currentAnnotations.reduce(into: AnnotationModifications()) { (modifications: inout AnnotationModifications, annotation: ObservationAnnotation) in
            let isOutsideBounds = !mapView.visibleMapRect.contains(MKMapPoint(annotation.coordinate))
            let isOfDifferentTime = annotation.observation.time != (newAnnotationsMap[annotation.observation.locationId]?.observation.time ?? annotation.observation.time)
            if (isOutsideBounds || isOfDifferentTime) {
                modifications.toRemove.append(annotation)
            } else {
                modifications.idsToRetain.append(annotation.observation.locationId)
            }
        }
        let toAdd = newAnnotations.filter { (ann) in !annotationModifications.idsToRetain.contains(ann.observation.locationId) }
        mapView.removeAnnotations(annotationModifications.toRemove)
        mapView.addAnnotations(toAdd)
    }

    private func onModelStatusChanged(_ status: ObservationModel.ModelStatus) {
        switch (status) {
        case .Ready:
            loadingIndicator?.stopAnimating()
            outsideBoundsLabel?.isHidden = true
        case .Querying:
            loadingIndicator?.startAnimating()
        case .RegionNotAvailable:
            loadingIndicator?.stopAnimating()
            outsideBoundsLabel?.isHidden = false
        }
    }
    
    private func makeObservationText(_ observation: ObservationModel.Observation) -> String {
        let airTemperature = observationValue(observation.airTemperature, unit: "°C ")
        let avgWindSpeed = observationValue(observation.windSpeed, unit: " m/s ")
        let gws = observationValue(observation.windSpeedGust, unit: " m/s")
        let gustWindSpeed = gws != "" ? "(\(gws)) " : ""
        let wd = ObservationUtils.windDirection(observation.windDirection)
        let windDirection = wd != nil ? wd! + " " : ""
        let result = "\(airTemperature)\(windDirection)\(avgWindSpeed)\(gustWindSpeed)"
        return result != "" ? result : "(No temperature & wind data)"
    }
    
    private func observationValue(_ value: Double?, unit: String = "") -> String {
        guard let v = value else { return "" }
        return String(format: "%0.1f%@", v, unit)
    }
    
    private func showAlert(_ message: String) {
        DispatchQueue.main.async {
            let alertVC = UIAlertController(title: "Error loading data",
                                            message: message,
                                            preferredStyle: UIAlertController.Style.alert)
            alertVC.addAction(UIAlertAction(title: "Ok", style: UIAlertAction.Style.cancel, handler: nil))
            self.present(alertVC, animated: true, completion: nil)
        }
    }
}

// http://danlec.com/st4k#questions/27092354
extension UIImage {
    func rotate(degrees: Double) -> UIImage? {
        let radians = degrees * Double.pi / 180.0
        var newSize = CGRect(origin: CGPoint.zero, size: self.size).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        let context = UIGraphicsGetCurrentContext()!

        // Move origin to middle
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: CGFloat(radians))
        // Draw the image at its center
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }
}
