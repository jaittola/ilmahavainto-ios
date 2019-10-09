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

    init(coordinate: CLLocationCoordinate2D,
         title: String,
         subtitle: String,
         locationId: String,
         windSpeed: String?,
         windDirection: String?) {
        self.locationId = locationId
        self.windSpeed = NSString(string: windSpeed ?? "0").doubleValue
        self.windDirection = NSString(string: windDirection ?? "0").doubleValue

        super.init()

        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
    }
}
