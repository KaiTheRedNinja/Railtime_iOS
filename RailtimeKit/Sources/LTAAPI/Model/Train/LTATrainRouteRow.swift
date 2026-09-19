//
//  LTAMRTRouteRow.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 18/9/26.
//

/// Information about the routes that a train service can take
public struct LTATrainRoutes: Codable {
    /// The MRT service code, e.g. "NE" for North-East Line
    public let code: String
    /// The MRT operator code, e.g. "SBST".
    public let `operator`: String
    /// The colour for this MRT line
    public let color: String
    /// The terminal station IDs
    public let termini: [String]
    /// A list of station IDs, in no guaranteed order
    public let stations: [String]
    /// The station IDs in start-to-end order, per direction
    public let directions: [String: [String]]

    enum CodingKeys: CodingKey {
        case code
        case `operator`
        case color
        case termini
        case stations
        case directions
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.code, forKey: .code)
        try container.encode(self.operator, forKey: .operator)
        try container.encode(self.color, forKey: .color)
        try container.encode(self.termini, forKey: .termini)
        try container.encode(self.stations, forKey: .stations)
        try container.encode(self.directions, forKey: .directions)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.code = try container.decode(String.self, forKey: .code)
        self.operator = try container.decode(String.self, forKey: .operator)
        self.color = try container.decode(String.self, forKey: .color)
        self.termini = try container.decodeIfPresent([String].self, forKey: .termini) ?? []
        self.stations = try container.decode([String].self, forKey: .stations)
        self.directions = try container.decode([String: [String]].self, forKey: .directions)
    }
}
