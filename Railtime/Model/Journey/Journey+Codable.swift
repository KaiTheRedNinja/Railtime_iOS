//
//  Journey+Codable.swift
//  Railtime
//
//  Created by Kai Quan Tay on 13/9/26.
//

import Foundation

extension Journey: Codable {
    enum CodingKeys: CodingKey {
        case id
        case startNode
        case legs
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(try JourneyNodeCodingBox(node: startNode), forKey: .startNode)
        try container.encode(legs.map { try JourneyLegCodingBox(leg: $0) }, forKey: .legs)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.startNode = try container.decode(JourneyNodeCodingBox.self, forKey: .startNode).existential
        self.legs = try container.decode([JourneyLegCodingBox].self, forKey: .legs).map { $0.existential }
    }

    fileprivate enum JourneyNodeCodingBox: Codable {
        case busStop(JourneyBusStopNode)

        init(node: any JourneyNode) throws {
            if let node = node as? JourneyBusStopNode {
                self = .busStop(node)
            } else {
                throw JourneyCodingError.invalidType
            }
        }

        var existential: any JourneyNode {
            switch self {
            case .busStop(let journeyBusStopNode): journeyBusStopNode
            }
        }
    }
    fileprivate enum JourneyLegCodingBox: Codable {
        case bus(JourneyBusLeg)

        init(leg: any JourneyLeg) throws {
            if let leg = leg as? JourneyBusLeg {
                self = .bus(leg)
            } else {
                throw JourneyCodingError.invalidType
            }
        }

        var existential: any JourneyLeg {
            switch self {
            case .bus(let journeyBusLeg): journeyBusLeg
            }
        }
    }
}

enum JourneyCodingError: Error {
    /// An invalid type was passed in
    case invalidType
}
