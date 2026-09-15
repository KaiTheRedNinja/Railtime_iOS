//
//  Journey+Walk.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 15/9/26.
//

import Foundation
import LTAAPI

/// A node representing a bus stop
public struct JourneyArbitraryLocationNode: JourneyNode {
    /// A coordinate for an arbitrary location
    public struct Context: JourneyNodeContext {
        /// The location's latitude, in degrees.
        public let latitude: Double
        /// The location's longitude, in degrees.
        public let longitude: Double
    }

    public var id: JourneyNodeID = .init()
    public var nextLegIds: [JourneyLegID]
    public var contextId: JourneyNodeContextID { id.uuidString }

    public init(id: JourneyNodeID = .init(), nextLegIds: [JourneyLegID]) {
        self.id = id
        self.nextLegIds = nextLegIds
    }
}

/// A node representing a bus journey
public struct JourneyWalkLeg: JourneyLeg {
    /// The walking duration information for a walk
    public struct Context: JourneyLegContext {
        /// The estimated distance of the walk, in km
        public var estimatedDistance: CGFloat
        /// The estimated time to walk
        public var walkTime: TimeDelta
    }

    public var id: JourneyLegID = .init()
    public var destinationId: JourneyNodeID
    public var contextId: JourneyLegContextID { id.uuidString }

    public init(id: JourneyLegID = .init(), destinationId: JourneyNodeID) {
        self.id = id
        self.destinationId = destinationId
    }

    // a walk can start and end anywhere
    public static func canStartWith<N>(node: N) -> Bool where N: JourneyNode { true }
    public static func canEndWith<N>(node: N) -> Bool where N: JourneyNode { true }

    public func attemptMerge(
        withNextLeg next: JourneyWalkLeg,
        selfContext: Context,
        nextContext: Context
    ) -> (JourneyWalkLeg, Context)? {
        // walks cannot be merged, as two walks being merged would violate the triangle property
        // where dist(A -> C) <= dist(A -> B -> C)
        return nil
    }
}
