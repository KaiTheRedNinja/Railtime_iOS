//
//  Journey+Train.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 15/9/26.
//

import Foundation
import BusEstimation
import LTAAPI

/// A node representing a bus stop
public struct JourneyTrainStopNode: JourneyNode {
    // TODO: replace with the type we implement for MRT Context
    public struct Context: JourneyNodeContext {
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

        public struct Exit: Equatable, Codable {
            /// The code for the stop, eg "Exit A"
            var code: String
            /// The description for what this exit corresponds to
            var description: String
        }
    }

    public var id: JourneyNodeID = .init()
    public var trainStopCode: String
    public var nextLegIds: [JourneyLegID]
    public var contextId: JourneyNodeContextID { trainStopCode }

    public init(id: JourneyNodeID = .init(), trainStopCode: String, nextLegIds: [JourneyLegID]) {
        self.id = id
        self.trainStopCode = trainStopCode
        self.nextLegIds = nextLegIds
    }
}

/// A node representing an MRT journey
public struct JourneyTrainLeg: JourneyLeg {
    /// The estimations for a segment of a bus route
    public struct Context: JourneyLegContext {
        /// The code for the stop that this segment starts with - i.e. the stop that the user would enter the MRT
        public var startCode: String
        /// The code for the stop that this segment ends with - i.e. the stop that the user would exit the MRT
        public var endCode: String

        /// The estimates, starting from the start code and ending at the end code.
        ///
        /// Note that these are all projections, because LTA does not give us actual train timings.
        public var stopEstimations: [TrainStopArrivalEstimates]
    }

    public var id: JourneyLegID = .init()
    public var serviceNo: String
    public var destinationId: JourneyNodeID
    public var contextId: JourneyLegContextID { id.uuidString }

    public init(id: JourneyLegID = .init(), serviceNo: String, destinationId: JourneyNodeID) {
        self.id = id
        self.serviceNo = serviceNo
        self.destinationId = destinationId
    }

    public static func canStartWith<N>(node: N) -> Bool where N: JourneyNode { N.self is JourneyTrainStopNode.Type }
    public static func canEndWith<N>(node: N) -> Bool where N: JourneyNode { N.self is JourneyTrainStopNode.Type }

    public func canBeMerged(
        withNextLeg next: JourneyTrainLeg,
        selfContext: Context,
        nextContext: Context
    ) -> Bool {
        self.serviceNo == next.serviceNo // must have the same service
    }
}
