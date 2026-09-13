//
//  JourneyManager.swift
//  Railtime
//
//  Created by Kai Quan Tay on 12/9/26.
//

import Foundation
import SwiftUI
import Combine

class JourneyManager: ObservableObject {
    @Published var journey: Journey
    var estimator: BusArrivalEstimator

    @Published var nodeContext: [UUID: any JourneyNodeContext]
    @Published var edgeContext: [UUID: any JourneyLegContext]

    init(apiKey: String = UserDefaults.standard.string(forKey: "LTA_API_KEY") ?? "") throws {
        let journey = Journey.emptyBusJourney()
        self.journey = journey
        self.estimator = .init(client: try! LTAClient(accountKey: apiKey))
        self.nodeContext = [:]
        self.edgeContext = [:]
    }

    /// Updates the context for stops found in the `journey`
    func updateStopContext() async throws {
        if let startNode = journey.startNode as? JourneyBusStopNode, startNode.busStopCode.count == 5 {
            nodeContext[startNode.id] = try await estimator.data.getStopInfo(busStopCode: startNode.busStopCode)
        } else {
            nodeContext.removeValue(forKey: journey.startNode.id)
        }

        for leg in journey.legs {
            guard let leg = leg as? JourneyBusLeg, leg.destinationBusStop.busStopCode.count == 5 else {
                nodeContext.removeValue(forKey: leg.destination.id)
                continue
            }
            let legNode = leg.destinationBusStop

            nodeContext[legNode.id] = try await estimator.data.getStopInfo(
                busStopCode: legNode.busStopCode
            )
        }
    }

    /// Obtains the full edge context for the `journey`
    func calculateJourney() async throws {
        async let stopContextTask: () = updateStopContext()

        // estimate each leg in parallel
        try await withThrowingTaskGroup(of: JourneyBusLegContextWithId.self, returning: Void.self) { taskGroup in
            for (index, leg) in journey.legs.enumerated() {
                // make sure it is a suported format
                guard let leg = leg as? JourneyBusLeg else {
                    throw JourneyManagerError.unsupportedNodeOrEdgeType
                }

                // get the start node
                let legStartNode = index == 0 ? journey.startNode : journey.legs[index-1].destination
                let legEndNode = leg.destinationBusStop
                guard let legStartNode = legStartNode as? JourneyBusStopNode else {
                    throw JourneyManagerError.journeyNodeEdgeTypeMismatch
                }

                // add a temporary empty context
                edgeContext[leg.id] = JourneyBusLeg.Context(
                    startCode: legStartNode.busStopCode,
                    endCode: legEndNode.busStopCode,
                    stopEstimations: []
                )

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

        _ = try await stopContextTask
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
