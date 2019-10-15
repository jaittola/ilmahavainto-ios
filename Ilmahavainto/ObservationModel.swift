//
//  ObservationModel.swift
//  Ilmahavainto
//
//  Created by Jukka Aittola on 15/10/2019.
//  Copyright © 2019 Jukka Aittola. All rights reserved.
//

import Foundation
import MapKit

protocol ObservationModelDelegate {
    func onError(_ message: String)
    func onDisplayObservations(_ observations: [String: [Dictionary<String, String>]])
}

class ObservationModel {
    private let delegate: ObservationModelDelegate
    private var observations: [String: [Dictionary<String, String>]] = [:]

    init(_ delegate: ObservationModelDelegate) {
        self.delegate = delegate
    }

    func loadObservations(center: CLLocationCoordinate2D, viewSpan: MKCoordinateSpan) {
        let lat1 = roundTo3(center.latitude - viewSpan.latitudeDelta / 2)
        let lat2 = roundTo3(center.latitude + viewSpan.latitudeDelta / 2)
        let lon1 = roundTo3(center.longitude - viewSpan.longitudeDelta / 2)
        let lon2 = roundTo3(center.longitude + viewSpan.longitudeDelta / 2)
        if let url = URL(string:  "https://ilmaproxy.herokuapp.com/1/observations?lat1=\(lat1)&lat2=\(lat2)&lon1=\(lon1)&lon2=\(lon2)") {
            Swift.print("=> Loading observations after map region change; approx pos range \(lat1) \(lon1) ,  \(lat2), \(lon2) from URL \(url)")
            let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
                if let localizedDescription = error?.localizedDescription {
                    self.delegate.onError(localizedDescription)
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.delegate.onError("Response is not a HTTPURLResponse")
                    return
                }
                switch (httpResponse.statusCode) {
                case 200...299:
                    break;  // Ok
                case 400...499:
                    print("Got reply with response code \(httpResponse.statusCode)")
                    return
                default:
                    self.delegate.onError("Getting observation data failed. Response code \(httpResponse.statusCode)")

                }
                if let dataValue = data {
                    self.handleObservationDataResponse(dataValue)
                }
            }
            task.resume()
        }
    }

    func observation(forLocationId: String) -> [Dictionary<String, String>]? {
        return observations[forLocationId]
    }

    private func handleObservationDataResponse(_ data: Data) {
        let rawj = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: 0)) as Any?
        if let obsStations = rawj as? [ String:[ Dictionary<String, String> ] ] {
            observations = obsStations
        }
        else {
            observations = [:]
            delegate.onError("Bad JSON data received")
        }

        DispatchQueue.main.async {
            self.delegate.onDisplayObservations(self.observations)
        }
    }

    private func roundTo3(_ v: Double) -> Double {
        return Double(round(1000 * v) / 1000)
    }
}
