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
        if !isFirst { // Hack, there are always two region changes after
                      // creating the view.
            loadObservations(center: center, viewSpan: viewSpan)
        }
        isFirst = false
    }
    
    @IBAction func handleAboutButtonPress(_ sender: UIButton) {
        let aboutVC = UIAlertController(title: "About this application",
                                        message: "Copyright (c) 2015-2019 jaittola@iki.fi\nWeather data source: Finnish Meteorological Institute Open Data. For details about the licensing of the weather data, see http://en.ilmatieteenlaitos.fi/open-data-licence",
                                        preferredStyle: UIAlertController.Style.actionSheet)
        aboutVC.addAction(UIAlertAction(title: "Ok", style: UIAlertAction.Style.default, handler: nil))
        self.present(aboutVC, animated: true, completion: nil)
    }
    
    func mapView(_ mapView: MKMapView, viewFor: MKAnnotation) -> MKAnnotationView? {
        var pinAnnotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "AnnotationView") as? MKPinAnnotationView
        if (pinAnnotationView == nil) {
            pinAnnotationView = MKPinAnnotationView(annotation: viewFor, reuseIdentifier: "PinView")
            pinAnnotationView!.canShowCallout = true
            let rightButton = UIButton(type: UIButton.ButtonType.detailDisclosure)
            // rightButton.addTarget(nil, action: #selector(self.pressButton(_:)), for: UIControl.Event.TouchUpInside);  // TODO: what did this do in the original code?
            pinAnnotationView!.rightCalloutAccessoryView = rightButton
        }
        else {
            pinAnnotationView!.annotation = viewFor
        }
        
        return pinAnnotationView
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        performSegue(withIdentifier: "ShowObservationStation", sender: view)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowObservationStation" {
            let annotation = (sender! as! MKAnnotationView).annotation as! ExtendedAnnotation
            if let observationVC = segue.destination as? ObservationDataViewController {
                observationVC.observationStationData = observations![annotation.locationId!]
            }
        }
    }

    func loadObservations(center: CLLocationCoordinate2D, viewSpan: MKCoordinateSpan) {
        let lat1 = roundTo3(center.latitude - viewSpan.latitudeDelta / 2)
        let lat2 = roundTo3(center.latitude + viewSpan.latitudeDelta / 2)
        let lon1 = roundTo3(center.longitude - viewSpan.longitudeDelta / 2)
        let lon2 = roundTo3(center.longitude + viewSpan.longitudeDelta / 2)
        Swift.print("=> Loading observations after map region change; approx pos range \(lat1) \(lon1) ,  \(lat2), \(lon2)")
        let url = URL(string:  "https://ilmaproxy.herokuapp.com/1/observations?lat1=\(lat1)&lat2=\(lat2)&lon1=\(lon1)&lon2=\(lon2)")
        let task = URLSession.shared.dataTask(with: url!) { (data, response, error) in
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
    
    func roundTo3(_ v: Double) -> Double {
        return Double(round(1000 * v) / 1000)
    }

    func handleObservationDataResponse(_ data: Data) {
        let rawj = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: 0)) as Any?
        if let obsStations = rawj as? [ String:[ Dictionary<String, String> ] ] {
            observations = obsStations
        }
        else {
            observations = nil
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
        if let observationDict = observations {
            for (locationKey, observationArr) in observationDict {
                let firstObservation = observationArr[0]
                if let coordinate = makeCoordinate(firstObservation) {
                    let annotation = ExtendedAnnotation()
                    let stationName = firstObservation["stationName"] ?? ""
                    annotation.coordinate = coordinate.coordinates
                    annotation.title = makeObservationText(firstObservation)
                    annotation.subtitle = "\(stationName) (\(coordinate.displayString))"
                    annotation.locationId = locationKey
                    mapView.addAnnotation(annotation)
                }
            }
        }
    }
    
    func makeCoordinate(_ observation: [String: String]) -> Coordinates? {
        let lat = observation["lat"]
        let lon = observation["long"]
        
        if lat == nil || lon == nil {
            return nil
        }
        
        return Coordinates(coordinates: CLLocationCoordinate2D(latitude: NSString(string: lat!).doubleValue, longitude: NSString(string: lon!).doubleValue),
            displayString: ObservationUtils.makeCoordinateString(lat: lat!, lon: lon!))
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
        if value == nil || value! == "NaN" {
            return ""
        }
        return String(format: "%@%@", value!, unit)
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

    var observations: [String: [Dictionary<String, String>]]?
    var isFirst = true
}
