//
//  LTANextBusInfo.swift
//  Railtime
//
//  Created by Kai Quan Tay on 5/9/26.
//

import Foundation

/// Live tracking information for a single upcoming bus, as returned by the
/// 2.1 BusArrival endpoint's NextBus/NextBus2/NextBus3 fields.
public struct LTANextBusInfo: Decodable {
    /// The bus stop code of this bus's origin.
    public let originCode: String?
    /// The bus stop code of this bus's destination.
    public let destinationCode: String?
    /// The estimated arrival time at the queried stop, as an ISO-8601
    /// timestamp string.
    public let estimatedArrival: String?
    /// The bus's last-known latitude.
    public let latitude: String?
    /// The bus's last-known longitude.
    public let longitude: String?
    /// The bus's visit number at this stop (1 = first visit this trip).
    public let visitNumber: String?
    /// The bus's passenger load, e.g. "SEA", "SDA", "LSD".
    public let load: Load?
    /// Bus features, e.g. "WAB" for wheelchair-accessible.
    public let feature: String?
    /// The bus type, e.g. "SD" (single-deck), "DD" (double-deck), "BD" (bendy).
    public let type: BusVariant?

    public enum CodingKeys: String, CodingKey {
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

    public enum Load: String, Codable {
        case seatsAvailable = "SEA"
        case standingAvailable = "SDA"
        case limitedStanding = "LSD"
    }

    public enum BusVariant: String, Codable {
        case singleDeck = "SD"
        case doubleDeck = "DD"
        case bendy = "BD"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.originCode = try container.decodeIfPresent(String.self, forKey: .originCode)
        self.destinationCode = try container.decodeIfPresent(String.self, forKey: .destinationCode)
        self.estimatedArrival = try container.decodeIfPresent(String.self, forKey: .estimatedArrival)
        self.latitude = try container.decodeIfPresent(String.self, forKey: .latitude)
        self.longitude = try container.decodeIfPresent(String.self, forKey: .longitude)
        self.visitNumber = try container.decodeIfPresent(String.self, forKey: .visitNumber)

        self.load = try? container.decodeIfPresent(LTANextBusInfo.Load.self, forKey: .load)
        self.feature = try? container.decodeIfPresent(String.self, forKey: .feature)
        self.type = try? container.decodeIfPresent(LTANextBusInfo.BusVariant.self, forKey: .type)
    }
}
