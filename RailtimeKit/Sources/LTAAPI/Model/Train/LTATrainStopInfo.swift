//
//  LTATrainStopInfo.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 18/9/26.
//

public struct LTATrainStopInfo: Hashable, Codable {
    /// The mrt stop code. For interchanges, this may have multiple lines.
    public let id: String
    /// The mrt stop code, under a proper name for compatibility
    public var mrtStopCode: String { id }
    /// The name of the stop
    public let description: String?
    /// The latitude of the stop
    public let latitude: Double
    /// The longitude of the stop
    public let longitude: Double
    /// The lines that this stop serves
    public let lines: [String]
    /// The exits available
    public let exits: [Exit]

    /// The Chinese name
    public let chineseName: String?
    /// The Tamil name
    public let tamilName: String?

    /// The details about an exit to a station
    public struct Exit: Hashable, Codable {
        /// The code for the stop, eg "Exit A"
        public var code: String
        /// The description for what this exit corresponds to
        public var description: String
        /// The latitude for the exit, if any
        public var latitude: Double?
        /// The longitude for the exit, if any
        public var longitude: Double?

        public init(code: String, description: String, latitude: Double?, longitude: Double?) {
            self.code = code
            self.description = description
            self.latitude = latitude
            self.longitude = longitude
        }
    }

    public init(
        id: String,
        description: String?,
        latitude: Double,
        longitude: Double,
        lines: [String],
        exits: [Exit],
        chineseName: String?,
        tamilName: String?
    ) {
        self.id = id
        self.description = description
        self.latitude = latitude
        self.longitude = longitude
        self.lines = lines
        self.exits = exits
        self.chineseName = chineseName
        self.tamilName = tamilName
    }

    enum CodingKeys: CodingKey {
        case id
        case name
        case latitude
        case longitude
        case lines
        case exits
        case chineseName
        case tamilName
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.description = try container.decodeIfPresent(String.self, forKey: .name)
        self.latitude = try container.decode(Double.self, forKey: .latitude)
        self.longitude = try container.decode(Double.self, forKey: .longitude)
        self.lines = try container.decode([String].self, forKey: .lines)
        self.exits = try container.decodeIfPresent([LTATrainStopInfo.Exit].self, forKey: .exits) ?? []
        self.chineseName = try container.decodeIfPresent(String.self, forKey: .chineseName)
        self.tamilName = try container.decodeIfPresent(String.self, forKey: .tamilName)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(description, forKey: .name)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(lines, forKey: .lines)
        try container.encode(exits, forKey: .exits)
        try container.encode(chineseName, forKey: .chineseName)
        try container.encode(tamilName, forKey: .tamilName)
    }
}
