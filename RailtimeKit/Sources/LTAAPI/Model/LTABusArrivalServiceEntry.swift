//
//  BusArrivalServiceEntry.swift
//  Railtime
//
//  Created by Kai Quan Tay on 5/9/26.
//

import Foundation

/// One bus service's live arrival information at a stop, as returned by the
/// 2.1 BusArrival endpoint.
public struct LTABusArrivalServiceEntry: Decodable {
    /// The bus service number.
    public let serviceNo: String
    /// The bus operator code.
    public let `operator`: String?
    /// The next bus expected at this stop, if any.
    public let nextBus: LTANextBusInfo?
    /// The second-next bus expected at this stop, if any.
    public let nextBus2: LTANextBusInfo?
    /// The third-next bus expected at this stop, if any.
    public let nextBus3: LTANextBusInfo?

    public enum CodingKeys: String, CodingKey {
        case serviceNo = "ServiceNo"
        case `operator` = "Operator"
        case nextBus = "NextBus"
        case nextBus2 = "NextBus2"
        case nextBus3 = "NextBus3"
    }

    /// Returns [nextBus, nextBus2, nextBus3] in order, mirroring the
    /// Python code's `for key in ("NextBus", "NextBus2", "NextBus3")` loops.
    public var nextBuses: [LTANextBusInfo?] {
        [nextBus, nextBus2, nextBus3]
    }
}
