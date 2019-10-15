//
//  MapViewController.swift
//  Ilmahavainto
//
//  Created by Jukka Aittola on 03/08/15.
//  Copyright (c) 2015 Jukka Aittola. All rights reserved.
//

import UIKit
import MapKit

class MapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate, ObservationModelDelegate {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var locateButton: UIButton!

    @IBAction func handleLocateButtonPress(_ sender: Any) {
        guard let mv = mapView else { return }
        mv.setCenter(mv.userLocation.coordinate, animated: true)
    }

    private var locationManager: CLLocationManager? = nil
    private var model: ObservationModel? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        model = ObservationModel(self)
        let center = CLLocationCoordinate2D(latitude: 60.2, longitude: 25.0)
        let coordinateSpan = MKCoordinateSpan(latitudeDelta: 0.6, longitudeDelta: 1.0)
        mapView.setRegion(MKCoordinateRegion(center: center, span: coordinateSpan),
            animated: false)
        setupLocationUpdates()
    }

    override func viewWillAppear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(true, animated: false)
        locationManager?.startUpdatingLocation()
    }

    override func viewWillDisappear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(false, animated: false)
        locationManager?.stopUpdatingLocation()
    }

    private func setupLocationUpdates() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.requestWhenInUseAuthorization()
        locationManager?.startUpdatingLocation()
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
        model?.loadObservations(center: mapView.region.center, viewSpan: mapView.region.span)
    }

    func mapView(_ mapView: MKMapView, viewFor: MKAnnotation) -> MKAnnotationView? {
        guard let observationAnnotation = viewFor as? ObservationAnnotation else { return nil }
        if observationAnnotation.windSpeed >= minWindSpeed {
            return createWindBarbAnnotation(observationAnnotation)
        } else {
            return createPinAnnotation(observationAnnotation)
        }
    }

    private func createWindBarbAnnotation(_ observationAnnotation: ObservationAnnotation) -> MKAnnotationView {
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
        annotationView.image = createWindBarbImage(observationAnnotation)
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
    
    private func createWindBarbImage(_ annotation: ObservationAnnotation) -> UIImage? {
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

        return UIImage(named: barbImage(windSpeed: annotation.windSpeed))?.rotate(degrees: annotation.windDirection - 90.0)  // The barb images point to east
    }

    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        performSegue(withIdentifier: "ShowObservationStation", sender: view)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let theModel = model else { return }

        if segue.identifier == "ShowObservationStation" {
            if let annotation = (sender as? MKAnnotationView)?.annotation as? ObservationAnnotation {
                (segue.destination as? ObservationDataViewController)?.observationStationData = theModel.observation(forLocationId: annotation.locationId)
            }
        }
    }

    func onError(_ message: String) {
        showAlert(message)
    }

    struct Coordinates {
        init(coordinates: CLLocationCoordinate2D, displayString: String) {
            self.coordinates = coordinates
            self.displayString = displayString
        }
        
        let coordinates: CLLocationCoordinate2D
        let displayString: String
    }
    
    
    func onDisplayObservations(_ observations: [String: [Dictionary<String, String>]]) {
        let newAnnotations = observations
            .map { (locationKey, observationArr) -> ObservationAnnotation? in
                    guard let observation = observationArr.last else { return nil }
                    guard let coordinate = makeCoordinate(observation) else { return nil }
                    return ObservationAnnotation(
                            coordinate: coordinate.coordinates,
                            title: makeObservationText(observation),
                            subtitle: observation["stationName"] ?? "",
                            locationId: locationKey,
                            windSpeed: observation["windSpeed"],
                            windDirection: observation["windDirection"],
                            timestamp: observation["time"])
                }
            .compactMap { $0 }
        let newAnnotationsMap = newAnnotations.reduce(into: [String: ObservationAnnotation]()) { (dict: inout [String: ObservationAnnotation], observation: ObservationAnnotation) in
            dict[observation.locationId] = observation
        }

        struct AnnotationModifications {
            var toRemove: [ObservationAnnotation] = []
            var idsToRetain: [String] = []
        }

        let currentAnnotations: [ObservationAnnotation] = mapView.annotations.map { (annotation) -> ObservationAnnotation? in annotation as? ObservationAnnotation }.compactMap { $0 }
        let annotationModifications = currentAnnotations.reduce(into: AnnotationModifications()) { (modifications: inout AnnotationModifications, annotation: ObservationAnnotation) in
            let isOutsideBounds = !mapView.visibleMapRect.contains(MKMapPoint(annotation.coordinate))
            let isOutdated = annotation.timestamp < (newAnnotationsMap[annotation.locationId]?.timestamp ?? annotation.timestamp)
            if (isOutsideBounds || isOutdated) {
                modifications.toRemove.append(annotation)
            } else {
                modifications.idsToRetain.append(annotation.locationId)
            }
        }
        let toAdd = newAnnotations.filter { !annotationModifications.idsToRetain.contains($0.locationId) }
        mapView.removeAnnotations(annotationModifications.toRemove)
        mapView.addAnnotations(toAdd)
    }
    
    func makeCoordinate(_ observation: [String: String]) -> Coordinates? {
        guard let lat = observation["lat"] else { return nil }
        guard let lon = observation["long"] else { return nil }
        
        return Coordinates(coordinates: CLLocationCoordinate2D(latitude: NSString(string: lat).doubleValue, longitude: NSString(string: lon).doubleValue),
            displayString: ObservationUtils.makeCoordinateString(lat: lat, lon: lon))
    }
    
    
    func makeObservationText(_ observation: [String: String]) -> String {
        let airTemperature = observationValue(observation["airTemperature"], unit: "°C ")
        let avgWindSpeed = observationValue(observation["windSpeed"], unit: " m/s ")
        let gws = observationValue(observation["windSpeedGust"], unit: " m/s")
        let gustWindSpeed = gws != "" ? "(\(gws)) " : ""
        let wd = ObservationUtils.windDirection(observation["windDirection"])
        let windDirection = wd != "" ? wd + " " : ""
        let result = "\(airTemperature)\(windDirection)\(avgWindSpeed)\(gustWindSpeed)"
        return result != "" ? result : "(No temperature & wind data)"
    }
    
    func observationValue(_ value: String?, unit: String = "") -> String {
        guard let v = value else { return "" }
        return String(format: "%@%@", v, unit)
    }
    
    func showAlert(_ message: String) {
        DispatchQueue.main.async {
            let alertVC = UIAlertController(title: "Error loading data",
                                            message: message,
                                            preferredStyle: UIAlertController.Style.alert)
            alertVC.addAction(UIAlertAction(title: "Ok", style: UIAlertAction.Style.cancel, handler: nil))
            self.present(alertVC, animated: true, completion: nil)
        }
    }

    let minWindSpeed = 0.01
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
