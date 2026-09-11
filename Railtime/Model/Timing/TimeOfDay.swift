//
//  TimeOfDay.swift
//  Railtime
//
//  Created by Kai Quan Tay on 5/9/26.
//

import Foundation

/// A way to represent a time of day without a date. This should only be used when the date is _explicitly not known nor provided_.
/// If the date is known, use `Date` instead for more comprehensive functionality.
///
/// `TimeOfDay` intentionally does not conform to `AdditiveArithmetic` or `Comparable` as day boundaries
/// can mess up operations if same-day assumptions are implicitly made.
struct TimeOfDay: Codable, CustomDebugStringConvertible {
    /// The raw number of seconds since the start of the day (i.e. midnight)
    var secondsSinceMidnight: TimeInterval

    /// The `hh` part of the time of day, represented as `hh:mm:dd`
    var hh: Int { Int(secondsSinceMidnight / (60 * 60)) }
    /// The `mm` part of the time of day, represented as `hh:mm:dd`
    var mm: Int { Int((secondsSinceMidnight.truncatingRemainder(dividingBy: 60 * 60)) / 60) }
    /// The `ss` part of the time of day, represented as `hh:mm:dd`
    var ss: Int { Int(secondsSinceMidnight.truncatingRemainder(dividingBy: 60)) }

    /// The date formatted as a `hh:mm:ss` string
    var hhmmss: String { "\(String(format: "%02d", hh)):\(String(format: "%02d", mm)):\(String(format: "%02d", ss))" }
    /// The date formatted as a `hh:mm` string
    var hhmm: String { "\(String(format: "%02d", hh)):\(String(format: "%02d", mm))" }

    /// The debug description
    var debugDescription: String { "\(hhmmss), secondsSinceMidnight = \(secondsSinceMidnight)" }

    /// A time of day initialised from seconds since midnight. No validation done.
    init(secondsSinceMidnight: TimeInterval) {
        self.secondsSinceMidnight = secondsSinceMidnight
    }
    /// A time of day obtained from a string in a format `HHmm`
    init?(hhmmString: String) {
        guard hhmmString.count == 4,
              let hours = Int(hhmmString.prefix(2)), 0 <= hours && hours <= 24, // note: 2400 is a valid time, will be wrapped to 0000
              let minutes = Int(hhmmString.suffix(2)), 0 <= minutes && minutes < 60
        else { return nil }

        secondsSinceMidnight = (TimeInterval(hours) * 3600 + TimeInterval(minutes) * 60).truncatingRemainder(dividingBy: 24 * 60 * 60)
    }
    /// A time of day initialised from a date
    init(date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        self.init(
            secondsSinceMidnight: TimeInterval(
                components.hour! * 60 * 60 +
                components.minute! * 60 +
                components.second!
            )
        )
    }
    /// A time of day as the hour, minute, and second values as integers. No validation done.
    init(hh: Int = 0, mm: Int = 0, ss: Int = 0) {
        secondsSinceMidnight = Double(hh * 3600 + mm * 60 + ss)
    }

    /// Obtains the time delta that has elapsed since a previous `TimeOfDay`. `other` is assumed to be before
    /// `self`.
    func timeDelta(since other: TimeOfDay, wrapMidnight: Bool = true) -> TimeDelta {
        var rawSeconds = self.secondsSinceMidnight - other.secondsSinceMidnight

        if rawSeconds < 0, wrapMidnight {
            // Wrap midnight accounts for timings that are negative. For example,
            // when you have 00:01 - 23:59. In absolute terms, this is -23h58min, but the
            // more likely case is that this is simply 2 minutes that wrapped around midnight
            rawSeconds += 24 * 60 * 60

            // if wrapMidnight is not true, this will simply return a negative number
        }

        return TimeDelta(seconds: rawSeconds)
    }

    /// Increments this time by a certain time delta, wrapping around 24H if nescessary.
    func incrementingBy(timeDelta: TimeDelta) -> TimeOfDay {
        TimeOfDay(
            secondsSinceMidnight: (self.secondsSinceMidnight + timeDelta.seconds)
                .remainder(dividingBy: 24 * 60 * 60)
        )
    }

    /// Checks if a time of day is bound between one or two other times of day.
    ///
    /// - If two reference points are given where the latest time is before the earliest time, it will return false.
    /// - If no reference points are given, it will return true.
    func isBetween(earliest: TimeOfDay? = nil, latest: TimeOfDay? = nil) -> Bool {
        if let earliest, let latest,
           latest.secondsSinceMidnight < earliest.secondsSinceMidnight {
            return false
        }

        if let earliest, earliest.secondsSinceMidnight > self.secondsSinceMidnight {
            return false
        }

        if let latest, self.secondsSinceMidnight > latest.secondsSinceMidnight {
            return false
        }

        return true
    }

    // Codable
    func encode(to encoder: any Encoder) throws {
        try String(format: "%04d", hh * 100 + mm).encode(to: encoder)
    }
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawString = try container.decode(String.self)
        if let initialised = TimeOfDay(hhmmString: rawString) {
            self = initialised
        } else {
            throw DecodingError.dataCorrupted( .init(
                codingPath: decoder.codingPath,
                debugDescription: "TimeOfDay string did not follow HHmm format"
            ))
        }
    }
}
