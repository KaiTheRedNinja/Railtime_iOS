//
//  StopArrivalEstimates.swift
//  Railtime
//
//  Created by Kai Quan Tay on 6/9/26.
//

import Foundation

/// All the estimates for when busses will arrive at this stop.
struct StopArrivalEstimates: Equatable, Codable {
    /// The ID of this stop.
    var stopId: String
    /// The delta-time of this stop, relative to some downstream target, in
    /// seconds (equivalent to the Python `timedelta` field of the same
    /// name).
    var deltaTime: TimeDelta
    /// The error in the delta-time of this stop, relative to some
    /// downstream target, in seconds.
    var deltaError: TimeDelta
    /// The arrival estimates, first.
    var estimates: [BusArrivalEstimate]
}
