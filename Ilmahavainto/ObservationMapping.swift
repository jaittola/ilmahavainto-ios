//
//  ObservationMapping.swift
//  Ilmahavainto
//
//  Created by Jukka Aittola on 31/07/15.
//  Copyright (c) 2015 Jukka Aittola. All rights reserved.
//

import UIKit

class ObservationMapping: NSObject {
    var title: String
    var parameter: String
    var format: (value: String) -> String
    
    init(title: String, parameter: String, formatter: (value: String) -> String) {
        self.title = title
        self.parameter = parameter
        self.format = formatter
    }
}
