//
//  TimeDelta.swift
//  Railtime
//
//  Created by Kai Quan Tay on 5/9/26.
//

import Foundation

/// The difference between two times of day
public nonisolated struct TimeDelta: AdditiveArithmetic, Equatable, Comparable, Sendable, Codable {
    /// A time delta representing no difference in time of day
    public static let zero: TimeDelta = .zero

    /// The difference between two times of day, in seconds
    public var seconds: TimeInterval

    /// Creates a time delta from a number of seconds
    public init(seconds: TimeInterval) {
        self.seconds = seconds
    }

    /// Creates a time delta from a number of seconds
    public static func secs(_ seconds: TimeInterval) -> TimeDelta { return .init(seconds: seconds) }
    /// Creates a time delta from a number of minutes
    public static func mins(_ minutes: Double) -> TimeDelta { return .init(seconds: minutes * 60) }
    /// Creates a time delta from a number of hours
    public static func hours(_ hours: Double) -> TimeDelta { return .init(seconds: hours * 60 * 60) }

    /// Adds one time delta to another
    public static func + (lhs: TimeDelta, rhs: TimeDelta) -> TimeDelta {
        TimeDelta(seconds: lhs.seconds + rhs.seconds)
    }

    /// Subtracts one time delta from another
    public static func - (lhs: TimeDelta, rhs: TimeDelta) -> TimeDelta {
        TimeDelta(seconds: lhs.seconds - rhs.seconds)
    }

    /// Checks if one time delta is smaller than another
    public static func < (lhs: TimeDelta, rhs: TimeDelta) -> Bool {
        lhs.seconds < rhs.seconds
    }

    /// Multiplies a time delta by a scalar value
    public func scale(by rhs: Double) -> TimeDelta {
        TimeDelta(seconds: self.seconds * rhs)
    }

    /// Performs the `abs` operation on the time delta and returns the result
    public func magnitude() -> TimeDelta {
        TimeDelta(seconds: abs(seconds))
    }
}
