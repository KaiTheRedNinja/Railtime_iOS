//
//  JourneyLeg.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 14/9/26.
//

import Foundation

/// A unique ID for a leg of a journey
public typealias JourneyLegID = UUID
/// A unique ID for context for a leg of a journey
public typealias JourneyLegContextID = String
/// A travel method from one node to another
public protocol JourneyLeg: Equatable, Identifiable, Codable where Self.ID == JourneyLegID {
    associatedtype Context: JourneyLegContext

    /// The ID for the destination node
    var destinationId: JourneyNodeID { get set }
    /// The ID to retrieve a context from
    var contextId: JourneyLegContextID { get }

    /// Determines whether a leg of this type can start with a given starting node
    static func canStartWith<N>(node: N) -> Bool where N: JourneyNode
    /// Determines whether a leg of this type can end with a given ending node
    static func canEndWith<N>(node: N) -> Bool where N: JourneyNode

    /// Determines whether this leg can be merged with the leg (of the same type) after it. Should be O(1) if possible.
    func canBeMerged(
        withNextLeg next: Self,
        selfContext: Context,
        nextContext: Context
    ) -> Bool
}

extension JourneyLeg {
    /// Determines whether this leg can be merged with the leg (of possibly a different type) after it. If the next leg is a different
    /// type, it automatically returns `false`.
    func canBeMerged(
        withAnyNextLeg next: any JourneyLeg,
        selfContext: any JourneyLegContext,
        nextContext: any JourneyLegContext
    ) -> Bool {
        if let next = next as? Self,
           let selfContext = selfContext as? Self.Context,
           let nextContext = nextContext as? Self.Context {
            canBeMerged(withNextLeg: next, selfContext: selfContext, nextContext: nextContext)
        } else {
            false
        }
    }
}

/// The context for a leg of a journey
public protocol JourneyLegContext: Equatable, Codable {}
/// A wrapper for `any JourneyLeg`
public struct AnyJourneyLeg: Identifiable {
    public var id: JourneyLegID { value.id }
    public var value: any JourneyLeg

    public init(value: any JourneyLeg) {
        self.value = value
    }
}
