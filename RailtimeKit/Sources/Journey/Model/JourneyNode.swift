//
//  JourneyNode.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 14/9/26.
//

import Foundation

/// A unique ID for a node in a journey
public typealias JourneyNodeID = UUID
/// A unique ID for context for a node in a journey
public typealias JourneyNodeContextID = String
/// A node in a journey
public protocol JourneyNode: Equatable, Identifiable, Codable where Self.ID == JourneyNodeID {
    associatedtype Context: JourneyNodeContext

    /// The ID for subsequent legs, if any, in order of preference
    var nextLegIds: [JourneyLegID] { get set }
    /// The ID to retrieve a context from.
    var contextId: JourneyNodeContextID { get }
}
/// The context for a node in the journey
public protocol JourneyNodeContext: Equatable, Codable {
    /// The location's latitude, in degrees.
    var latitude: Double { get }
    /// The location's longitude, in degrees.
    var longitude: Double { get }
}
/// A wrapper for `any JourneyNode`
public struct AnyJourneyNode: Identifiable {
    public var id: JourneyNodeID { value.id }
    public var value: any JourneyNode

    public init(value: any JourneyNode) {
        self.value = value
    }
}
