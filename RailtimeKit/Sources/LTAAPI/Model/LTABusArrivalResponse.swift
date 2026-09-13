//
//  LTABusArrivalResponse.swift
//  Railtime
//
//  Created by Kai Quan Tay on 5/9/26.
//

import Foundation

/// The 2.1 BusArrival endpoint's response envelope for a single bus stop.
public struct LTABusArrivalResponse: Decodable {
    /// The bus stop code these arrivals apply to.
    public let busStopCode: String
    /// Per-service arrival information at this stop (filtered to a single
    /// service when `ServiceNo` was passed to the request).
    public let services: [LTABusArrivalServiceEntry]

    public enum CodingKeys: String, CodingKey {
        case busStopCode = "BusStopCode"
        case services = "Services"
    }
}
