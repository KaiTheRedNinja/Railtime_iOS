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
        legType _: L.Type = L.self,
        nodeType _: N.Type = N.self
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
        as _: L.Type = L.self
    ) -> L.Context? where L: JourneyLeg {
        guard let leg = journey.leg(for: pathItem, as: L.self),
              let legContext = context.context(forLegContextId: leg.contextId, type: L.self)
        else { return nil }

        return legContext
    }

    /// Gets the end node context for a given path item, given the expected return type
    public func endNodeContext<N>(
        forPathItem pathItem: JourneyLegID,
        as _: N.Type = N.self
    ) -> N.Context? where N: JourneyNode {
        guard let endNode = journey.endNode(for: pathItem, as: N.self),
              let endNodeContext = context.context(forNodeContextId: endNode.contextId, type: N.self)
        else { return nil }

        return endNodeContext
    }

    /// Determines whether the given path item can be an extension of the prior leg, or if
    /// the next leg can be an extension of this leg.
    ///
    /// This function will return `false` when:
    /// - The path item cannot be found or its context cannot be found (both return values will be `false`)
    /// - There is no previous/next path item, or there is but the context could not be found (respective return value will be `false`)
    /// - The previous/next path item cannot be merged with the given path item (respective return value will be `false`)
    public func isExtension(
        pathItem: JourneyLegID
    ) -> (prev: Bool, next: Bool) {
        // get the index of the path item, and also its context
        guard let pathIndex = journey.path.firstIndex(of: pathItem),
              let thisLeg = journey.legs[pathItem],
              let thisLegContext = context.edgeContext[thisLeg.contextId]
        else { return (false, false) }

        let prev = if pathIndex - 1 >= 0,
                      let prevLeg = journey.legs[journey.path[pathIndex - 1]],
                      let prevLegContext = context.edgeContext[prevLeg.contextId] {
            prevLeg.canBeMerged(
                withAnyNextLeg: thisLeg,
                selfContext: prevLegContext,
                nextContext: thisLegContext
            )
        } else { false }

        let next = if pathIndex + 1 < journey.path.count,
                      let nextLeg = journey.legs[journey.path[pathIndex - 1]],
                      let nextLegContext = context.edgeContext[nextLeg.contextId] {
            thisLeg.canBeMerged(
                withAnyNextLeg: nextLeg,
                selfContext: thisLegContext,
                nextContext: nextLegContext
            )
        } else { false }

        return (prev, next)
    }
}
