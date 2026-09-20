//
//  TrainLine.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 20/9/26.
//

import Foundation

/// An MRT/LRT line
public enum TrainLine: Equatable, Codable {
    case northSouth
    case eastWest
    case northEast
    case circle
    case downtown
    case thomsonEastCoast
    case bukitPanjang
    case sengkang
    case punggol

    /// The two-letter prefix that goes before a station, eg. "EW8"
    public var stationCodePrefix: String {
        switch self {
        case .northSouth: "NS"
        case .eastWest: "EW"
        case .northEast: "NE"
        case .circle: "CC" // NOTE: circle line also goes by CE
        case .downtown: "DT"
        case .thomsonEastCoast: "TE"
        case .bukitPanjang: "BP"
        case .sengkang: "SE"
        case .punggol: "PE"
        }
    }

    /// The three-to-four-letter acronym for the line itself
    public var lineAcronym: String {
        switch self {
        case .northSouth: "NSL"
        case .eastWest: "EWL"
        case .northEast: "NEL"
        case .circle: "CCL"
        case .downtown: "DTL"
        case .thomsonEastCoast: "TEL"
        case .bukitPanjang: "BPL"
        case .sengkang: "SLRT"
        case .punggol: "PLRT"
        }
    }

    /// Creates a line from either a station prefix or a line acronym
    public init?(_ string: String) {
        switch string {
        case "NS", "NSL": self = .northSouth
        case "EW", "EWL": self = .eastWest
        case "NE", "NEL": self = .northEast
        case "CC", "CE", "CCL": self = .circle
        case "DT", "DTL": self = .downtown
        case "TE", "TEL": self = .thomsonEastCoast
        case "BP", "BPL": self = .bukitPanjang
        case "SE", "SLRT": self = .sengkang
        case "PE", "PLRT": self = .punggol
        default: return nil
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        if let value = Self(string) {
            self = value
        } else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Decoded string was not a station prefix or line acronym"
                )
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stationCodePrefix)
    }
}
