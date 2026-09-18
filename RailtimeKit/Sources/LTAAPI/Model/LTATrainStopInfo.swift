//
//  LTATrainStopInfo.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 18/9/26.
//

public struct LTATrainStopInfo: Equatable, Codable {
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
    }
}
