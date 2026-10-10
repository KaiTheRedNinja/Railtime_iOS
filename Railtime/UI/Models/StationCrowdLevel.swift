//
//  StationCrowdLevel.swift
//  Railtime
//
//  Created by Kai Quan Tay on 10/10/26.
//

import Foundation
import CoreLocation
import SwiftUI
import LTAAPI
import BusEstimation

enum StationCrowdLevel: String, Codable {
    case low = "l"
    case moderate = "m"
    case high = "h"
    case unknown = ""

    var displayText: String {
        switch self {
        case .low: return "Low Crowd"
        case .moderate: return "Moderate Crowd"
        case .high: return "High Crowd"
        case .unknown: return "Normal"
        }
    }

    var subtitleText: String {
        switch self {
        case .low: return "Plenty of space on platform"
        case .moderate: return "Normal passenger volume"
        case .high: return "High passenger volume"
        case .unknown: return "Live status unavailable"
        }
    }

    var color: Color {
        switch self {
        case .low: return .green
        case .moderate: return .orange
        case .high: return .red
        case .unknown: return .gray
        }
    }

    var iconName: String {
        switch self {
        case .low: return "person.2.fill"
        case .moderate: return "person.3.fill"
        case .high: return "person.3.sequence.fill"
        case .unknown: return "person.fill"
        }
    }
}

struct StationLineCrowd: Identifiable {
    var id: String { stationCode }
    let lineCode: String // e.g. "NS", "TE"
    let stationCode: String // e.g. "NS22"
    let crowdLevel: StationCrowdLevel
}
