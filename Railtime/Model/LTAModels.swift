import Foundation

// --------------------------------------------------------------------------
// Data models for the LTA DataMall API
//
// The original Python client passed raw dictionaries around; these
// structures give the same fields a concrete, typed shape for Swift.
// --------------------------------------------------------------------------

/// Generic wrapper for LTA DataMall's paginated `{"value": [...]}` envelope,
/// used by BusRoutes, BusServices, and BusStops.
struct LTAPagedResponse<Value: Decodable>: Decodable {
    /// The page of records returned by the API.
    let value: [Value]
}

/// A single row from the 2.3 BusRoutes endpoint: one (service, direction,
/// stop-sequence) entry along a route.
struct BusRouteRow: Codable {
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

/// A single row from the 2.2 BusServices endpoint: static, frequency-level
/// information about a bus service.
struct BusServiceInfo: Codable {
    /// The bus service number, e.g. "15".
    let serviceNo: String
    /// The bus operator code, e.g. "SBST".
    let `operator`: String
    /// The direction of travel this frequency information applies to.
    let direction: Int
    /// The service category, e.g. "TRUNK".
    let category: String?
    /// The bus stop code of this service's origin.
    let originCode: String?
    /// The bus stop code of this service's destination.
    let destinationCode: String?
    /// AM peak dispatch frequency, formatted as a "lo-hi" minute band.
    let amPeakFreq: String?
    /// AM off-peak dispatch frequency, formatted as a "lo-hi" minute band.
    let amOffpeakFreq: String?
    /// PM peak dispatch frequency, formatted as a "lo-hi" minute band.
    let pmPeakFreq: String?
    /// PM off-peak dispatch frequency, formatted as a "lo-hi" minute band.
    let pmOffpeakFreq: String?
    /// Free-text description of the loop, if this service loops.
    let loopDesc: String?

    enum CodingKeys: String, CodingKey {
        case serviceNo = "ServiceNo"
        case `operator` = "Operator"
        case direction = "Direction"
        case category = "Category"
        case originCode = "OriginCode"
        case destinationCode = "DestinationCode"
        case amPeakFreq = "AM_Peak_Freq"
        case amOffpeakFreq = "AM_Offpeak_Freq"
        case pmPeakFreq = "PM_Peak_Freq"
        case pmOffpeakFreq = "PM_Offpeak_Freq"
        case loopDesc = "LoopDesc"
    }
}

/// A single row from the 2.4 BusStops endpoint: static information about a
/// physical bus stop.
struct BusStopInfo: Codable {
    /// The bus stop code.
    let busStopCode: String
    /// The name of the road the stop is on.
    let roadName: String?
    /// A human-readable description of the stop (often its landmark name).
    let description: String?
    /// The stop's latitude, in degrees.
    let latitude: Double
    /// The stop's longitude, in degrees.
    let longitude: Double

    enum CodingKeys: String, CodingKey {
        case busStopCode = "BusStopCode"
        case roadName = "RoadName"
        case description = "Description"
        case latitude = "Latitude"
        case longitude = "Longitude"
    }
}

/// The 2.1 BusArrival endpoint's response envelope for a single bus stop.
struct BusArrivalResponse: Decodable {
    /// The bus stop code these arrivals apply to.
    let busStopCode: String
    /// Per-service arrival information at this stop (filtered to a single
    /// service when `ServiceNo` was passed to the request).
    let services: [BusArrivalServiceEntry]

    enum CodingKeys: String, CodingKey {
        case busStopCode = "BusStopCode"
        case services = "Services"
    }
}

/// One bus service's live arrival information at a stop, as returned by the
/// 2.1 BusArrival endpoint.
struct BusArrivalServiceEntry: Decodable {
    /// The bus service number.
    let serviceNo: String
    /// The bus operator code.
    let `operator`: String?
    /// The next bus expected at this stop, if any.
    let nextBus: NextBusInfo?
    /// The second-next bus expected at this stop, if any.
    let nextBus2: NextBusInfo?
    /// The third-next bus expected at this stop, if any.
    let nextBus3: NextBusInfo?

    enum CodingKeys: String, CodingKey {
        case serviceNo = "ServiceNo"
        case `operator` = "Operator"
        case nextBus = "NextBus"
        case nextBus2 = "NextBus2"
        case nextBus3 = "NextBus3"
    }

    /// Returns [nextBus, nextBus2, nextBus3] in order, mirroring the
    /// Python code's `for key in ("NextBus", "NextBus2", "NextBus3")` loops.
    var nextBuses: [NextBusInfo?] {
        [nextBus, nextBus2, nextBus3]
    }
}

/// Live tracking information for a single upcoming bus, as returned by the
/// 2.1 BusArrival endpoint's NextBus/NextBus2/NextBus3 fields.
struct NextBusInfo: Decodable {
    /// The bus stop code of this bus's origin.
    let originCode: String?
    /// The bus stop code of this bus's destination.
    let destinationCode: String?
    /// The estimated arrival time at the queried stop, as an ISO-8601
    /// timestamp string.
    let estimatedArrival: String?
    /// The bus's last-known latitude.
    let latitude: String?
    /// The bus's last-known longitude.
    let longitude: String?
    /// The bus's visit number at this stop (1 = first visit this trip).
    let visitNumber: String?
    /// The bus's passenger load, e.g. "SEA", "SDA", "LSD".
    let load: String?
    /// Bus features, e.g. "WAB" for wheelchair-accessible.
    let feature: String?
    /// The bus type, e.g. "SD" (single-deck), "DD" (double-deck), "BD" (bendy).
    let type: String?

    enum CodingKeys: String, CodingKey {
        case originCode = "OriginCode"
        case destinationCode = "DestinationCode"
        case estimatedArrival = "EstimatedArrival"
        case latitude = "Latitude"
        case longitude = "Longitude"
        case visitNumber = "VisitNumber"
        case load = "Load"
        case feature = "Feature"
        case type = "Type"
    }
}
