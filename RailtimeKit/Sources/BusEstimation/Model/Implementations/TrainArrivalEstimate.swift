//
//  TrainArrivalEstimate.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 17/9/26.
//

import Foundation
import LTAAPI

public typealias TrainStopArrivalEstimates = StopArrivalEstimates<TrainArrivalEstimate>

/// An estimate for when a train, with a given ID, will arrive at a given stop.
public struct TrainArrivalEstimate: VehicleArrivalEstimate {
    /// The ID of this MRT
    public var id: TrainID
    /// The line name of this train
    public var lineName: String
    /// The projected arrival time at the target stop.
    public var eta: Date
    /// The error at the time of estimation.
    public let error: TimeDelta
    /// Where the information for the train's arrival came from
    ///
    /// For Singapore's MRT, train ETAs are not provided. Therefore they are always extrapolated.
    public var source: DataSource { .extrapolated }

    // display info
    public var displayText: String { lineName }
    public var displayColor: String { "#FF4245" }
    public var displaySymbol: String { "train.side.rear.car" }

    public let metadata: ()

    /// The ID of a bus
    public enum TrainID: Equatable, Hashable, Codable {
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

    public init(id: TrainID, lineName: String, eta: Date, error: LTAAPI.TimeDelta, metadata: ()) {
        self.id = id
        self.lineName = lineName
        self.eta = eta
        self.error = error
        self.metadata = metadata
    }

    enum CodingKeys: CodingKey {
        case id
        case lineName
        case eta
        case error
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(lineName, forKey: .lineName)
        try container.encode(eta, forKey: .eta)
        try container.encode(error, forKey: .error)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(TrainID.self, forKey: .id)
        self.lineName = try container.decode(String.self, forKey: .lineName)
        self.eta = try container.decode(Date.self, forKey: .eta)
        self.error = try container.decode(TimeDelta.self, forKey: .error)
    }

    public static func == (lhs: borrowing TrainArrivalEstimate, rhs: borrowing TrainArrivalEstimate) -> Bool {
        [
            lhs.id == rhs.id,
            lhs.lineName == rhs.lineName,
            lhs.eta == rhs.eta,
            lhs.error == rhs.error
        ].reduce(true, { $0 && $1 })
    }
}
