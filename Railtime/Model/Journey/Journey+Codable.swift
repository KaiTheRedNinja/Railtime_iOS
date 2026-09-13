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

extension JourneyContext: Codable {
    enum CodingKeys: CodingKey {
        case nodeContext
        case edgeContext
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(
            nodeContext.mapValues { try JourneyNodeContextCodingBox(node: $0)},
            forKey: .nodeContext
        )
        try container.encode(
            edgeContext.mapValues { try JourneyLegContextCodingBox(leg: $0)},
            forKey: .edgeContext
        )
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.nodeContext = try container.decode(
            [UUID: JourneyNodeContextCodingBox].self,
            forKey: .nodeContext
        ).mapValues { $0.existential }
        self.edgeContext = try container.decode(
            [UUID: JourneyLegContextCodingBox].self,
            forKey: .edgeContext
        ).mapValues { $0.existential }
    }

    fileprivate enum JourneyNodeContextCodingBox: Codable {
        case busStop(JourneyBusStopNode.Context)

        init(node: any JourneyNodeContext) throws {
            if let node = node as? JourneyBusStopNode.Context {
                self = .busStop(node)
            } else {
                throw JourneyCodingError.invalidType
            }
        }

        var existential: any JourneyNodeContext {
            switch self {
            case .busStop(let journeyBusStopNode): journeyBusStopNode
            }
        }
    }
    fileprivate enum JourneyLegContextCodingBox: Codable {
        case bus(JourneyBusLeg.Context)

        init(leg: any JourneyLegContext) throws {
            if let leg = leg as? JourneyBusLeg.Context {
                self = .bus(leg)
            } else {
                throw JourneyCodingError.invalidType
            }
        }

        var existential: any JourneyLegContext {
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
