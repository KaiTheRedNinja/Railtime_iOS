//
//  JourneyManager+access.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 14/9/26.
//

extension JourneyManager {
    /// Gets the leg and end node context for a given path item, given the expected return types for both
    public func legAndEndNodeContext<L, N>(
        forPathItem pathItem: JourneyLegID,
        legType _: L.Type,
        nodeType _: N.Type
    ) -> (legContext: L.Context, endNodeContext: N.Context)? where L: JourneyLeg, N: JourneyNode {
        guard let (leg, endNode) = journey.legAndEndNode(for: pathItem, legAs: L.self, nodeAs: N.self),
              let legContext = context.context(forLegContextId: leg.contextId, type: L.self),
              let endNodeContext = context.context(forNodeContextId: endNode.contextId, type: N.self)
        else { return nil }

        return (legContext, endNodeContext)
    }

    /// Gets the leg context for a given path item, given the expected return type
    public func legContext<L>(
        forPathItem pathItem: JourneyLegID,
        as _: L.Type
    ) -> L.Context? where L: JourneyLeg {
        guard let leg = journey.leg(for: pathItem, as: L.self),
              let legContext = context.context(forLegContextId: leg.contextId, type: L.self)
        else { return nil }

        return legContext
    }

    /// Gets the end node context for a given path item, given the expected return type
    public func endNodeContext<N>(
        forPathItem pathItem: JourneyLegID,
        as _: N.Type
    ) -> N.Context? where N: JourneyNode {
        guard let endNode = journey.endNode(for: pathItem, as: N.self),
              let endNodeContext = context.context(forNodeContextId: endNode.contextId, type: N.self)
        else { return nil }

        return endNodeContext
    }
}
