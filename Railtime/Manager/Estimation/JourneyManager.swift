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
    @Published var context: JourneyContext
    var estimator: BusArrivalEstimator

    init(apiKey: String = UserDefaults.standard.string(forKey: "LTA_API_KEY") ?? "") throws {
        let journey = Journey.emptyBusJourney()
        self.journey = journey
        self.estimator = .init(client: try! LTAClient(accountKey: apiKey))
        self.context = .empty
    }

    /// Updates the context for stops found in the `journey`
    func updateStopContext() async throws {
        if let startNode = journey.startNode as? JourneyBusStopNode, startNode.busStopCode.count == 5 {
            context.nodeContext[startNode.id] = try await estimator.data.getStopInfo(busStopCode: startNode.busStopCode)
        } else {
            context.nodeContext.removeValue(forKey: journey.startNode.id)
        }

        for leg in journey.legs {
            guard let leg = leg as? JourneyBusLeg, leg.destinationBusStop.busStopCode.count == 5 else {
                context.nodeContext.removeValue(forKey: leg.destination.id)
                continue
            }
            let legNode = leg.destinationBusStop

            context.nodeContext[legNode.id] = try await estimator.data.getStopInfo(
                busStopCode: legNode.busStopCode
            )
        }
    }

    /// Obtains the full edge context for the `journey`
    func calculateJourney() async throws {
        async let stopContextTask: () = updateStopContext()

        // estimate each leg in parallel
        var stopCodes: [String] = []
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
                context.edgeContext[leg.id] = JourneyBusLeg.Context(
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
                context.edgeContext[result.id] = result.context
                stopCodes.append(contentsOf: result.context.stopEstimations.map { $0.stopId })
            }
        }

        // get details for each stop in parallel
        try await withThrowingTaskGroup(of: JourneyIntermediateBusNodeContextWithId?.self, returning: Void.self) { taskGroup in
            for stopCode in stopCodes {
                taskGroup.addTask {
                    if let stopInfo = try await self.estimator.data.getStopInfo(busStopCode: stopCode) {
                        return .init(id: stopCode, context: stopInfo)
                    } else {
                        return nil
                    }
                }
            }

            for try await result in taskGroup {
                guard let result else { continue }
                context.intermediateNodeContext[result.id] = result.context
            }
        }

        _ = try await stopContextTask
    }

    private struct JourneyBusLegContextWithId {
        var id: JourneyBusLeg.ID
        var context: JourneyBusLeg.Context
    }

    private struct JourneyIntermediateBusNodeContextWithId {
        var id: String
        var context: JourneyBusStopNode.Context
    }
}

enum JourneyManagerError: Error {
    case journeyNodeEdgeTypeMismatch
    case unsupportedNodeOrEdgeType
}
