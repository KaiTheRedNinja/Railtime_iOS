import Foundation
import CoreLocation
import SwiftUI

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

struct BusStop: Identifiable, Hashable, Codable {
    let id: String // Bus stop code e.g. "09048"
    let name: String // e.g. "Orchard Stn/Tang Plaza"
    let roadName: String // e.g. "Orchard Rd"
    let coordinate: CLLocationCoordinate2D
    
    func distance(from refCoordinate: CLLocationCoordinate2D?) -> Double? {
        guard let refCoordinate = refCoordinate else { return nil }
        let refLoc = CLLocation(latitude: refCoordinate.latitude, longitude: refCoordinate.longitude)
        let stopLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return refLoc.distance(from: stopLoc)
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

struct StationExit: Identifiable, Hashable, Codable {
    var id: String { code }
    let code: String // e.g. "Exit A", "Exit B", "Exit 1"
    let description: String // e.g. "ION Orchard, Tang Plaza, Wheelock Place"
    let latitude: Double?
    let longitude: Double?
    
    enum CodingKeys: String, CodingKey {
        case code
        case description
        case latitude
        case longitude
    }
    
    init(code: String, description: String, latitude: Double? = nil, longitude: Double? = nil) {
        self.code = code
        self.description = description
        self.latitude = latitude
        self.longitude = longitude
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.code = try container.decode(String.self, forKey: .code)
        self.description = try container.decode(String.self, forKey: .description)
        self.latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        self.longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(code, forKey: .code)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
    }
    
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

struct Station: Identifiable, Hashable, Codable {
    let id: String // Station code (e.g. "NS22/TE14")
    let name: String // Station name (e.g. "Orchard")
    let coordinate: CLLocationCoordinate2D
    let lines: [String]
    let exits: [StationExit]
    let chineseName: String?
    let tamilName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case coordinate
        case latitude
        case longitude
        case lines
        case exits
        case chineseName
        case tamilName
    }
    
    init(
        id: String,
        name: String,
        coordinate: CLLocationCoordinate2D,
        lines: [String],
        exits: [StationExit] = [],
        chineseName: String? = nil,
        tamilName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.lines = lines
        self.exits = exits
        self.chineseName = chineseName
        self.tamilName = tamilName
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.lines = try container.decode([String].self, forKey: .lines)
        self.exits = try container.decodeIfPresent([StationExit].self, forKey: .exits) ?? []
        self.chineseName = try container.decodeIfPresent(String.self, forKey: .chineseName)
        self.tamilName = try container.decodeIfPresent(String.self, forKey: .tamilName)
        
        if let lat = try container.decodeIfPresent(Double.self, forKey: .latitude),
           let lon = try container.decodeIfPresent(Double.self, forKey: .longitude) {
            self.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else if let coord = try container.decodeIfPresent(CLLocationCoordinate2D.self, forKey: .coordinate) {
            self.coordinate = coord
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.latitude,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing latitude/longitude or coordinate properties")
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(coordinate, forKey: .coordinate)
        try container.encode(lines, forKey: .lines)
        try container.encode(exits, forKey: .exits)
        try container.encodeIfPresent(chineseName, forKey: .chineseName)
        try container.encodeIfPresent(tamilName, forKey: .tamilName)
    }
    
    static func == (lhs: Station, rhs: Station) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    
    func distance(from refCoordinate: CLLocationCoordinate2D?) -> Double? {
        guard let refCoordinate = refCoordinate else { return nil }
        let refLoc = CLLocation(latitude: refCoordinate.latitude, longitude: refCoordinate.longitude)
        let stationLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
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

// MARK: - Bus Arrival Models

enum BusLoad: String {
    case seatsAvailable = "SEA"
    case standingAvailable = "SDA"
    case limitedStanding = "LSD"
    case unknown = ""
    
    var displayText: String {
        switch self {
        case .seatsAvailable: return "Seats Available"
        case .standingAvailable: return "Standing Available"
        case .limitedStanding: return "Limited Standing"
        case .unknown: return "No Data"
        }
    }
    
    var color: Color {
        switch self {
        case .seatsAvailable: return .green
        case .standingAvailable: return .orange
        case .limitedStanding: return .red
        case .unknown: return .gray
        }
    }
}

enum BusType: String {
    case singleDeck = "SD"
    case doubleDeck = "DD"
    case articulated = "BD"
    case unknown = ""
    
    var displayText: String {
        switch self {
        case .singleDeck: return "Single Deck"
        case .doubleDeck: return "Double Deck"
        case .articulated: return "Bendy"
        case .unknown: return "Bus"
        }
    }
}

struct BusTimingInfo: Identifiable, Hashable {
    let id = UUID()
    let rawArrival: String?
    let load: BusLoad
    let busType: BusType
    let isWheelchairAccessible: Bool
    let destinationCode: String?
    
    init(rawArrival: String?, loadStr: String?, typeStr: String?, featureStr: String?, destinationCode: String? = nil) {
        self.rawArrival = rawArrival
        self.load = BusLoad(rawValue: loadStr ?? "") ?? .unknown
        self.busType = BusType(rawValue: typeStr ?? "") ?? .unknown
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

struct PreseededBusStop: Codable {
    let busStopCode: String
    let direction: Int
    let stopSequence: Int
    let distance: Double?
    let wdFirstBus: String?
    let wdLastBus: String?
    let satFirstBus: String?
    let satLastBus: String?
    let sunFirstBus: String?
    let sunLastBus: String?
}

struct PreseededBusService: Codable {
    let serviceNo: String
    let operatorName: String?
    let stops: [PreseededBusStop]
    
    enum CodingKeys: String, CodingKey {
        case serviceNo
        case operatorName = "operator"
        case stops
    }
}

struct BusRouteStop: Identifiable, Hashable {
    var id: String { "\(direction)_\(stopSequence)_\(busStopCode)" }
    let serviceNo: String
    let busStopCode: String
    let stopSequence: Int
    let direction: Int
    let distance: Double?
    let busStop: BusStop?
    let nearbyStation: Station?
    let wdFirstBus: String?
    let wdLastBus: String?
    let satFirstBus: String?
    let satLastBus: String?
    let sunFirstBus: String?
    let sunLastBus: String?
    
    init(
        serviceNo: String,
        busStopCode: String,
        stopSequence: Int,
        direction: Int,
        distance: Double?,
        busStop: BusStop?,
        nearbyStation: Station?,
        wdFirstBus: String? = nil,
        wdLastBus: String? = nil,
        satFirstBus: String? = nil,
        satLastBus: String? = nil,
        sunFirstBus: String? = nil,
        sunLastBus: String? = nil
    ) {
        self.serviceNo = serviceNo
        self.busStopCode = busStopCode
        self.stopSequence = stopSequence
        self.direction = direction
        self.distance = distance
        self.busStop = busStop
        self.nearbyStation = nearbyStation
        self.wdFirstBus = wdFirstBus
        self.wdLastBus = wdLastBus
        self.satFirstBus = satFirstBus
        self.satLastBus = satLastBus
        self.sunFirstBus = sunFirstBus
        self.sunLastBus = sunLastBus
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

// MARK: - LTA API Responses

struct LTABusArrivalResponse: Codable {
    let busStopCode: String?
    let services: [LTABusServiceItem]?
    
    enum CodingKeys: String, CodingKey {
        case busStopCode = "BusStopCode"
        case services = "Services"
    }
}

struct LTABusServiceItem: Codable {
    let serviceNo: String
    let busOperator: String?
    let nextBus: LTABusTimingItem?
    let nextBus2: LTABusTimingItem?
    let nextBus3: LTABusTimingItem?
    
    enum CodingKeys: String, CodingKey {
        case serviceNo = "ServiceNo"
        case busOperator = "Operator"
        case nextBus = "NextBus"
        case nextBus2 = "NextBus2"
        case nextBus3 = "NextBus3"
    }
}

struct LTABusTimingItem: Codable {
    let estimatedArrival: String?
    let latitude: String?
    let longitude: String?
    let load: String?
    let feature: String?
    let type: String?
    let destinationCode: String?
    
    enum CodingKeys: String, CodingKey {
        case estimatedArrival = "EstimatedArrival"
        case latitude = "Latitude"
        case longitude = "Longitude"
        case load = "Load"
        case feature = "Feature"
        case type = "Type"
        case destinationCode = "DestinationCode"
    }
}

struct LTABusStopsResponse: Codable {
    let value: [LTABusStopItem]
}

struct LTABusStopItem: Codable {
    let busStopCode: String
    let roadName: String
    let description: String
    let latitude: Double
    let longitude: Double
    
    enum CodingKeys: String, CodingKey {
        case busStopCode = "BusStopCode"
        case roadName = "RoadName"
        case description = "Description"
        case latitude = "Latitude"
        case longitude = "Longitude"
    }
}

struct LTABusRoutesResponse: Codable {
    let value: [LTABusRouteItem]
}

struct LTABusRouteItem: Codable {
    let serviceNo: String
    let busOperator: String?
    let direction: Int
    let stopSequence: Int
    let busStopCode: String
    let distance: Double?
    let wdFirstBus: String?
    let wdLastBus: String?
    let satFirstBus: String?
    let satLastBus: String?
    let sunFirstBus: String?
    let sunLastBus: String?
    
    enum CodingKeys: String, CodingKey {
        case serviceNo = "ServiceNo"
        case busOperator = "Operator"
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
}

struct LTAPCDRealTimeResponse: Codable {
    let value: [LTAPCDRealTimeItem]?
}

struct LTAPCDRealTimeItem: Codable {
    let station: String?
    let crowdLevel: String?
    
    enum CodingKeys: String, CodingKey {
        case station = "Station"
        case crowdLevel = "CrowdLevel"
    }
}

struct LTATrainAlertsResponse: Codable {
    let value: LTATrainAlertValue?
}

struct LTATrainAlertValue: Codable {
    let status: Int?
    let message: [LTATrainAlertMessage]?
    
    enum CodingKeys: String, CodingKey {
        case status = "Status"
        case message = "Message"
    }
}

struct LTATrainAlertMessage: Codable {
    let content: String?
    
    enum CodingKeys: String, CodingKey {
        case content = "Content"
    }
}
