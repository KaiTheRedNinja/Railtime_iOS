//
//  JourneyContext.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 14/9/26.
//

/// A structure containing context for a `Journey`
public struct JourneyContext {
    /// The context for nodes anywhere in the journey, including intermediate nodes which are not formally part of the journey's path
    public var nodeContext: [JourneyNodeContextID: any JourneyNodeContext]
    /// The context for the edges of the journey
    public var edgeContext: [JourneyLegContextID: any JourneyLegContext]

    /// An empty context
    public static var empty: JourneyContext = .init(nodeContext: [:], edgeContext: [:])

    /// Gets a typed node context for a given node
    public func context<N>(forNode node: any JourneyNode, type _: N.Type = N.self) -> N.Context? where N: JourneyNode {
        if (node as? N) != nil,
           let context = nodeContext[node.contextId],
           let typedContext = context as? N.Context {
            return typedContext
        } else {
            return nil
        }
    }

    /// Gets a typed node context for a given node context ID
    public func context<N>(forNodeContextId id: JourneyNodeContextID, type _: N.Type = N.self) -> N.Context? where N: JourneyNode {
        if let context = nodeContext[id],
           let typedContext = context as? N.Context {
            return typedContext
        } else {
            return nil
        }
    }

    /// Gets a typed edge context for a given edge
    public func context<L>(forLeg leg: any JourneyLeg, type _: L.Type = L.self) -> L.Context? where L: JourneyLeg {
        if (leg as? L) != nil,
           let context = edgeContext[leg.contextId],
           let typedContext = context as? L.Context {
            return typedContext
        } else {
            return nil
        }
    }

    /// Gets a typed edge context for a given edge context ID
    public func context<L>(forLegContextId id: JourneyNodeContextID, type _: L.Type = L.self) -> L.Context? where L: JourneyLeg {
        if let context = edgeContext[id],
           let typedContext = context as? L.Context {
            return typedContext
        } else {
            return nil
        }
    }
}
