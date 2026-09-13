//
//  Journey+Bus.swift
//  Railtime
//
//  Created by Kai Quan Tay on 12/9/26.
//

import Foundation
import BusEstimation
import LTAAPI

/// A node representing a bus stop
public struct JourneyBusStopNode: JourneyNode {
    public typealias Context = LTABusStopInfo

    public var id: UUID = .init()

    public var busStopCode: String

    public init(id: UUID = .init(), busStopCode: String) {
        self.id = id
        self.busStopCode = busStopCode
    }
}

extension LTABusStopInfo: JourneyNodeContext {}

/// A node representing a bus journey
public struct JourneyBusLeg: JourneyLeg {
    /// The estimations for a segment of a bus route
    public struct Context: JourneyLegContext {
        /// The code for the stop that this segment starts with - i.e. the stop that the user would enter the bus
        public var startCode: String
        /// The code for the stop that this segment ends with - i.e. the stop that the user would exit the bus
        public var endCode: String

        /// The estimations, where the first item is for the start bus stop, and the last is for the end bus stop.
        public var stopEstimations: [StopArrivalEstimates]
    }

    public var id: UUID = .init()

    public var serviceNo: String
    public var destinationBusStop: JourneyBusStopNode

    public var destination: any JourneyNode { destinationBusStop }

    public init(id: UUID = .init(), serviceNo: String, destinationBusStop: JourneyBusStopNode) {
        self.id = id
        self.serviceNo = serviceNo
        self.destinationBusStop = destinationBusStop
    }
}
