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
    let observation: ObservationModel.Observation

    init(title: String,
         subtitle: String,
         observation: ObservationModel.Observation) {
        self.observation = observation
        super.init()
        self.coordinate = observation.coordinates
        self.title = title
        self.subtitle = subtitle
    }
}
