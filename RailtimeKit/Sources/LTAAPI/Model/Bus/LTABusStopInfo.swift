//
//  LTABusStopInfo.swift
//  Railtime
//
//  Created by Kai Quan Tay on 5/9/26.
//

import Foundation

/// A single row from the 2.4 BusStops endpoint: static information about a
/// physical bus stop.
public struct LTABusStopInfo: Hashable, Codable {
    /// The bus stop code.
    public let busStopCode: String
    /// The name of the road the stop is on.
    public let roadName: String?
    /// A human-readable description of the stop (often its landmark name).
    public let description: String?
    /// The stop's latitude, in degrees.
    public let latitude: Double
    /// The stop's longitude, in degrees.
    public let longitude: Double

    public enum CodingKeys: String, CodingKey {
        case busStopCode = "BusStopCode"
        case roadName = "RoadName"
        case description = "Description"
        case latitude = "Latitude"
        case longitude = "Longitude"
    }

    public init(busStopCode: String, roadName: String?, description: String?, latitude: Double, longitude: Double) {
        self.busStopCode = busStopCode
        self.roadName = roadName
        self.description = description
        self.latitude = latitude
        self.longitude = longitude
    }
}
