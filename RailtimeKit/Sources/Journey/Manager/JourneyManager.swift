//
//  JourneyManager.swift
//  Railtime
//
//  Created by Kai Quan Tay on 12/9/26.
//

import Foundation
import SwiftUI
import Combine

import BusEstimation
import LTAAPI

@MainActor
public class JourneyManager: ObservableObject {
    @Published public var journey: Journey
    @Published public var context: JourneyContext
    public var estimator: BusArrivalEstimator

    public init(apiKey: String = UserDefaults.standard.string(forKey: "LTA_API_KEY") ?? "") throws {
        let journey = Journey.emptyBusJourney()
        self.journey = journey
        self.estimator = .init(client: try! LTAClient(accountKey: apiKey))
        self.context = .empty
    }

    /// Updates the context for stops found in the `journey`
    public func updateStopContext() async throws {
        if let startNode = journey.startNode(as: JourneyBusStopNode.self), startNode.busStopCode.count == 5 {
            context.nodeContext[startNode.contextId] = try await estimator.data.getStopInfo(busStopCode: startNode.busStopCode)
        } else {
            context.nodeContext.removeValue(forKey: journey.startNode.contextId)
        }

        for legId in journey.path {
            guard let destNode = journey.endNode(for: legId, as: JourneyBusStopNode.self),
                  destNode.busStopCode.count == 5 else {
                if let legUntyped = journey.legs[legId],
                   let destNodeUntyped = journey.nodes[legUntyped.destinationId] {
                    context.nodeContext.removeValue(forKey: destNodeUntyped.contextId)
                }
                continue
            }

            context.nodeContext[destNode.contextId] = try await estimator.data.getStopInfo(
                busStopCode: destNode.busStopCode
            )
        }
    }

    /// Obtains the full edge context for the `journey`
    public func calculateJourney() async throws {
        async let stopContextTask: () = updateStopContext()

        // estimate each leg in parallel
        var stopCodes: [String] = []
        try await withThrowingTaskGroup(of: JourneyBusLegContextWithId.self, returning: Void.self) { taskGroup in
            for (index, legId) in journey.path.enumerated() {
                // make sure it is a suported format
                guard let (leg, legEndNode) = journey.legAndEndNode(
                    for: legId,
                    legAs: JourneyBusLeg.self,
                    nodeAs: JourneyBusStopNode.self
                ) else {
                    throw JourneyManagerError.unsupportedNodeOrEdgeType
                }

                // get the start node
                guard let legStartNode = (index == 0 ? journey.startNode(as: JourneyBusStopNode.self) : journey.endNode(
                    for: journey.path[index-1],
                    as: JourneyBusStopNode.self
                )) else {
                    throw JourneyManagerError.journeyNodeEdgeTypeMismatch
                }

                // add a temporary empty context
                context.edgeContext[leg.contextId] = JourneyBusLeg.Context(
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
                        contextId: leg.contextId,
                        context: JourneyBusLeg.Context(
                            startCode: legStartNode.busStopCode,
                            endCode: legEndNode.busStopCode,
                            stopEstimations: Array(estimates)
                        )
                    )
                }
            }

            for try await result in taskGroup {
                context.edgeContext[result.contextId] = result.context
                stopCodes.append(contentsOf: result.context.stopEstimations.map { $0.stopId })
            }
        }

        // get details for each stop in parallel
        try await withThrowingTaskGroup(of: JourneyIntermediateBusNodeContextWithId?.self, returning: Void.self) { taskGroup in
            for stopCode in stopCodes {
                taskGroup.addTask {
                    if let stopInfo = try await self.estimator.data.getStopInfo(busStopCode: stopCode) {
                        return .init(contextId: stopCode, context: stopInfo)
                    } else {
                        return nil
                    }
                }
            }

            for try await result in taskGroup {
                guard let result else { continue }
                context.nodeContext[result.contextId] = result.context
            }
        }

        _ = try await stopContextTask
    }

    private struct JourneyBusLegContextWithId {
        var contextId: JourneyLegContextID
        var context: JourneyBusLeg.Context
    }

    private struct JourneyIntermediateBusNodeContextWithId {
        var contextId: JourneyNodeContextID
        var context: JourneyBusStopNode.Context
    }
}

public enum JourneyManagerError: Error {
    case journeyNodeEdgeTypeMismatch
    case unsupportedNodeOrEdgeType
}
