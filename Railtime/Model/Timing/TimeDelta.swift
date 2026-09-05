//
//  TimeDelta.swift
//  Railtime
//
//  Created by Kai Quan Tay on 5/9/26.
//

import Foundation

/// The difference between two times of day
nonisolated struct TimeDelta: AdditiveArithmetic, Equatable, Comparable, Sendable {
    /// A time delta representing no difference in time of day
    static var zero: TimeDelta = .zero

    /// The difference between two times of day, in seconds
    var seconds: TimeInterval

    /// Creates a time delta from a number of seconds
    init(seconds: TimeInterval) {
        self.seconds = seconds
    }

    /// Creates a time delta from a number of seconds
    static func secs(_ seconds: TimeInterval) -> TimeDelta { return .init(seconds: seconds) }
    /// Creates a time delta from a number of minutes
    static func mins(_ minutes: Double) -> TimeDelta { return .init(seconds: minutes * 60) }
    /// Creates a time delta from a number of hours
    static func hours(_ hours: Double) -> TimeDelta { return .init(seconds: hours * 60 * 60) }

    /// Adds one time delta to another
    static func + (lhs: TimeDelta, rhs: TimeDelta) -> TimeDelta {
        TimeDelta(seconds: lhs.seconds + rhs.seconds)
    }

    /// Subtracts one time delta from another
    static func - (lhs: TimeDelta, rhs: TimeDelta) -> TimeDelta {
        TimeDelta(seconds: lhs.seconds - rhs.seconds)
    }

    /// Checks if one time delta is smaller than another
    static func < (lhs: TimeDelta, rhs: TimeDelta) -> Bool {
        lhs.seconds < rhs.seconds
    }

    /// Multiplies a time delta by a scalar value
    static func * (lhs: TimeDelta, rhs: Double) -> TimeDelta {
        TimeDelta(seconds: lhs.seconds * rhs)
    }

    /// Divides a time delta by a scalar value
    static func / (lhs: TimeDelta, rhs: Double) -> TimeDelta {
        TimeDelta(seconds: lhs.seconds * rhs)
    }

    /// Performs the `abs` operation on the time delta and returns the result
    func magnitude() -> TimeDelta {
        TimeDelta(seconds: abs(seconds))
    }
}
