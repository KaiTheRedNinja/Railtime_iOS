//
//  JourneyChain.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 15/9/26.
//

/// A directed chain, consisting of a start (root) node and a series of travel legs. This is based on a linear subgraph of
/// `Journey`, and outlines the modes of transportation to take from the start to a single end node.
///
/// Note that due to merging nodes together, a `JourneyChain` MAY NOT BE an exact subgraph of the `Journey` it was built from.
public struct JourneyChain {
    /// The path items that this journey consists of
    public var pathItems: [JourneyPathItem]

    /// Creates a journey chain reflecting the current path of a `Journey`.
    ///
    /// This is a HEAVY OPERATION that will create a lot of copies - it should be used sparingly!
    public init(journey: Journey, context: JourneyContext, optimise: Bool = true) throws {
        pathItems = []

        var currentPathItem: JourneyPathItem?
        var currentTailNode = journey.startNode
        guard var currentTailNodeContext = context.nodeContext[currentTailNode.contextId]
        else { throw JourneyChainError.missingContext }

        for pathId in journey.path {
            // get the current leg
            guard let newLeg = journey.legs[pathId] else { throw JourneyChainError.invalidPath }
            guard let newTailNode = journey.nodes[newLeg.destinationId] else { throw JourneyChainError.invalidGraph }
            guard let newLegContext = context.edgeContext[newLeg.contextId],
                  let newTailNodeContext = context.nodeContext[newTailNode.contextId]
            else { throw JourneyChainError.missingContext }

            // attempt to merge with the current path item, if any
            if optimise,
               let curr = currentPathItem,
               let (mergedLeg, mergedLegContext) = curr.leg.attemptMerge(
                withAnyNextLeg: newLeg,
                selfContext: curr.legContext,
                nextContext: newLegContext
               ) {
                currentPathItem?.id = mergedLeg.id
                currentPathItem?.leg = mergedLeg
                currentPathItem?.legContext = mergedLegContext
                currentPathItem?.tailNode = newTailNode
                currentPathItem?.tailNodeContext = newTailNodeContext
            } else {
                // add old path item, create new path item
                if let currentPathItem { pathItems.append(currentPathItem) }

                currentPathItem = .init(
                    id: pathId,
                    leg: newLeg,
                    legContext: newLegContext,
                    headNode: currentTailNode,
                    headNodeContext: currentTailNodeContext,
                    tailNode: newTailNode,
                    tailNodeContext: newTailNodeContext
                )
            }

            currentTailNode = newTailNode
            currentTailNodeContext = newTailNodeContext
        }

        if let currentPathItem { pathItems.append(currentPathItem) }
    }
}

public enum JourneyChainError: Error {
    /// The path through the graph is invalid
    case invalidPath
    /// The graph is invalid, eg. referenced node or leg does not exist
    case invalidGraph
    /// Missing context
    case missingContext
}

public struct JourneyPathItem: Identifiable {
    /// The path ID of this chain item
    public var id: JourneyLegID

    /// The leg for this path item
    public var leg: any JourneyLeg
    /// The context for the leg, if any
    public var legContext: any JourneyLegContext

    /// The node that this leg of the path starts with
    public var headNode: any JourneyNode
    /// The context for the start node, if any
    public var headNodeContext: any JourneyNodeContext
    /// The node that this leg of the path ends with
    public var tailNode: any JourneyNode
    /// The context for the end node, if any
    public var tailNodeContext: any JourneyNodeContext

    /// Gets the leg and leg context, given the expected type
    public func legAndContext<L>(as _: L.Type) -> (L, L.Context?)? where L: JourneyLeg {
        if let leg = leg as? L { return (leg, legContext as? L.Context) }
        return nil
    }

    /// Gets the head node and head node context, given the expected type
    public func headNodeAndContext<N>(as _: N.Type) -> (N, N.Context?)? where N: JourneyNode {
        if let head = headNode as? N { return (head, headNodeContext as? N.Context) }
        return nil
    }

    /// Gets the tail node and tail node context, given the expected type
    public func tailNodeAndContext<N>(as _: N.Type) -> (N, N.Context?)? where N: JourneyNode {
        if let tail = tailNode as? N { return (tail, tailNodeContext as? N.Context) }
        return nil
    }
}
