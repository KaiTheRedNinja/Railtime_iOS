//
//  StopArrivalEstimates.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 16/9/26.
//

import Foundation
import LTAAPI

/// A structure containing information about a generic stop
public struct StopArrivalEstimates<ArrivalEstimate: VehicleArrivalEstimate>: Equatable, Identifiable, Codable {
    public typealias ID = String

    /// The ID of this stop
    public var id: String

    /// The ID of this stop, under the old name for backward compatibility
    public var stopId: String { get { id } set { id = newValue } }

    /// The delta-time of this stop, relative to some downstream target. This is expected to be a negative number, and
    /// the delta time of the last stop of the leg will be zero.
    public var deltaTime: TimeDelta

    /// The error in the delta-time of this stop, relative to some
    /// downstream target, in seconds.
    public var deltaError: TimeDelta

    /// The arrival estimates, first being the earliest vehicle to arrive
    public var estimates: [ArrivalEstimate]

    public init(stopId: String, deltaTime: TimeDelta, deltaError: TimeDelta, estimates: [ArrivalEstimate]) {
        self.id = stopId
        self.deltaTime = deltaTime
        self.deltaError = deltaError
        self.estimates = estimates
    }
}
