//
//  Journey.swift
//  Railtime
//
//  Created by Kai Quan Tay on 12/9/26.
//

import Foundation

/// A directed chain, consisting of a start (root) node and a series of travel legs. This outlines the modes
/// of transportation to take from the start to end nodes.
public struct Journey: Identifiable {
    /// The ID of this journey
    public var id: UUID = .init()

    /// The node that this journey starts from
    public var startNode: any JourneyNode
    /// The legs of this journey
    public var legs: [any JourneyLeg]

    public init(id: UUID = .init(), startNode: any JourneyNode, legs: [any JourneyLeg]) {
        self.id = id
        self.startNode = startNode
        self.legs = legs
    }

    /// A SwiftUI-safe type-erased wrapper for `legs`. This is lazily mapped.
    public var legsErased: MappedArray<any JourneyLeg, AnyJourneyLeg> {
        get { MappedArray(base: legs, toU: { AnyJourneyLeg(value: $0) }, toT: { $0.value }) }
        set { legs = newValue.base }
        _modify {
            var wrapper = MappedArray(base: legs, toU: { AnyJourneyLeg(value: $0) }, toT: { $0.value })
            legs = []
            defer { legs = wrapper.base }
            yield &wrapper
        }
    }

    /// The node that this journey ends with. If `legs` is empty, this is equal to `startNode`.
    public var endNode: any JourneyNode {
        legs.last?.destination ?? startNode
    }

    /// Creates a new `Journey` consisting of an undefined bus route
    public static func emptyBusJourney() -> Journey {
        .init(
            startNode: JourneyBusStopNode(busStopCode: ""),
            legs: [JourneyBusLeg(serviceNo: "", destinationBusStop: JourneyBusStopNode(busStopCode: ""))]
        )
    }
}

/// A node in a journey
public protocol JourneyNode: Equatable, Identifiable, Codable where Self.ID == UUID {
    associatedtype Context: JourneyNodeContext
}
/// The context for a node in the journey
public protocol JourneyNodeContext: Equatable, Codable { }
/// A wrapper for `any JourneyNode`
public struct AnyJourneyNode: Identifiable {
    public var id: UUID { value.id }
    public var value: any JourneyNode
}

/// A travel method from one node to another
public protocol JourneyLeg: Equatable, Identifiable, Codable where Self.ID == UUID {
    associatedtype Context: JourneyLegContext

    var destination: any JourneyNode { get }
}
/// The context for a leg of a journey
public protocol JourneyLegContext: Equatable, Codable { }
/// A wrapper for `any JourneyLeg`
public struct AnyJourneyLeg: Identifiable {
    public var id: UUID { value.id }
    public var value: any JourneyLeg
}

/// A structure containing context for a `Journey`
public struct JourneyContext {
    /// The context for the nodes of the journey
    public var nodeContext: [UUID: any JourneyNodeContext]
    /// The context for intermediate nodes of the journey, that are a part of the context and not the journey
    public var intermediateNodeContext: [String: any JourneyNodeContext]
    /// The context for the edges of the journey
    public var edgeContext: [UUID: any JourneyLegContext]

    public static var empty: JourneyContext = .init(nodeContext: [:], intermediateNodeContext: [:], edgeContext: [:])
}

/// An array type which lazily maps elements into a mutable, random access, range replaceable collection.
public struct MappedArray<T, U>: RandomAccessCollection, MutableCollection, RangeReplaceableCollection {
    var base: [T]
    let toU: (T) -> U
    let toT: (U) -> T

    // RandomAccessCollection / MutableCollection conformance
    public var startIndex: Int { base.startIndex }
    public var endIndex: Int { base.endIndex }
    public func index(after i: Int) -> Int { base.index(after: i) }
    public func index(before i: Int) -> Int { base.index(before: i) }

    public subscript(position: Int) -> U {
        get { toU(base[position]) }
        set { base[position] = toT(newValue) }
    }

    // RangeReplaceableCollection conformance
    public init() {
        // Only reachable if you have default T/U mappings; see note below.
        fatalError("MappedArray requires toU/toT — use init(base:toU:toT:) instead")
    }

    public init(base: [T], toU: @escaping (T) -> U, toT: @escaping (U) -> T) {
        self.base = base
        self.toU = toU
        self.toT = toT
    }

    public mutating func replaceSubrange<C: Collection>(
        _ subrange: Range<Int>, with newElements: C
    ) where C.Element == U {
        base.replaceSubrange(subrange, with: newElements.lazy.map(toT))
    }

    // Optional but worth overriding for efficiency — the default
    // reserveCapacity(_:) is a no-op otherwise.
    public mutating func reserveCapacity(_ n: Int) {
        base.reserveCapacity(n)
    }
}
