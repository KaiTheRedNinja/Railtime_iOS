//
//  LTAPCDRealTimeResponse.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 19/9/26.
//

import Foundation

public struct LTAPCDRealTimeResponse: Codable {
    public let value: [LTAPCDRealTimeItem]?
}

public struct LTAPCDRealTimeItem: Codable {
    public let station: String?
    public let crowdLevel: String?

    public enum CodingKeys: String, CodingKey {
        case station = "Station"
        case crowdLevel = "CrowdLevel"
    }
}
