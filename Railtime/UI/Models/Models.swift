import Foundation
import CoreLocation
import SwiftUI
import LTAAPI
import BusEstimation

struct BusServiceArrivals: Identifiable {
    var stopId: String
    var serviceNo: String
    var operatorName: String?
    var destinationCode: String?
    var destinationName: String?
    var arrivals: [BusArrivalEstimate]

    var id: String { serviceNo }
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
