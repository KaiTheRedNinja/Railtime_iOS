//
//  LTAMRTScheduleResponse.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 18/9/26.
//

import Foundation

struct LTAMRTScheduleResponse: Codable {
    var value: [Body]

    struct Body: Codable {
        var timestamp: String
        var link: String
    }
}
