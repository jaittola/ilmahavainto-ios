//
//  ObservationDataViewController
//  Ilmahavainto
//
//  Created by Jukka Aittola on 31/07/15.
//  Copyright (c) 2015 Jukka Aittola. All rights reserved.
//

import UIKit

class ObservationDataViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        loadObservations()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func loadObservations() {
        let task = urlSession.dataTaskWithURL(NSURL(string: "https://ilmahavainto.herokuapp.com/1/observations?lat1=59.5&lat2=60.5&lon1=24.8&lon2=25.5")!,
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
    
    func handleObservationDataResponse(data: NSData!, response: NSURLResponse!, error: NSError!) {
        var jsonError: NSError? = nil
        var rawj: AnyObject? = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(0), error: &jsonError)
        if let je = jsonError {
            showAlert("Bad JSON data received: \(jsonError!.localizedDescription)")
            return
        }
        if let obsStations = rawj as? [ String:[ Dictionary<String, String> ] ] {
            let interestingObservations = obsStations["60.20307,24.96130"]?.last
            if let obs = interestingObservations {
                self.updateObservations(obs)
            }
            else {
                updateObservations([String:String]())
            }
        }
    }
    
    func updateObservations(observations: [String: String]) {
        displayArray.removeAll(keepCapacity: true)
        for m in observationMappings {
            if let observation = observations[m.parameter] {
                if (observation != "NaN") {
                    let t = m.title  // ??
                    displayArray.append((t, m.format(value: observation)))
                }
            }
        }
        updateObservationCoordinates(observations["lat"]!, longitude: observations["long"]!)
        updateObservationTimestap(observations["time"])
        dispatch_async(dispatch_get_main_queue(), {
            self.tableView.reloadData()
        })
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
    
    func updateObservationCoordinates(latitude: String, longitude: String) {
        if latitude == "nil" || longitude == "nil" {
            coordString = ""
        }
        else {
            coordString = "Observations at N \(latitude), E \(longitude)"
        }
    }
    
    func updateObservationTimestap(timestamp: String?) {
        if let ts = timestamp {
            let date = NSDate(timeIntervalSince1970: NSString(string: ts).doubleValue)
            observationTimestamp = NSDateFormatter.localizedStringFromDate(date,
                dateStyle: NSDateFormatterStyle.ShortStyle, timeStyle: NSDateFormatterStyle.ShortStyle)
        }
        else {
            observationTimestamp = ""
        }
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if coordString.isEmpty || observationTimestamp.isEmpty {
            return ""
        }
        else {
            return coordString + " at " + observationTimestamp
        }
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return displayArray.isEmpty ? 0 : 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayArray.count
    }
    
    override func tableView(_tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = _tableView.dequeueReusableCellWithIdentifier("ObservationValueCell") as! ObservationTableViewCell
        cell.title.text = displayArray[indexPath.row].0
        cell.value.text = displayArray[indexPath.row].1
        return cell
    }
    
    class func stripDecimals(value: String) -> String {
        return (NSString(format: "%.0f", round((value as NSString).floatValue)) as String)
    }

    let urlSession = NSURLSession.sharedSession()
    var coordString = ""
    var observationTimestamp = ""
    var displayArray: [ (String, String) ] = []
    var observationMappings = [
        ObservationMapping(title: "Temperature", parameter: "airTemperature",
            formatter: { (value: String) -> String in value + "°C" }),
        ObservationMapping(title: "Wind Direction", parameter: "windDirection",
            formatter: { (value: String) -> String in
                ObservationDataViewController.stripDecimals(value) + "°"
            }),
        ObservationMapping(title: "Average wind speed", parameter: "windSpeed",
            formatter: { (value: String) -> String in value + " m/s"}),
        ObservationMapping(title: "Gust wind speed", parameter: "windSpeedGust",
            formatter: { (value: String) -> String in value + " m/s"}),
        ObservationMapping(title: "Cloud cover (0/8)", parameter: "amountOfCloud",
            formatter: { (value: String) -> String in
                ObservationDataViewController.stripDecimals(value) }),
        ObservationMapping(title: "Visibility", parameter: "visibility",
            formatter: { (value: String) -> String in
                let valueKm = (value as NSString).floatValue / 1000.0
                return (NSString(format: "%.0f km", valueKm) as String)
            }),
        ObservationMapping(title: "Amount of precipitation", parameter: "precipitationAmount",
            formatter: { (value: String) -> String in value + " mm"
        }),
        ObservationMapping(title: "Relative humidity", parameter: "relativeHumidity",
            formatter: {(value: String) -> String in
                ObservationDataViewController.stripDecimals(value) + " %" }),
    ]
}

