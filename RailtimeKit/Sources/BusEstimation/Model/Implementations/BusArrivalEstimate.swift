//
//  BusArrivalEstimate.swift
//  Railtime
//
//  Created by Kai Quan Tay on 6/9/26.
//

import Foundation
import LTAAPI

public typealias BusStopArrivalEstimates = StopArrivalEstimates<BusArrivalEstimate>

/// An estimate for when a bus, with a given ID, will arrive at a given stop.
public struct BusArrivalEstimate: VehicleArrivalEstimate {
    /// The ID of this bus.
    public var id: BusID
    /// The service number of this bus.
    public var busServiceNo: String
    /// The projected arrival time at the target stop.
    public var eta: Date
    /// The error at the time of estimation.
    public let error: LTAAPI.TimeDelta
    /// Where the information for the bus's arrival came from
    public var source: DataSource

    // display info
    public var displayText: String { busServiceNo }
    public var displayColor: String { "#30D158" }
    public var displaySymbol: String { "bus" }

    /// Metadata
    public var metadata: Metadata

    public struct Metadata: Equatable, Codable {
        /// The upstream stop code used for this projection.
        public var projectedFromStop: String?
        /// Optional metadata from the API.
        public var load: LTANextBusInfo.Load?
        /// Optional metadata from the API.
        public var feature: String?
        /// Optional metadata from the API.
        public var busType: LTANextBusInfo.BusVariant?
    }

    /// The ID of a bus
    public enum BusID: Equatable, Hashable, Codable {
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

    public init(
        busId: BusID,
        busServiceNo: String,
        eta: Date,
        error: TimeDelta = .zero,
        source: DataSource,
        projectedFromStop: String? = nil,
        load: LTANextBusInfo.Load? = nil,
        feature: String? = nil,
        busType: LTANextBusInfo.BusVariant? = nil
    ) {
        self.id = busId
        self.busServiceNo = busServiceNo
        self.eta = eta
        self.error = error
        self.source = source
        self.metadata = .init(
            projectedFromStop: projectedFromStop,
            load: load,
            feature: feature,
            busType: busType
        )
    }
}
