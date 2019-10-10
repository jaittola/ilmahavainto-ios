//
//  MapViewController.swift
//  Ilmahavainto
//
//  Created by Jukka Aittola on 03/08/15.
//  Copyright (c) 2015 Jukka Aittola. All rights reserved.
//

import UIKit
import MapKit

class MapViewController: UIViewController, MKMapViewDelegate {
    @IBOutlet weak var mapView: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        let center = CLLocationCoordinate2D(latitude: 60.2, longitude: 25.0)
        let coordinateSpan = MKCoordinateSpan(latitudeDelta: 0.6, longitudeDelta: 1.0)
        mapView.setRegion(MKCoordinateRegion(center: center, span: coordinateSpan),
            animated: false)
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        let viewSpan = mapView.region.span
        let center = mapView.region.center
        if !animated {
            loadObservations(center: center, viewSpan: viewSpan)
        }
    }
    
    @IBAction func handleAboutButtonPress(_ sender: UIButton) {
        let aboutVC = UIAlertController(title: "About this application",
                                        message: "Copyright (c) 2015-2019 jaittola@iki.fi\nWeather data source: Finnish Meteorological Institute Open Data. For details about the licensing of the weather data, see http://en.ilmatieteenlaitos.fi/open-data-licence\nWind icons: Wikimedia Commons, see https://commons.wikimedia.org/wiki/File:Symbol_wind_speed_01.svg",
                                        preferredStyle: UIAlertController.Style.actionSheet)
        aboutVC.addAction(UIAlertAction(title: "Ok", style: UIAlertAction.Style.default, handler: nil))
        self.present(aboutVC, animated: true, completion: nil)
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
        if segue.identifier == "ShowObservationStation" {
            if let annotation = (sender as? MKAnnotationView)?.annotation as? ObservationAnnotation {
                (segue.destination as? ObservationDataViewController)?.observationStationData = observations[annotation.locationId]
            }
        }
    }

    func loadObservations(center: CLLocationCoordinate2D, viewSpan: MKCoordinateSpan) {
        let lat1 = roundTo3(center.latitude - viewSpan.latitudeDelta / 2)
        let lat2 = roundTo3(center.latitude + viewSpan.latitudeDelta / 2)
        let lon1 = roundTo3(center.longitude - viewSpan.longitudeDelta / 2)
        let lon2 = roundTo3(center.longitude + viewSpan.longitudeDelta / 2)
        if let url = URL(string:  "https://ilmaproxy.herokuapp.com/1/observations?lat1=\(lat1)&lat2=\(lat2)&lon1=\(lon1)&lon2=\(lon2)") {
            Swift.print("=> Loading observations after map region change; approx pos range \(lat1) \(lon1) ,  \(lat2), \(lon2) from URL \(url)")
            let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
                if let localizedDescription = error?.localizedDescription {
                    self.showAlert(localizedDescription)
                }
                guard let httpResponse = response as? HTTPURLResponse,
                    (200...299).contains(httpResponse.statusCode) else {
                        self.showAlert("Getting observation data failed ")
                        return
                }
                if let dataValue = data {
                    self.handleObservationDataResponse(dataValue)
                }
            }
            task.resume()
        }
    }
    
    func roundTo3(_ v: Double) -> Double {
        return Double(round(1000 * v) / 1000)
    }

    func handleObservationDataResponse(_ data: Data) {
        let rawj = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: 0)) as Any?
        if let obsStations = rawj as? [ String:[ Dictionary<String, String> ] ] {
            observations = obsStations
        }
        else {
            observations = [:]
            showAlert("Bad JSON data received")
        }
        
        DispatchQueue.main.async {
            self.displayObservations()
        }
    }
    
    struct Coordinates {
        init(coordinates: CLLocationCoordinate2D, displayString: String) {
            self.coordinates = coordinates
            self.displayString = displayString
        }
        
        let coordinates: CLLocationCoordinate2D
        let displayString: String
    }
    
    
    func displayObservations() {
        mapView.removeAnnotations(mapView.annotations)
        for (locationKey, observationArr) in observations {
            guard let observation = observationArr.last else { continue }
            guard let coordinate = makeCoordinate(observation) else { continue }
            let annotation = ObservationAnnotation(
                    coordinate: coordinate.coordinates,
                    title: makeObservationText(observation),
                    subtitle: observation["stationName"] ?? "",
                    locationId: locationKey,
                    windSpeed: observation["windSpeed"],
                    windDirection: observation["windDirection"])
            mapView.addAnnotation(annotation)
        }
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

    var observations: [String: [Dictionary<String, String>]] = [:]
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
