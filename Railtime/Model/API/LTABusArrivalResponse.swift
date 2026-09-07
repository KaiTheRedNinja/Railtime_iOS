//
//  LTABusArrivalResponse.swift
//  Railtime
//
//  Created by Kai Quan Tay on 5/9/26.
//

import Foundation

/// The 2.1 BusArrival endpoint's response envelope for a single bus stop.
struct LTABusArrivalResponse: Decodable {
    /// The bus stop code these arrivals apply to.
    let busStopCode: String
    /// Per-service arrival information at this stop (filtered to a single
    /// service when `ServiceNo` was passed to the request).
    let services: [LTABusArrivalServiceEntry]

    enum CodingKeys: String, CodingKey {
        case busStopCode = "BusStopCode"
        case services = "Services"
    }
}
