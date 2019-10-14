//
//  ObservationAnnotation.swift
//  Ilmahavainto
//
//  Created by Jukka Aittola on 04/08/15.
//  Copyright (c) 2015 Jukka Aittola. All rights reserved.
//

import UIKit
import MapKit

class ObservationAnnotation: MKPointAnnotation {
    let locationId: String
    let windSpeed: Double
    let windDirection: Double
    let timestamp: Date

    var isExpired: Bool {
        get {
            let tenMinutesInSeconds = 10 * 60
            return timestamp < Date(timeIntervalSinceNow: TimeInterval(-tenMinutesInSeconds))
        }
    }


    init(coordinate: CLLocationCoordinate2D,
         title: String,
         subtitle: String,
         locationId: String,
         windSpeed: String?,
         windDirection: String?,
         timestamp: String?) {
        self.locationId = locationId
        self.windSpeed = NSString(string: windSpeed ?? "0").doubleValue
        self.windDirection = NSString(string: windDirection ?? "0").doubleValue
        if let ts = timestamp {
            self.timestamp = Date(timeIntervalSince1970: NSString(string: ts).doubleValue)
        } else {
            self.timestamp = Date()
        }





        super.init()

        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
    }
}
