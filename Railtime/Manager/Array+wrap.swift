//
//  Array+wrap.swift
//  Railtime
//
//  Created by Kai Quan Tay on 6/9/26.
//

import Foundation

// --------------------------------------------------------------------------
// Array helper
// --------------------------------------------------------------------------

extension Array {
    /// Indexes into the array the way Python's `list` does: a negative
    /// index counts backwards from the end (`stops[-1]` is the last
    /// element). Used to faithfully mirror a couple of spots in the
    /// original Python where an index can legitimately go negative and
    /// Python's wraparound (rather than a crash) is the observed behaviour.
    /// Just like Python, an index that is out of range even after
    /// wraparound will trap.
    subscript(wrapping index: Int) -> Element {
        let resolvedIndex = index >= 0 ? index : count + index
        return self[resolvedIndex]
    }

    /// Similar to `map` but passes an inout of the current value instead
    mutating func modify(_ modifier: (inout Element) -> Void) {
        for index in self.indices {
            modifier(&self[index])
        }
    }
}
