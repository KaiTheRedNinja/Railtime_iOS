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
