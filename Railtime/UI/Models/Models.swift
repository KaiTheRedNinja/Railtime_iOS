import Foundation
import CoreLocation
import SwiftUI
import LTAAPI

enum StationCrowdLevel: String, Codable {
    case low = "l"
    case moderate = "m"
    case high = "h"
    case unknown = ""

    var displayText: String {
        switch self {
        case .low: return "Low Crowd"
        case .moderate: return "Moderate Crowd"
        case .high: return "High Crowd"
        case .unknown: return "Normal"
        }
    }

    var subtitleText: String {
        switch self {
        case .low: return "Plenty of space on platform"
        case .moderate: return "Normal passenger volume"
        case .high: return "High passenger volume"
        case .unknown: return "Live status unavailable"
        }
    }

    var color: Color {
        switch self {
        case .low: return .green
        case .moderate: return .orange
        case .high: return .red
        case .unknown: return .gray
        }
    }

    var iconName: String {
        switch self {
        case .low: return "person.2.fill"
        case .moderate: return "person.3.fill"
        case .high: return "person.3.sequence.fill"
        case .unknown: return "person.fill"
        }
    }
}

struct StationLineCrowd: Identifiable {
    var id: String { stationCode }
    let lineCode: String // e.g. "NS", "TE"
    let stationCode: String // e.g. "NS22"
    let crowdLevel: StationCrowdLevel
}

struct BusTimingInfo: Identifiable, Hashable {
    let id = UUID()
    let rawArrival: String?
    let load: BusLoad?
    let busType: BusType?
    let isWheelchairAccessible: Bool
    let destinationCode: String?
    
    init(rawArrival: String?, loadStr: String?, typeStr: String?, featureStr: String?, destinationCode: String? = nil) {
        self.rawArrival = rawArrival
        self.load = BusLoad(rawValue: loadStr ?? "")
        self.busType = BusType(rawValue: typeStr ?? "")
        self.isWheelchairAccessible = (featureStr == "WAB")
        self.destinationCode = destinationCode
    }
    
    var minutesRemaining: Int? {
        guard let raw = rawArrival, !raw.isEmpty else { return nil }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var arrivalDate = formatter.date(from: raw)
        
        if arrivalDate == nil {
            formatter.formatOptions = [.withInternetDateTime]
            arrivalDate = formatter.date(from: raw)
        }
        
        guard let date = arrivalDate else { return nil }
        let diff = date.timeIntervalSinceNow
        let mins = Int(ceil(diff / 60.0))
        return max(0, mins)
    }
}

struct BusArrival: Identifiable, Hashable {
    var id: String { serviceNo }
    let serviceNo: String
    let operatorName: String?
    let nextBus: BusTimingInfo?
    let subsequentBus: BusTimingInfo?
    let thirdBus: BusTimingInfo?
    let destinationCode: String?
    let destinationName: String?
}

// MARK: - Bus Service Route & Preseeded Models
struct BusRouteStop: Identifiable, Hashable {
    var id: String { "\(direction)_\(stopSequence)_\(busStopCode)" }

    var stopInfo: LTABusRouteRow
    var busStop: BusStop?
    var nearbyStation: Station?

    var serviceNo: String { stopInfo.serviceNo }
    var busStopCode: String { stopInfo.busStopCode }
    var stopSequence: Int { stopInfo.stopSequence }
    var direction: Int { stopInfo.direction }
    var distance: Double? { stopInfo.distance }
    var wdFirstBus: String? { stopInfo.wdFirstBus?.hhmmOriginal }
    var wdLastBus: String? { stopInfo.wdLastBus?.hhmmOriginal }
    var satFirstBus: String? { stopInfo.satFirstBus?.hhmmOriginal }
    var satLastBus: String? { stopInfo.satLastBus?.hhmmOriginal }
    var sunFirstBus: String? { stopInfo.sunFirstBus?.hhmmOriginal }
    var sunLastBus: String? { stopInfo.sunLastBus?.hhmmOriginal }

    init(stopInfo: LTABusRouteRow, busStop: BusStop? = nil, nearbyStation: Station? = nil) {
        self.busStop = busStop
        self.nearbyStation = nearbyStation
        self.stopInfo = stopInfo
    }
}

struct BusServiceRoute: Identifiable, Hashable {
    var id: String { serviceNo }
    let serviceNo: String
    let operatorName: String?
    let direction1Stops: [BusRouteStop]
    let direction2Stops: [BusRouteStop]
    
    var direction1Terminal: String {
        direction1Stops.last?.busStop?.name ?? direction1Stops.last?.busStopCode ?? "Terminal 1"
    }
    
    var direction2Terminal: String {
        if direction2Stops.isEmpty {
            return direction1Terminal
        }
        return direction2Stops.last?.busStop?.name ?? direction2Stops.last?.busStopCode ?? "Terminal 2"
    }
}

// MARK: - Train First & Last Schedules

struct TrainDirectionSchedule: Identifiable, Hashable {
    let id = UUID()
    let destination: String
    let weekdayFirst: String
    let sundayFirst: String
    let dailyLast: String
}

struct LineTrainSchedule: Identifiable, Hashable {
    var id: String { lineCode }
    let lineCode: String
    let lineName: String
    let directions: [TrainDirectionSchedule]
}

// MARK: - Navigation & Map Models

enum TransitItem: Hashable {
    case station(Station)
    case busStop(BusStop)
}

struct BusServiceDetail: Hashable {
    let serviceNo: String
    let originStopCode: String?
}
