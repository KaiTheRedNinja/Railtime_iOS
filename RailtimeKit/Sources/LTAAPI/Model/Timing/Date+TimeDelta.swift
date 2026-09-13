//
//  Date+TimeDelta.swift
//  Railtime
//
//  Created by Kai Quan Tay on 5/9/26.
//

import Foundation

public extension Date {
    /// Obtains the time delta that has elapsed since a previous `TimeOfDay`. `other` is assumed to be before
    /// `self`.
    func timeDelta(since other: Date) -> TimeDelta {
        TimeDelta(seconds: self.timeIntervalSince(other))
    }

    /// Increments this time by a certain time delta, wrapping around 24H if nescessary.
    func incrementingBy(timeDelta: TimeDelta) -> Date {
        self.addingTimeInterval(timeDelta.seconds)
    }
}
