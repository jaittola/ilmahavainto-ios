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
    
    class func makeCoordinateString(lat: Double, lon: Double) -> String {
        let latText = makeSexagesimal(decimalDegree: lat, isLatitude: true)
        let lonText = makeSexagesimal(decimalDegree: lon, isLatitude: false)

        return "\(latText) \(lonText)"
    }

    class func windDirection(_ wind: Double?) -> String? {
        let windDirections = ["N", "NE", "E", "SE", "S", "SW", "W", "NW", "W"]
        guard let wd = wind else { return nil }
        let roundedWind = round(wd)
        let windSectorIdx = Int(roundedWind + 22) / 45
        let windSector = windSectorIdx < windDirections.count ? windDirections[windSectorIdx] : ""
        return String(format: "%@ (%.0f°)", windSector, roundedWind)
    }
    
}
