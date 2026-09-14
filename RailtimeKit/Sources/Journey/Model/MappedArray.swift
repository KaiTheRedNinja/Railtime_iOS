//
//  MappedArray.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 14/9/26.
//


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
