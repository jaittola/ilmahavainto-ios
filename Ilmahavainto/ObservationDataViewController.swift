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
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func updateObservations(_ observations: [String: String]) {
        displayArray.removeAll(keepingCapacity: true)
        for m in observationMappings {
            if let observation = observations[m.parameter] {
                    displayArray.append((m.title, m.format(observation)))
            }
        }
        stationName = observations["stationName"] ?? ""
        coordString = ObservationUtils.makeCoordinateString(lat: observations["lat"], lon: observations["long"])
        observationTimestamp = observationTimestamp(observations["time"])
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    private func observationTimestamp(_ timestamp: String?) -> String {
        guard let ts = timestamp else { return "" }
        let date = Date(timeIntervalSince1970: NSString(string: ts).doubleValue)
        return DateFormatter.localizedString(from: date,
                                             dateStyle: DateFormatter.Style.short,
                                             timeStyle: DateFormatter.Style.short)
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if coordString.isEmpty || observationTimestamp.isEmpty {
            return ""
        }
        else {
            return (stationName != "" ? "\(stationName) (\(coordString))" : coordString) +
                " at " + observationTimestamp
        }
    }
    
    override func numberOfSections(in: UITableView) -> Int {
        return displayArray.isEmpty ? 0 : 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayArray.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ObservationValueCell") as! ObservationTableViewCell
        cell.title.text = displayArray[cellForRowAt.row].0
        cell.value.text = displayArray[cellForRowAt.row].1
        return cell
    }
    
    class func stripDecimals(_ value: String) -> String {
        return (NSString(format: "%.0f", round((value as NSString).floatValue)) as String)
    }

    var observationStationData: [Dictionary<String, String>]? {
        didSet {
            if let sd = observationStationData?.last {
                updateObservations(sd)
            }
        }
    }
    
    var stationName = ""
    var coordString = ""
    var observationTimestamp = ""
    var displayArray: [ (String, String) ] = []
    var observationMappings = [
        ObservationMapping(title: "Temperature", parameter: "airTemperature",
            formatter: { (value: String) -> String in value + "°C" }),
        ObservationMapping(title: "Wind Direction", parameter: "windDirection",
            formatter: { (value: String) -> String in
                ObservationUtils.windDirection(value)
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

