//
//  Journey+Codable.swift
//  Railtime
//
//  Created by Kai Quan Tay on 13/9/26.
//

import Foundation
import BusEstimation
import LTAAPI

extension Journey: Codable {
    public enum CodingKeys: CodingKey {
        case id
        case startNodeId
        case nodes
        case legs
        case path
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(startNodeId, forKey: .startNodeId)
        try container.encode(nodes.mapValues { try JourneyNodeCodingBox(node: $0) }, forKey: .nodes)
        try container.encode(legs.mapValues { try JourneyLegCodingBox(leg: $0) }, forKey: .legs)
        try container.encode(path, forKey: .path)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Journey.ID.self, forKey: .id)
        self.startNodeId = try container.decode(JourneyNodeID.self, forKey: .startNodeId)
        self.nodes = try container.decode([JourneyNodeID: JourneyNodeCodingBox].self, forKey: .nodes).mapValues { $0.existential }
        self.legs = try container.decode([JourneyLegID: JourneyLegCodingBox].self, forKey: .legs).mapValues { $0.existential }
        self.path = try container.decode([JourneyLegID].self, forKey: .path)
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
    public enum CodingKeys: CodingKey {
        case nodeContext
        case edgeContext
    }

    public func encode(to encoder: any Encoder) throws {
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

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.nodeContext = try container.decodeIfPresent(
            [JourneyNodeContextID: JourneyNodeContextCodingBox].self,
            forKey: .nodeContext
        )?.mapValues { $0.existential } ?? [:]
        self.edgeContext = try container.decodeIfPresent(
            [JourneyLegContextID: JourneyLegContextCodingBox].self,
            forKey: .edgeContext
        )?.mapValues { $0.existential } ?? [:]
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

public enum JourneyCodingError: Error {
    /// An invalid type was passed in
    case invalidType
}
