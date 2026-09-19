//
//  LTATrainAlertsResponse.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 19/9/26.
//

import Foundation

public struct LTATrainAlertsResponse: Codable {
    public let value: LTATrainAlertValue?
}

public struct LTATrainAlertValue: Codable {
    public let status: Int?
    public let message: [LTATrainAlertMessage]?

    public enum CodingKeys: String, CodingKey {
        case status = "Status"
        case message = "Message"
    }
}

public struct LTATrainAlertMessage: Codable {
    public let content: String?

    public enum CodingKeys: String, CodingKey {
        case content = "Content"
    }
}
