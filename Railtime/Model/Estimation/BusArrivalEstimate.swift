//
//  BusArrivalEstimate.swift
//  Railtime
//
//  Created by Kai Quan Tay on 6/9/26.
//

import Foundation

/// An estimate for when a bus, with a given ID, will arrive at a given stop.
struct BusArrivalEstimate: Equatable {
    /// The ID of this bus.
    var busId: BusID
    /// The service number of this bus.
    var busServiceNo: String
    /// The projected arrival time at the target stop.
    var eta: Date

    /// Where the information for the bus's arrival came from
    var source: DataSource
    /// The upstream stop code used for this projection.
    var projectedFromStop: String?

    /// Optional metadata from the API.
    var load: LTANextBusInfo.Load?
    /// Optional metadata from the API.
    var feature: String?
    /// Optional metadata from the API.
    var busType: LTANextBusInfo.BusVariant?

    /// The ID of a bus
    enum BusID: Equatable {
        /// The ID of this bus is yet to be assigned
        case unassigned
        /// A sequential ID for this bus
        case ordered(index: Int)

        var description: String {
            switch self {
            case .unassigned: "UNASSIGNED"
            case .ordered(let index): "bus_\(index)"
            }
        }

        var index: Int? {
            switch self {
            case .unassigned: nil
            case .ordered(let index): index
            }
        }
    }

    /// Where the information for a bus' arrival comes from
    enum DataSource {
        /// The data was obtained directly from the LTA Live Bus API
        case live
        /// The data was projected from an up/downstream `live` bus
        case projected
        /// The data was extrapolated from the last known `live` or `projected` bus using known frequency data
        case extrapolated
    }

    /// Optional metadata from the API.
    init(
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
    func minutesFrom(_ ref: Date) -> TimeDelta {
        eta.timeDelta(since: ref)
    }
}
