//
//  LTABusStopInfo.swift
//  Railtime
//
//  Created by Kai Quan Tay on 5/9/26.
//

import Foundation

/// A single row from the 2.4 BusStops endpoint: static information about a
/// physical bus stop.
struct LTABusStopInfo: Equatable, Codable {
    /// The bus stop code.
    let busStopCode: String
    /// The name of the road the stop is on.
    let roadName: String?
    /// A human-readable description of the stop (often its landmark name).
    let description: String?
    /// The stop's latitude, in degrees.
    let latitude: Double
    /// The stop's longitude, in degrees.
    let longitude: Double

    enum CodingKeys: String, CodingKey {
        case busStopCode = "BusStopCode"
        case roadName = "RoadName"
        case description = "Description"
        case latitude = "Latitude"
        case longitude = "Longitude"
    }
}
