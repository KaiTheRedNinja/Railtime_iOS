//
//  JourneyManager.swift
//  Railtime
//
//  Created by Kai Quan Tay on 12/9/26.
//

import Foundation
import Observation

@Observable
class JourneyManager {
    var journey: Journey
    var estimator: BusArrivalEstimator

    var nodeContext: [UUID: any JourneyNodeContext]
    var edgeContext: [UUID: any JourneyLegContext]

    init(apiKey: String = UserDefaults.standard.string(forKey: "LTA_API_KEY") ?? "") throws {
        let journey = Journey.emptyBusJourney()
        self.journey = journey
        self.estimator = .init(client: try! LTAClient(accountKey: apiKey))
        self.nodeContext = [:]
        self.edgeContext = [:]
    }

    /// Updates the context for stops found in the `journey`
    func updateStopContext() async throws {
        if let startNode = journey.startNode as? JourneyBusStopNode {
            nodeContext[startNode.id] = try await estimator.data.getStopInfo(busStopCode: startNode.busStopCode)
        }

        for leg in journey.legs {
            guard let leg = leg as? JourneyBusLeg else { continue }
            let legNode = leg.destinationBusStop

            nodeContext[legNode.id] = try await estimator.data.getStopInfo(
                busStopCode: legNode.busStopCode
            )
        }
    }

    /// Obtains the full edge context for the `journey`
    func calculateJourney() async throws {
        Task { try await updateStopContext() }

        // estimate each leg in parallel
        try await withThrowingTaskGroup(of: JourneyBusLegContextWithId.self, returning: Void.self) { taskGroup in
            for (index, leg) in journey.legs.enumerated() {
                guard let leg = leg as? JourneyBusLeg else {
                    throw JourneyManagerError.unsupportedNodeOrEdgeType
                }

                let legStartNode = index == 0 ? journey.startNode : journey.legs[index-1].destination
                let legEndNode = leg.destinationBusStop
                guard let legStartNode = legStartNode as? JourneyBusStopNode else {
                    throw JourneyManagerError.journeyNodeEdgeTypeMismatch
                }

                taskGroup.addTask {
                    let rawEstimates = try await self.estimator.track(
                        stopIdsOfInterest: [legStartNode.busStopCode, legEndNode.busStopCode],
                        serviceNo: leg.serviceNo
                    )
                    guard let startIndex = rawEstimates.firstIndex(where: { $0.stopId == legStartNode.busStopCode }),
                          let endIndex = rawEstimates.lastIndex(where: { $0.stopId == legEndNode.busStopCode }),
                          startIndex < endIndex else {
                        throw BusArrivalEstimatorError.stopNotFound(stopCode: legStartNode.busStopCode, serviceNo: leg.serviceNo)
                    }
                    let estimates = rawEstimates[startIndex...endIndex]
                    return .init(
                        id: leg.id,
                        context: JourneyBusLeg.Context(
                            startCode: legStartNode.busStopCode,
                            endCode: legEndNode.busStopCode,
                            stopEstimations: Array(estimates)
                        )
                    )
                }
            }

            for try await result in taskGroup {
                edgeContext[result.id] = result.context
            }
        }
    }

    private struct JourneyBusLegContextWithId {
        var id: JourneyBusLeg.ID
        var context: JourneyBusLeg.Context
    }
}

enum JourneyManagerError: Error {
    case journeyNodeEdgeTypeMismatch
    case unsupportedNodeOrEdgeType
}
