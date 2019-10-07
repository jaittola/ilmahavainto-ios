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

    func mapView(mapView: MKMapView!, regionDidChangeAnimated animated: Bool) {
        let viewSpan = mapView.region.span
        let center = mapView.region.center
        if !isFirst { // Hack, there are always two region changes after
                      // creating the view.
            loadObservations(center, viewSpan: viewSpan)
        }
        isFirst = false
    }
    
    @IBAction func handleAboutButtonPressed(sender: AnyObject) {
        var aboutVC = UIAlertController(title: "About this application",
                message: "Copyright (c) 2015 jaittola@iki.fi\nWeather data source: Finnish Meteorological Institute Open Data. For details about the licensing of the weather data, see http://en.ilmatieteenlaitos.fi/open-data-licence",
                preferredStyle: UIAlertControllerStyle.ActionSheet)
        aboutVC.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: nil))
        self.presentViewController(aboutVC, animated: true, completion: nil)
    }
    
    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        var pinAnnotationView = mapView.dequeueReusableAnnotationViewWithIdentifier("AnnotationView") as? MKPinAnnotationView
        if (pinAnnotationView == nil) {
            pinAnnotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "PinView")
            pinAnnotationView!.canShowCallout = true
            var rightButton = UIButton.buttonWithType(UIButtonType.DetailDisclosure) as! UIButton
            rightButton.addTarget(nil, action: nil, forControlEvents: UIControlEvents.TouchUpInside);
            pinAnnotationView!.rightCalloutAccessoryView = rightButton
        }
        else {
            pinAnnotationView!.annotation = annotation
        }
        
        return pinAnnotationView
    }
    
    func mapView(mapView: MKMapView!, annotationView view: MKAnnotationView!, calloutAccessoryControlTapped control: UIControl!) {
        performSegueWithIdentifier("ShowObservationStation", sender: view)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ShowObservationStation" {
            let annotation = (sender! as! MKAnnotationView).annotation as! ExtendedAnnotation
            if let observationVC = segue.destinationViewController as? ObservationDataViewController {
                observationVC.observationStationData = observations![annotation.locationId!]
            }
        }
    }

    func loadObservations(center: CLLocationCoordinate2D, viewSpan: MKCoordinateSpan) {
        let lat1 = roundTo3(center.latitude - viewSpan.latitudeDelta / 2)
        let lat2 = roundTo3(center.latitude + viewSpan.latitudeDelta / 2)
        let lon1 = roundTo3(center.longitude - viewSpan.longitudeDelta / 2)
        let lon2 = roundTo3(center.longitude + viewSpan.longitudeDelta / 2)
        println("=> Loading observations after map region change; approx pos range \(lat1) \(lon1) ,  \(lat2), \(lon2)")
        let task = urlSession.dataTaskWithURL(NSURL(string: "https://ilmaproxy.herokuapp.com/1/observations?lat1=\(lat1)&lat2=\(lat2)&lon1=\(lon1)&lon2=\(lon2)")!,
            completionHandler: { (data: NSData!, response: NSURLResponse!, error: NSError!) -> Void in
                if error != nil {
                    self.showAlert(error.localizedDescription)
                }
                else if let dataValue = data {
                    self.handleObservationDataResponse(dataValue, response: response, error: error)
                }
        })
        task.resume()
    }
    
    func roundTo3(v: Double) -> Double {
        return Double(round(1000 * v) / 1000)
    }

    func handleObservationDataResponse(data: NSData!, response: NSURLResponse!, error: NSError!) {
        var jsonError: NSError? = nil
        var rawj: AnyObject? = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(0), error: &jsonError)
        if let je = jsonError {
            showAlert("Bad JSON data received: \(jsonError!.localizedDescription)")
            return
        }
        if let obsStations = rawj as? [ String:[ Dictionary<String, String> ] ] {
            observations = obsStations
        }
        else {
            observations = nil
        }
        
        dispatch_async(dispatch_get_main_queue(), {
            () -> Void in self.displayObservations()
        })
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
    
    func makeCoordinate(observation: [String: String]) -> Coordinates? {
        var lat = observation["lat"]
        var lon = observation["long"]
        
        if lat == nil || lon == nil {
            return nil
        }
        
        return Coordinates(coordinates: CLLocationCoordinate2D(latitude: NSString(string: lat!).doubleValue, longitude: NSString(string: lon!).doubleValue),
            displayString: ObservationUtils.makeCoordinateString(lat: lat!, lon: lon!))
    }
    
    
    func makeObservationText(observation: [String: String]) -> String {
        let airTemperature = observationValue(observation["airTemperature"], unit: "°C ")
        let avgWindSpeed = observationValue(observation["windSpeed"], unit: " m/s ")
        let gws = observationValue(observation["windSpeedGust"], unit: " m/s")
        let gustWindSpeed = gws != "" ? "(\(gws)) " : ""
        let wd = ObservationUtils.windDirection(observation["windDirection"])
        let windDirection = wd != "" ? wd + " " : ""
        let result = "\(airTemperature)\(windDirection)\(avgWindSpeed)\(gustWindSpeed)"
        return result != "" ? result : "(No temperature & wind data)"
    }
    
    func observationValue(value: String?, unit: String = "") -> String {
        if value == nil || value! == "NaN" {
            return ""
        }
        return String(format: "%@%@", value!, unit)
    }
    
    func showAlert(message: String) {
        dispatch_async(dispatch_get_main_queue(), {
            var alertVC = UIAlertController(title: "Error loading data",
                message: message,
                preferredStyle: UIAlertControllerStyle.Alert)
            alertVC.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Cancel, handler: nil))
            self.presentViewController(alertVC, animated: true, completion: nil)
        })
    }

    let urlSession = NSURLSession.sharedSession()
    var observations: [String: [Dictionary<String, String>]]?
    var isFirst = true
}
