//
//  ObservationUtils.swift
//  Ilmahavainto
//
//  Created by Jukka Aittola on 04/08/15.
//  Copyright (c) 2015 Jukka Aittola. All rights reserved.
//

import Foundation

class ObservationUtils: NSObject {
    class func makeSexagesimal(decimalDegree: Double, isLatitude: Bool) -> String {
        let degrees: Int = Int(decimalDegree)
        let fraction = decimalDegree - Double(degrees)
        let hemisphere = isLatitude ?
            (decimalDegree >= 0 ? "N" : "S") :
            (decimalDegree >= 0 ? "E" : "W")
        
        return String(format: "%@ %d° %.3f'", hemisphere, degrees, fraction)
    }
    
    class func makeCoordinateString(#lat: String, lon: String) -> String {
        let latText = makeSexagesimal(NSString(string: lat).doubleValue, isLatitude: true)
        let lonText = makeSexagesimal(NSString(string: lon).doubleValue, isLatitude: false)

        return "\(latText) \(lonText)"
    }

    class func windDirection(wind: String?) -> String {
        let windDirections = ["N", "NE", "E", "SE", "S", "SW", "W", "NW", "W"]
        if let wd = wind {
            let roundedWind = round(NSString(string: wd).doubleValue)
            let windSectorIdx = Int(roundedWind + 22) / 45
            let windSector = windSectorIdx < windDirections.count ? windDirections[windSectorIdx] : ""
            return String(format: "%@ (%.0f°)", windSector, roundedWind)
        }
        return ""
    }
    
}
