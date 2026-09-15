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

    /// Attempt to merge this leg with the leg (of the same type) after it.
    /// - Parameters:
    ///   - next: The next leg of the journey chain
    ///   - selfContext: The context for this leg
    ///   - nextContext: The context for the next leg
    /// - Returns: A merged instance and context, or `nil` if a merge was not successful
    func attemptMerge(
        withNextLeg next: Self,
        selfContext: Context,
        nextContext: Context
    ) -> (Self, Context)?
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
