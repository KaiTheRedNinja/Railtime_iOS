//
//  LTATrainStopInfo.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 18/9/26.
//

public struct LTATrainStopInfo: Equatable, Codable {
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

    /// The details about an exit to a station
    public struct Exit: Equatable, Codable {
        /// The code for the stop, eg "Exit A"
        var code: String
        /// The description for what this exit corresponds to
        var description: String

        public init(code: String, description: String) {
            self.code = code
            self.description = description
        }
    }

    public init(
        id: String,
        description: String?,
        latitude: Double,
        longitude: Double,
        lines: [String],
        exits: [Exit]
    ) {
        self.id = id
        self.description = description
        self.latitude = latitude
        self.longitude = longitude
        self.lines = lines
        self.exits = exits
    }
}
