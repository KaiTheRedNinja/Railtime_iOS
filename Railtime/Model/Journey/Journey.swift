//
//  Journey.swift
//  Railtime
//
//  Created by Kai Quan Tay on 12/9/26.
//

import Foundation

/// A directed chain, consisting of a start (root) node and a series of travel legs. This outlines the modes
/// of transportation to take from the start to end nodes.
struct Journey: Identifiable {
    /// The ID of this journey
    var id: UUID = .init()

    /// The node that this journey starts from
    var startNode: any JourneyNode
    /// The legs of this journey
    var legs: [any JourneyLeg]

    /// The node that this journey ends with. If `legs` is empty, this is equal to `startNode`.
    var endNode: any JourneyNode {
        legs.last?.destination ?? startNode
    }

    /// Creates a new `Journey` consisting of an undefined bus route
    static func emptyBusJourney() -> Journey {
        .init(
            startNode: JourneyBusStopNode(busStopCode: ""),
            legs: [JourneyBusLeg(serviceNo: "", destinationBusStop: JourneyBusStopNode(busStopCode: ""))]
        )
    }
}

/// A node in a journey
protocol JourneyNode: Equatable, Identifiable where Self.ID == UUID {
    associatedtype Context: JourneyNodeContext
}
/// The context for a node in the journey
protocol JourneyNodeContext: Equatable { }

/// A travel method from one node to another
protocol JourneyLeg: Equatable, Identifiable where Self.ID == UUID {
    associatedtype Context: JourneyLegContext

    var destination: any JourneyNode { get }
}
/// The context for a leg of a journey
protocol JourneyLegContext: Equatable { }
