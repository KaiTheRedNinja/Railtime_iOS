//
//  RailtimeKit+Extensions.swift
//  Railtime
//
//  Created by Kai Quan Tay on 8/10/26.
//

import Foundation
import CoreLocation
import SwiftUI
import LTAAPI

// MARK: - CoreLocation Extensions for Codable

extension CLLocationCoordinate2D: @retroactive Codable {
    enum CodingKeys: String, CodingKey {
        case latitude, longitude
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: lat, longitude: lon)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
}

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

extension CLLocationCoordinate2D: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
}

// MARK: - Bus Stop & Station Models

extension LTABusStopInfo: @retroactive Identifiable {
    public var id: String { busStopCode }
    public var name: String { description ?? "N/A" }
    public var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }

    func distance(from refCoordinate: CLLocationCoordinate2D?) -> Double? {
        guard let refCoordinate = refCoordinate else { return nil }
        let refLoc = CLLocation(latitude: refCoordinate.latitude, longitude: refCoordinate.longitude)
        let stopLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return refLoc.distance(from: stopLoc)
    }

    /// Returns one of the following:
    /// - `"N"` for North
    /// - `"NE"` for North-East
    /// - `"E"` for East
    /// - `"SE"` for South-East
    /// - `"S"` for South
    /// - `"SW"` for South-West
    /// - `"W"` for West
    /// - `"NW"` for North-West
    func direction(from refCoordinate: CLLocationCoordinate2D) -> String {
        // determine the bearing from lat1 to lat2
        let lat1 = refCoordinate.latitude * .pi / 180
        let lon1 = refCoordinate.longitude * .pi / 180
        let lat2 = self.latitude * .pi / 180
        let lon2 = self.longitude * .pi / 180
        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) -
        sin(lat1) * cos(lat2) * cos(dLon)

        let radiansBearing = atan2(y, x)
        let degreesBearing = radiansBearing * 180 / .pi

        let bearing = (degreesBearing + 360).truncatingRemainder(dividingBy: 360)

        // correspond it to a direction
        let directions = [
            "N", "NE", "E", "SE",
            "S", "SW", "W", "NW"
        ]

        // each "slice" is 45 degrees, adding 22.5 centers the slice (otherwise north would be between slices 0 and 7)
        let index = Int((bearing + 22.5) / 45.0) % 8
        return directions[index]
    }

    func formattedDistance(from refCoordinate: CLLocationCoordinate2D?) -> String? {
        guard let meters = distance(from: refCoordinate) else { return nil }
        let km = meters / 1000.0
        if km < 1.0 {
            return String(format: "%.2f km", km)
        } else {
            return String(format: "%.1f km", km)
        }
    }

    var isInterchange: Bool {
        let lower = name.lowercased()
        return lower.contains(" int") || lower.contains(" interchange") || lower.contains(" ter") || lower.contains(" terminal") || lower.hasSuffix(" int")
    }

    var iconName: String {
        isInterchange ? "bus_int" : "bus"
    }
}

typealias BusStop = LTABusStopInfo

extension LTATrainStopInfo.Exit: @retroactive Identifiable {
    public var id: String { code }

    var sfSymbolName: String {
        let trimmed = code.replacingOccurrences(of: "Exit", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if let firstChar = trimmed.first {
            if firstChar.isLetter || firstChar.isNumber {
                return "\(firstChar).circle.fill"
            }
        }
        return "door.left.hand.open"
    }

    func coordinate(for station: Station, index: Int, total: Int) -> CLLocationCoordinate2D {
        if let lat = latitude, let lon = longitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        let radius = 0.00035
        let angle = (2.0 * .pi / Double(max(1, total))) * Double(index)
        let latOffset = radius * cos(angle)
        let lonOffset = radius * sin(angle)
        return CLLocationCoordinate2D(
            latitude: station.coordinate.latitude + latOffset,
            longitude: station.coordinate.longitude + lonOffset
        )
    }
}

typealias StationExit = LTATrainStopInfo.Exit

extension LTATrainStopInfo: @retroactive Identifiable {
    public var id: String { mrtStopCode }

    var name: String { description ?? "N/A" }

    var coordinate: CLLocationCoordinate2D {
        .init(latitude: latitude, longitude: longitude)
    }

    func distance(from refCoordinate: CLLocationCoordinate2D?) -> Double? {
        guard let refCoordinate = refCoordinate else { return nil }
        let refLoc = CLLocation(latitude: refCoordinate.latitude, longitude: refCoordinate.longitude)
        let stationLoc = CLLocation(latitude: latitude, longitude: longitude)
        return refLoc.distance(from: stationLoc)
    }

    func formattedDistance(from refCoordinate: CLLocationCoordinate2D?) -> String? {
        guard let meters = distance(from: refCoordinate) else { return nil }
        let km = meters / 1000.0
        if km < 1.0 {
            return String(format: "%.2f km", km)
        } else {
            return String(format: "%.1f km", km)
        }
    }

    var isLRT: Bool {
        lines.contains { ["BP", "SE", "SW", "PE", "PW", "STC", "PTC"].contains($0) }
    }

    var iconName: String {
        isLRT ? "lrt" : "mrt"
    }
}

typealias Station = LTATrainStopInfo

// MARK: - Bus Arrival Models

extension LTANextBusInfo.Load {
    var displayText: String {
        switch self {
        case .seatsAvailable: return "Seats Available"
        case .standingAvailable: return "Standing Available"
        case .limitedStanding: return "Limited Standing"
        }
    }

    var color: Color {
        switch self {
        case .seatsAvailable: return .green
        case .standingAvailable: return .orange
        case .limitedStanding: return .red
        }
    }
}

typealias BusLoad = LTANextBusInfo.Load

extension LTANextBusInfo.BusVariant {
    var displayText: String {
        switch self {
        case .singleDeck: return "Single Deck"
        case .doubleDeck: return "Double Deck"
        case .bendy: return "Bendy"
        }
    }
}

typealias BusType = LTANextBusInfo.BusVariant
