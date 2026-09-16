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

    public var id: JourneyNodeID = .init()
    public var busStopCode: String
    public var nextLegIds: [JourneyLegID]
    public var contextId: JourneyNodeContextID { busStopCode }

    public init(id: JourneyNodeID = .init(), busStopCode: String, nextLegIds: [JourneyLegID]) {
        self.id = id
        self.busStopCode = busStopCode
        self.nextLegIds = nextLegIds
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

    public var id: JourneyLegID = .init()
    public var serviceNo: String
    public var destinationId: JourneyNodeID
    public var contextId: JourneyLegContextID { id.uuidString }

    public init(id: JourneyLegID = .init(), serviceNo: String, destinationId: JourneyNodeID) {
        self.id = id
        self.serviceNo = serviceNo
        self.destinationId = destinationId
    }

    public static func canStartWith<N>(node: N) -> Bool where N: JourneyNode { N.self is JourneyBusStopNode.Type }
    public static func canEndWith<N>(node: N) -> Bool where N: JourneyNode { N.self is JourneyBusStopNode.Type }

    public func canBeMerged(
        withNextLeg next: JourneyBusLeg,
        selfContext: Context,
        nextContext: Context
    ) -> Bool {
        return self.serviceNo == next.serviceNo && // must have the same service
               selfContext.stopEstimations.last == nextContext.stopEstimations.first // must overlap estimations
    }

    public func attemptMerge(
        withNextLeg next: JourneyBusLeg,
        selfContext: Context,
        nextContext: Context
    ) -> (JourneyBusLeg, Context)? {
        guard self.serviceNo == next.serviceNo, // must have the same service
              selfContext.stopEstimations.last == nextContext.stopEstimations.first // must overlap estimations
        else { return nil }

        // build the new leg
        let newLeg = JourneyBusLeg(
            serviceNo: serviceNo,
            destinationId: next.destinationId
        )
        // build the new context
        let newContext = Context(
            startCode: selfContext.startCode,
            endCode: nextContext.endCode,
            stopEstimations: selfContext.stopEstimations + nextContext.stopEstimations.dropFirst()
        )
        return (newLeg, newContext)
    }
}
