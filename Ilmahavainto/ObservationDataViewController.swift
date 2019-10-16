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
    
    func updateObservations(_ observation: ObservationModel.Observation) {
        displayArray.removeAll(keepingCapacity: true)
        for m in observationMappings {
            if let value = m.formatter(observation) {
                displayArray.append((m.title, value))
            }
        }
        stationName = observation.stationName
        coordString = ObservationUtils.makeCoordinateString(lat: observation.coordinates.latitude,
                                                            lon: observation.coordinates.longitude)
        observationTimestamp = observationTimestamp(observation.time)
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    private func observationTimestamp(_ date: Date) -> String {
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
                " " + observationTimestamp
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
        cell.title.text = NSLocalizedString(displayArray[cellForRowAt.row].0, comment: "")
        cell.value.text = displayArray[cellForRowAt.row].1
        return cell
    }
    
    class func stripDecimals(_ value: Double?) -> String? {
        if let v = value {
            return String(format: "%.0f", round(v))
        } else {
            return nil
        }
    }

    var observationStationData: [ObservationModel.Observation]? {
        didSet {
            if let sd = observationStationData?.last {
                updateObservations(sd)
            }
        }
    }

    private var stationName = ""
    private var coordString = ""
    private var observationTimestamp = ""
    private var displayArray: [ (String, String) ] = []

    private struct ObservationMapping {
        let title: String
        let formatter: (ObservationModel.Observation) -> String?
        static func doubleFormatter(_ value: Double?, _ format: String, _ valueFilter: (Double) -> Double = { $0 }) -> String? {
            if let v = value {
                return String(format: format, valueFilter(v))
            } else {
                return nil
            }
        }
    }

    private let observationMappings = [
        ObservationMapping(title: "Temperature",
                           formatter: { ObservationMapping.doubleFormatter($0.airTemperature, "%.01f°C") }),
        ObservationMapping(title: "Wind Direction",
                           formatter: { ObservationUtils.windDirection($0.windDirection) }),
        ObservationMapping(title: "Average wind speed",
                           formatter: { ObservationMapping.doubleFormatter($0.windSpeed, "%.01f m/s") }),
        ObservationMapping(title: "Gust wind speed",
                           formatter: { ObservationMapping.doubleFormatter($0.windSpeedGust, "%.01f m/s") }),
        ObservationMapping(title: "Cloud cover (0/8)",
                           formatter: { ObservationMapping.doubleFormatter($0.amountOfCloud, "%.0f", round) }),
        ObservationMapping(title: "Visibility",
                           formatter: { obs in ObservationMapping.doubleFormatter(obs.visibility, "%.0f km", { $0/1000.0 }) }),
        ObservationMapping(title: "Amount of precipitation",
                           formatter: { ObservationMapping.doubleFormatter($0.precipitationAmount, "%.0f mm") }),
        ObservationMapping(title: "Relative humidity",
                           formatter: { ObservationMapping.doubleFormatter($0.relativeHumidity, "%.0f %%", round) })
    ]
}

