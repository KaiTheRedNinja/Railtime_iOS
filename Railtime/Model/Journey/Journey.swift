//
//  Journey.swift
//  Railtime
//
//  Created by Kai Quan Tay on 12/9/26.
//

import Foundation

/// A directed chain, consisting of a start (root) node and a series of travel legs. This outlines the modes
/// of transportation to take from the start to end nodes.
struct Journey: Identifiable {
    /// The ID of this journey
    var id: UUID = .init()

    /// The node that this journey starts from
    var startNode: any JourneyNode
    /// The legs of this journey
    var legs: [any JourneyLeg]

    /// A SwiftUI-safe type-erased wrapper for `legs`. This is lazily mapped.
    var legsErased: MappedArray<any JourneyLeg, AnyJourneyLeg> {
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
    var endNode: any JourneyNode {
        legs.last?.destination ?? startNode
    }

    /// Creates a new `Journey` consisting of an undefined bus route
    static func emptyBusJourney() -> Journey {
        .init(
            startNode: JourneyBusStopNode(busStopCode: ""),
            legs: [JourneyBusLeg(serviceNo: "", destinationBusStop: JourneyBusStopNode(busStopCode: ""))]
        )
    }
}

/// A node in a journey
protocol JourneyNode: Equatable, Identifiable, Codable where Self.ID == UUID {
    associatedtype Context: JourneyNodeContext
}
/// The context for a node in the journey
protocol JourneyNodeContext: Equatable, Codable { }
/// A wrapper for `any JourneyNode`
struct AnyJourneyNode: Identifiable {
    var id: UUID { value.id }
    var value: any JourneyNode
}

/// A travel method from one node to another
protocol JourneyLeg: Equatable, Identifiable, Codable where Self.ID == UUID {
    associatedtype Context: JourneyLegContext

    var destination: any JourneyNode { get }
}
/// The context for a leg of a journey
protocol JourneyLegContext: Equatable, Codable { }
/// A wrapper for `any JourneyLeg`
struct AnyJourneyLeg: Identifiable {
    var id: UUID { value.id }
    var value: any JourneyLeg
}

/// A structure containing context for a `Journey`
struct JourneyContext {
    /// The context for the nodes of the journey
    var nodeContext: [UUID: any JourneyNodeContext]
    /// The context for intermediate nodes of the journey, that are a part of the context and not the journey
    var intermediateNodeContext: [String: any JourneyNodeContext]
    /// The context for the edges of the journey
    var edgeContext: [UUID: any JourneyLegContext]

    static var empty: JourneyContext = .init(nodeContext: [:], intermediateNodeContext: [:], edgeContext: [:])
}

/// An array type which lazily maps elements into a mutable, random access, range replaceable collection.
struct MappedArray<T, U>: RandomAccessCollection, MutableCollection, RangeReplaceableCollection {
    var base: [T]
    let toU: (T) -> U
    let toT: (U) -> T

    // RandomAccessCollection / MutableCollection conformance
    var startIndex: Int { base.startIndex }
    var endIndex: Int { base.endIndex }
    func index(after i: Int) -> Int { base.index(after: i) }
    func index(before i: Int) -> Int { base.index(before: i) }

    subscript(position: Int) -> U {
        get { toU(base[position]) }
        set { base[position] = toT(newValue) }
    }

    // RangeReplaceableCollection conformance
    init() {
        // Only reachable if you have default T/U mappings; see note below.
        fatalError("MappedArray requires toU/toT — use init(base:toU:toT:) instead")
    }

    init(base: [T], toU: @escaping (T) -> U, toT: @escaping (U) -> T) {
        self.base = base
        self.toU = toU
        self.toT = toT
    }

    mutating func replaceSubrange<C: Collection>(
        _ subrange: Range<Int>, with newElements: C
    ) where C.Element == U {
        base.replaceSubrange(subrange, with: newElements.lazy.map(toT))
    }

    // Optional but worth overriding for efficiency — the default
    // reserveCapacity(_:) is a no-op otherwise.
    mutating func reserveCapacity(_ n: Int) {
        base.reserveCapacity(n)
    }
}
