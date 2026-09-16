//
//  Journey+Train.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 15/9/26.
//

import Foundation
import LTAAPI

/// A node representing a bus stop
public struct JourneyMRTStopNode: JourneyNode {
    // TODO: replace with the type we implement for MRT Context
    public typealias Context = JourneyArbitraryLocationNode.Context

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

/// A node representing an MRT journey
public struct JourneyMRTLeg: JourneyLeg {
    /// The estimations for a segment of a bus route
    public struct Context: JourneyLegContext {
        /// The code for the stop that this segment starts with - i.e. the stop that the user would enter the MRT
        public var startCode: String
        /// The code for the stop that this segment ends with - i.e. the stop that the user would exit the MRT
        public var endCode: String

        /// The period between when trains arrive at the starting MRT stop.
        ///
        /// Because LTA does not provide us with exact MRT position estimates, this is the best we can do.
        public var periodBetweenMRTs: TimeDelta
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

    public static func canStartWith<N>(node: N) -> Bool where N: JourneyNode { N.self is JourneyMRTStopNode.Type }
    public static func canEndWith<N>(node: N) -> Bool where N: JourneyNode { N.self is JourneyMRTStopNode.Type }

    public func canBeMerged(
        withNextLeg next: JourneyMRTLeg,
        selfContext: Context,
        nextContext: Context
    ) -> Bool {
        self.serviceNo == next.serviceNo // must have the same service
    }
}
