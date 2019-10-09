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
    
    class func makeCoordinateString(lat: String?, lon: String?) -> String {
        guard let lat2 = lat else { return "" }
        guard let lon2 = lon else { return "" }

        let latText = makeSexagesimal(decimalDegree: NSString(string: lat2).doubleValue, isLatitude: true)
        let lonText = makeSexagesimal(decimalDegree: NSString(string: lon2).doubleValue, isLatitude: false)

        return "\(latText) \(lonText)"
    }

    class func windDirection(_ wind: String?) -> String {
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
