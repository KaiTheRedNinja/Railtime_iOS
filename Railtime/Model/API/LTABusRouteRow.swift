//
//  LTABusRouteRow.swift
//  Railtime
//
//  Created by Kai Quan Tay on 5/9/26.
//

import Foundation

/// A single row from the 2.3 BusRoutes endpoint: one (service, direction,
/// stop-sequence) entry along a route.
struct LTABusRouteRow: Codable {
    /// The bus service number, e.g. "15".
    let serviceNo: String
    /// The bus operator code, e.g. "SBST".
    let `operator`: String
    /// The direction of travel for this route (1 or 2).
    let direction: Int
    /// This stop's 1-indexed position along the route in this direction.
    let stopSequence: Int
    /// The bus stop code for this stop along the route.
    let busStopCode: String
    /// Cumulative distance (km) from the origin stop of this route.
    let distance: Double

    /// Scheduled first-bus time on weekdays.
    let wdFirstBus: TimeOfDay?
    /// Scheduled last-bus time on weekdays.
    let wdLastBus: TimeOfDay?
    /// Scheduled first-bus time on Saturdays.
    let satFirstBus: TimeOfDay?
    /// Scheduled last-bus time on Saturdays.
    let satLastBus: TimeOfDay?
    /// Scheduled first-bus time on Sundays/public holidays.
    let sunFirstBus: TimeOfDay?
    /// Scheduled last-bus time on Sundays/public holidays.
    let sunLastBus: TimeOfDay?

    enum CodingKeys: String, CodingKey {
        case serviceNo = "ServiceNo"
        case `operator` = "Operator"
        case direction = "Direction"
        case stopSequence = "StopSequence"
        case busStopCode = "BusStopCode"
        case distance = "Distance"
        case wdFirstBus = "WD_FirstBus"
        case wdLastBus = "WD_LastBus"
        case satFirstBus = "SAT_FirstBus"
        case satLastBus = "SAT_LastBus"
        case sunFirstBus = "SUN_FirstBus"
        case sunLastBus = "SUN_LastBus"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.serviceNo = try container.decode(String.self, forKey: .serviceNo)
        self.operator = try container.decode(String.self, forKey: .operator)
        self.direction = try container.decode(Int.self, forKey: .direction)
        self.stopSequence = try container.decode(Int.self, forKey: .stopSequence)
        self.busStopCode = try container.decode(String.self, forKey: .busStopCode)
        self.distance = try container.decode(Double.self, forKey: .distance)

        // instead of "", LTA uses "-" to indicate an absence of information. This will not be decoded
        // by TimeOfDay, so we simply assume that all errors are from an absence of data.
        self.wdFirstBus = try? container.decodeIfPresent(TimeOfDay.self, forKey: .wdFirstBus) ?? nil
        self.wdLastBus = try? container.decodeIfPresent(TimeOfDay.self, forKey: .wdLastBus) ?? nil
        self.satFirstBus = try? container.decodeIfPresent(TimeOfDay.self, forKey: .satFirstBus) ?? nil
        self.satLastBus = try? container.decodeIfPresent(TimeOfDay.self, forKey: .satLastBus) ?? nil
        self.sunFirstBus = try? container.decodeIfPresent(TimeOfDay.self, forKey: .sunFirstBus) ?? nil
        self.sunLastBus = try? container.decodeIfPresent(TimeOfDay.self, forKey: .sunLastBus) ?? nil
    }

    /// Looks up one of this row's scheduled first/last-bus columns by name
    /// (e.g. "WD_FirstBus"), mirroring the Python code's `dict.get(target)`
    /// lookups against the raw BusRoutes row.
    ///
    /// - Parameter columnName: One of the six schedule column names, using
    ///   the same "{DayType}_{First|Last}Bus" naming as the raw API payload.
    /// - Returns: The "HHmm" string for that column, or `nil` if the column
    ///   name is unrecognised or the value is absent.
    func scheduleColumn(named columnName: String) -> TimeOfDay? {
        switch columnName {
        case "WD_FirstBus": return wdFirstBus
        case "WD_LastBus": return wdLastBus
        case "SAT_FirstBus": return satFirstBus
        case "SAT_LastBus": return satLastBus
        case "SUN_FirstBus": return sunFirstBus
        case "SUN_LastBus": return sunLastBus
        default: return nil
        }
    }
}
