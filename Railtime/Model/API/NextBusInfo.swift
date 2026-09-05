//
//  NextBusInfo.swift
//  Railtime
//
//  Created by Kai Quan Tay on 5/9/26.
//

import Foundation

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
