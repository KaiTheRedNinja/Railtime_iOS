//
//  Journey.swift
//  Railtime
//
//  Created by Kai Quan Tay on 12/9/26.
//

import Foundation
import SwiftUI

/// A directed, non-looping graph, consisting of a start (root) node and a graph of legs (edges). This outlines the possible modes
/// of transportation to take from the start to any of the end (leaf) nodes.
public struct Journey: Identifiable {
    /// The ID of this journey
    public var id: UUID = .init()

    /// The ID of the starting node
    public var startNodeId: JourneyNodeID
    /// The nodes of this journey
    public var nodes: [JourneyNodeID: any JourneyNode]
    /// The legs of this journey
    public var legs: [JourneyLegID: any JourneyLeg]
    /// The path that this journey will take starting from the start node
    public var path: [JourneyLegID]

    /// The starting node
    public var startNode: any JourneyNode {
        get { nodes[startNodeId]! }
        set { nodes[startNodeId] = newValue }
    }

    public init(
        id: UUID = .init(),
        startNodeId: JourneyNodeID,
        nodes: [JourneyNodeID: any JourneyNode],
        legs: [JourneyLegID: any JourneyLeg],
        path: [JourneyLegID]
    ) {
        assert(nodes[startNodeId] != nil, "`nodes` must contain a node with starting ID \(startNodeId)")

        self.id = id
        self.startNodeId = startNodeId
        self.nodes = nodes
        self.legs = legs
        self.path = path
    }

    /// Creates a new `Journey` consisting of an undefined bus route
    public static func emptyBusJourney() -> Journey {
        var startNode = JourneyBusStopNode(busStopCode: "", nextLegIds: [])
        let nextNode = JourneyBusStopNode(busStopCode: "", nextLegIds: [])
        let firstLeg = JourneyBusLeg(serviceNo: "", destinationId: nextNode.id)
        startNode.nextLegIds = [firstLeg.id]
        return .init(
            startNodeId: startNode.id,
            nodes: [startNode.id: startNode, nextNode.id: nextNode],
            legs: [firstLeg.id: firstLeg],
            path: [firstLeg.id]
        )
    }

    /// Obtains the start node, given the expected type
    public func startNode<N>(
        as _: N.Type
    ) -> N? where N: JourneyNode {
        nodes[startNodeId] as? N
    }

    /// Obtains the leg and the node that it leads to, given the expected type for both the leg and the node
    public func legAndEndNode<L, N>(
        for legId: JourneyLegID,
        legAs _: L.Type,
        nodeAs _: N.Type
    ) -> (leg: L, endNode: N)? where L: JourneyLeg, N: JourneyNode {
        guard let leg = legs[legId] as? L,
              let node = nodes[leg.destinationId] as? N
        else { return nil }
        return (leg, node)
    }

    /// Obtains the leg and the node that it leads to, given the expected type for the leg but not the node
    public func legAndEndNode<L>(
        for legId: JourneyLegID,
        legAs _: L.Type
    ) -> (leg: L, endNode: any JourneyNode)? where L: JourneyLeg {
        guard let leg = legs[legId] as? L,
              let node = nodes[leg.destinationId]
        else { return nil }
        return (leg, node)
    }

    /// Obtains the leg, given the expected type for the leg
    public func leg<L>(
        for legId: JourneyLegID,
        as _: L.Type
    ) -> L? where L: JourneyLeg {
        return legs[legId] as? L
    }

    /// Obtains the node that a leg leads to, given the expected type for the node
    public func endNode<N>(
        for legId: JourneyLegID,
        as _: N.Type
    ) -> N? where N: JourneyNode {
        guard let leg = legs[legId],
              let node = nodes[leg.destinationId] as? N
        else { return nil }
        return node
    }

    /// Removes nodes and edges that are not connected to the root node
    public mutating func removeUnconnected() {
        var queue = [startNode]
        let oldNodes = nodes
        let oldLegs = legs
        var newNodes: [JourneyNodeID: any JourneyNode] = [:]
        var newLegs: [JourneyLegID: any JourneyLeg] = [:]

        while var item = queue.popLast() {
            var validLegIds: [JourneyLegID] = []

            // go through each leg that starts from this node
            for nextLegId in item.nextLegIds {
                if newLegs[nextLegId] == nil, // leg must not already be registered (single start)
                   let nextLeg = oldLegs[nextLegId], // leg must connect to a node (single end)
                   let nextEndNode = oldNodes[nextLeg.destinationId] // connected node must exist
                {
                    // register leg
                    newLegs[nextLegId] = nextLeg
                    // mark leg as valid
                    validLegIds.append(nextLegId)
                    // add end node to queue
                    queue.append(nextEndNode)
                }
            }

            item.nextLegIds = validLegIds
            newNodes[item.id] = item
        }

        self.nodes = newNodes
        self.legs = newLegs
    }
}

public extension Binding where Value == Journey {
    /// Obtains the start node, given the expected type
    func startNode<N>(
        as _: N.Type
    ) -> Binding<N>? where N: JourneyNode {
        if let startNode = wrappedValue.startNode(as: N.self) {
            return .init {
                startNode
            } set: { newValue in
                wrappedValue.nodes[wrappedValue.startNodeId] = newValue
            }
        } else {
            return nil
        }
    }

    /// Obtains the leg and the node that it leads to, given the expected type for both the leg and the node
    func legAndEndNode<L, N>(
        for legId: JourneyLegID,
        legAs _: L.Type,
        nodeAs _: N.Type
    ) -> Binding<(leg: L, endNode: N)>? where L: JourneyLeg, N: JourneyNode {
        if let tuple = wrappedValue.legAndEndNode(for: legId, legAs: L.self, nodeAs: N.self) {
            return .init {
                tuple
            } set: { newValue in
                guard let leg = wrappedValue.legs[legId] else { fatalError("Attempted to use expired binding") }

                wrappedValue.legs[legId] = newValue.leg
                wrappedValue.nodes[leg.destinationId] = newValue.endNode
            }
        } else {
            return nil
        }
    }

    /// Obtains the leg and the node that it leads to, given the expected type for the leg but not the node
    func legAndEndNode<L>(
        for legId: JourneyLegID,
        legAs _: L.Type
    ) -> Binding<(leg: L, endNode: any JourneyNode)>? where L: JourneyLeg {
        if let tuple = wrappedValue.legAndEndNode(for: legId, legAs: L.self) {
            return .init {
                tuple
            } set: { newValue in
                guard let leg = wrappedValue.legs[legId] else { fatalError("Attempted to use expired binding") }

                wrappedValue.legs[legId] = newValue.leg
                wrappedValue.nodes[leg.destinationId] = newValue.endNode
            }
        } else {
            return nil
        }
    }

    /// Obtains the leg, given the expected type for the leg
    func leg<L>(
        for legId: JourneyLegID,
        as _: L.Type
    ) -> Binding<L>? where L: JourneyLeg {
        if let value = wrappedValue.leg(for: legId, as: L.self) {
            return .init {
                value
            } set: { newValue in
                wrappedValue.legs[legId] = newValue
            }
        } else {
            return nil
        }
    }

    /// Obtains the node that a leg leads to, given the expected type for the node
    func endNode<N>(
        for legId: JourneyLegID,
        as _: N.Type
    ) -> Binding<N>? where N: JourneyNode {
        if let value = wrappedValue.endNode(for: legId, as: N.self) {
            return .init {
                value
            } set: { newValue in
                guard let leg = wrappedValue.legs[legId] else { fatalError("Attempted to use expired binding") }
                wrappedValue.nodes[leg.destinationId] = newValue
            }
        } else {
            return nil
        }
    }
}
