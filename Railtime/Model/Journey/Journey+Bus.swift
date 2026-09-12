//
//  Journey+Bus.swift
//  Railtime
//
//  Created by Kai Quan Tay on 12/9/26.
//

import Foundation

/// A node representing a bus stop
struct JourneyBusStopNode: JourneyNode {
    typealias Context = LTABusStopInfo

    var id: UUID = .init()

    var busStopCode: String
}

extension LTABusStopInfo: JourneyNodeContext {}

/// A node representing a bus journey
struct JourneyBusLeg: JourneyLeg {
    /// The estimations for a segment of a bus route
    struct Context: JourneyLegContext {
        /// The code for the stop that this segment starts with - i.e. the stop that the user would enter the bus
        var startCode: String
        /// The code for the stop that this segment ends with - i.e. the stop that the user would exit the bus
        var endCode: String

        /// The estimations, where the first item is for the start bus stop, and the last is for the end bus stop.
        var stopEstimations: [StopArrivalEstimates]
    }

    var id: UUID = .init()

    var serviceNo: String
    var destinationBusStop: JourneyBusStopNode

    var destination: any JourneyNode { destinationBusStop }
}
