//
//  StopArrivalEstimates.swift
//  Railtime
//
//  Created by Kai Quan Tay on 6/9/26.
//

import Foundation
import LTAAPI

/// All the estimates for when busses will arrive at this stop.
public struct StopArrivalEstimates: Equatable, Codable {
    /// The ID of this stop.
    public var stopId: String
    /// The delta-time of this stop, relative to some downstream target, in
    /// seconds (equivalent to the Python `timedelta` field of the same
    /// name).
    public var deltaTime: TimeDelta
    /// The error in the delta-time of this stop, relative to some
    /// downstream target, in seconds.
    public var deltaError: TimeDelta
    /// The arrival estimates, first.
    public var estimates: [BusArrivalEstimate]

    public init(stopId: String, deltaTime: TimeDelta, deltaError: TimeDelta, estimates: [BusArrivalEstimate]) {
        self.stopId = stopId
        self.deltaTime = deltaTime
        self.deltaError = deltaError
        self.estimates = estimates
    }
}
