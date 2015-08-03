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
    
    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        var pinAnnotationView = mapView.dequeueReusableAnnotationViewWithIdentifier("PinView") as? MKPinAnnotationView
        if (pinAnnotationView == nil) {
            pinAnnotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "PinView")
        }
        else {
            pinAnnotationView!.annotation = annotation
        }
        
        return pinAnnotationView
    }

    func loadObservations(center: CLLocationCoordinate2D, viewSpan: MKCoordinateSpan) {
        let lat1 = roundTo3(center.latitude - viewSpan.latitudeDelta / 2)
        let lat2 = roundTo3(center.latitude + viewSpan.latitudeDelta / 2)
        let lon1 = roundTo3(center.longitude - viewSpan.longitudeDelta / 2)
        let lon2 = roundTo3(center.longitude + viewSpan.longitudeDelta / 2)
        println("=> Loading observations after map region change; approx pos range \(lat1) \(lon1) ,  \(lat2), \(lon2)")
        let task = urlSession.dataTaskWithURL(NSURL(string: "https://ilmahavainto.herokuapp.com/1/observations?lat1=\(lat1)&lat2=\(lat2)&lon1=\(lon1)&lon2=\(lon2)")!,
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
    
    
    func displayObservations() {
        for a in mapView.annotations {
            mapView.removeAnnotation(a as? MKAnnotation)
        }

        if let observationDict = observations {
            for (k, observationArr) in observationDict {
                if let coordinate = makeCoordinate(observationArr[0]) {
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = coordinate
                    annotation.title = "Observation \(k)"
                    mapView.addAnnotation(annotation)
                }
            }
        }
    }
    
    func makeCoordinate(observation: [String: String]) -> CLLocationCoordinate2D? {
        var lat = observation["lat"]
        var lon = observation["long"]
        
        if lat == nil || lon == nil {
            return nil
        }
        
        return CLLocationCoordinate2D(latitude: NSString(string: lat!).doubleValue, longitude: NSString(string: lon!).doubleValue)
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
