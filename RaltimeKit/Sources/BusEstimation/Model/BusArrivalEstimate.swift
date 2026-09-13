//
//  BusArrivalEstimate.swift
//  Railtime
//
//  Created by Kai Quan Tay on 6/9/26.
//

import Foundation
import LTAAPI

/// An estimate for when a bus, with a given ID, will arrive at a given stop.
public struct BusArrivalEstimate: Equatable, Codable {
    /// The ID of this bus.
    public var busId: BusID
    /// The service number of this bus.
    public var busServiceNo: String
    /// The projected arrival time at the target stop.
    public var eta: Date

    /// Where the information for the bus's arrival came from
    public var source: DataSource
    /// The upstream stop code used for this projection.
    public var projectedFromStop: String?

    /// Optional metadata from the API.
    public var load: LTANextBusInfo.Load?
    /// Optional metadata from the API.
    public var feature: String?
    /// Optional metadata from the API.
    public var busType: LTANextBusInfo.BusVariant?

    /// The ID of a bus
    public enum BusID: Equatable, Codable {
        /// The ID of this bus is yet to be assigned
        case unassigned
        /// A sequential ID for this bus
        case ordered(index: Int)

        public var description: String {
            switch self {
            case .unassigned: "UNASSIGNED"
            case .ordered(let index): "bus_\(index)"
            }
        }

        public var index: Int? {
            switch self {
            case .unassigned: nil
            case .ordered(let index): index
            }
        }
    }

    /// Where the information for a bus' arrival comes from
    public enum DataSource: Codable {
        /// The data was obtained directly from the LTA Live Bus API
        case live
        /// The data was projected from an up/downstream `live` bus
        case projected
        /// The data was extrapolated from the last known `live` or `projected` bus using known frequency data
        case extrapolated
    }

    public init(
        busId: BusID,
        busServiceNo: String,
        eta: Date,
        source: DataSource,
        projectedFromStop: String? = nil,
        load: LTANextBusInfo.Load? = nil,
        feature: String? = nil,
        busType: LTANextBusInfo.BusVariant? = nil
    ) {
        self.busId = busId
        self.busServiceNo = busServiceNo
        self.eta = eta
        self.source = source
        self.projectedFromStop = projectedFromStop
        self.load = load
        self.feature = feature
        self.busType = busType
    }

    /// The time delta from `ref` until this bus's ETA.
    public func minutesFrom(_ ref: Date) -> TimeDelta {
        eta.timeDelta(since: ref)
    }
}
