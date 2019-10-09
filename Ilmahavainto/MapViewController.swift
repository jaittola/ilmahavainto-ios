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
        loadObservations(center: center, viewSpan: viewSpan)
    }
    
    @IBAction func handleAboutButtonPress(_ sender: UIButton) {
        let aboutVC = UIAlertController(title: "About this application",
                                        message: "Copyright (c) 2015-2019 jaittola@iki.fi\nWeather data source: Finnish Meteorological Institute Open Data. For details about the licensing of the weather data, see http://en.ilmatieteenlaitos.fi/open-data-licence\nWind icons: Wikimedia Commons, see https://commons.wikimedia.org/wiki/File:Symbol_wind_speed_01.svg",
                                        preferredStyle: UIAlertController.Style.actionSheet)
        aboutVC.addAction(UIAlertAction(title: "Ok", style: UIAlertAction.Style.default, handler: nil))
        self.present(aboutVC, animated: true, completion: nil)
    }
    
    func mapView(_ mapView: MKMapView, viewFor: MKAnnotation) -> MKAnnotationView? {
        if let pinAnnotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "PinView") as? MKPinAnnotationView {
            pinAnnotationView.annotation = viewFor
            return pinAnnotationView
        }

        let av = MKPinAnnotationView(annotation: viewFor, reuseIdentifier: "PinView")
        av.canShowCallout = true
        let rightButton = UIButton(type: UIButton.ButtonType.detailDisclosure)
        av.rightCalloutAccessoryView = rightButton
        return av
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
                    windSpeed: observation[""],
                    windDirection: observation[""])
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
}
