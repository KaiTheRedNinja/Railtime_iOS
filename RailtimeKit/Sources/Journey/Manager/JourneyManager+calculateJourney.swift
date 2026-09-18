//
//  JourneyManager+calculateJourney.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 17/9/26.
//

import BusEstimation
import CoreLocation

extension JourneyManager {
    /// Obtains the full edge context for the `journey`
    public func calculateJourney() async throws {
        var busRangesToQuery: [String: [StopRangeRequest]] = [:]
        var mrtRangesToQuery: [String: [StopRangeRequest]] = [:]
        var walkRequests: [WalkRequest] = []

        var nodesToExplore = [journey.startNode]

        // explore the graph, depth-first search
        while let legStartNode = nodesToExplore.popLast() {
            // get each leg's end node
            for nextLegId in legStartNode.nextLegIds {
                guard let leg = journey.legs[nextLegId],
                      let legEndNode = journey.nodes[leg.destinationId]
                        else { throw JourneyManagerError.brokenGraph }

                if let legStartNode = legStartNode as? JourneyBusStopNode,
                   let leg = leg as? JourneyBusLeg,
                   let legEndNode = legEndNode as? JourneyBusStopNode {
                    busRangesToQuery[leg.serviceNo, default: []].append(
                        .init(
                            startCode: legStartNode.busStopCode,
                            endCode: legEndNode.busStopCode,
                            contextId: leg.contextId
                        )
                    )
                }
                if let legStartNode = legStartNode as? JourneyTrainStopNode,
                   let leg = leg as? JourneyTrainLeg,
                   let legEndNode = legEndNode as? JourneyTrainStopNode {
                    mrtRangesToQuery[leg.serviceNo, default: []].append(
                        .init(
                            startCode: legStartNode.trainStopCode,
                            endCode: legEndNode.trainStopCode,
                            contextId: leg.contextId
                        )
                    )
                }
                if let leg = leg as? JourneyWalkLeg {
                    walkRequests.append(
                        .init(
                            startContextId: legStartNode.contextId,
                            endContextId: legEndNode.contextId,
                            contextId: leg.contextId
                        )
                    )
                }

                // add end node to nodes to explore
                nodesToExplore.append(legEndNode)
            }
        }

        // get the timings
        let finalBusRangesToQuery = busRangesToQuery
        let finalMrtRangesToQuery = mrtRangesToQuery
        async let busContextTask: () = getBusContext(finalBusRangesToQuery)
        async let mrtContextTask: () = getTrainContext(finalMrtRangesToQuery)
        _ = try await (busContextTask, mrtContextTask)

        // determine any walking distances. This requires all node locations, therefore it goes last.
        getWalkContext(walkRequests: walkRequests)
    }

    private func getBusContext(_ busRangesToQuery: [String : [JourneyManager.StopRangeRequest]]) async throws {
        guard let estimator else { return }

        struct JourneyBusLegContextWithId {
            var contextId: JourneyLegContextID
            var context: JourneyBusLeg.Context
        }

        struct JourneyIntermediateBusNodeContextWithId {
            var contextId: JourneyNodeContextID
            var context: JourneyBusStopNode.Context
        }

        // estimate each leg in parallel
        var stopCodes: [String] = []
        try await withThrowingTaskGroup(of: [JourneyBusLegContextWithId].self, returning: Void.self) { taskGroup in
            for (serviceNo, stopRanges) in busRangesToQuery {
                // add a temporary empty context for each range
                for stopRange in stopRanges {
                    context.edgeContext[stopRange.contextId] = JourneyBusLeg.Context(
                        startCode: stopRange.startCode,
                        endCode: stopRange.endCode,
                        stopEstimations: []
                    )
                }

                taskGroup.addTask {
                    let rawEstimatesForRanges = try await estimator.track(
                        stopRangesOfInterest: stopRanges.map { ($0.startCode, $0.endCode) },
                        serviceNo: serviceNo
                    )

                    var estimatesForRanges: [JourneyBusLegContextWithId] = []
                    for (stopRange, rawEstimatesForRange) in zip(stopRanges, rawEstimatesForRanges) {
                        estimatesForRanges.append(
                            .init(
                                contextId: stopRange.contextId,
                                context: .init(
                                    startCode: stopRange.startCode,
                                    endCode: stopRange.endCode,
                                    stopEstimations: rawEstimatesForRange
                                )
                            )
                        )
                    }

                    return estimatesForRanges
                }
            }

            for try await resultGroup in taskGroup {
                for result in resultGroup {
                    context.edgeContext[result.contextId] = result.context
                    stopCodes.append(contentsOf: result.context.stopEstimations.map { $0.stopId })
                }
            }
        }

        // get details for each stop in parallel
        try await withThrowingTaskGroup(of: JourneyIntermediateBusNodeContextWithId?.self, returning: Void.self) { taskGroup in
            for stopCode in stopCodes {
                taskGroup.addTask {
                    if let stopInfo = try await estimator.data.getStopInfo(busStopCode: stopCode) {
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
    }

    private func getTrainContext(_ mrtRangesToQuery: [String : [JourneyManager.StopRangeRequest]]) async throws {
        guard let estimator else { return }

        struct JourneyTrainLegContextWithId {
            var contextId: JourneyLegContextID
            var context: JourneyTrainLeg.Context
        }

        struct JourneyIntermediateTrainNodeContextWithId {
            var contextId: JourneyNodeContextID
            var context: JourneyTrainStopNode.Context
        }

        // estimate each leg in parallel
        var stopCodes: [String] = []
        try await withThrowingTaskGroup(of: [JourneyTrainLegContextWithId].self, returning: Void.self) { taskGroup in
            for (serviceNo, stopRanges) in mrtRangesToQuery {
                // add a temporary empty context for each range
                for stopRange in stopRanges {
                    context.edgeContext[stopRange.contextId] = JourneyTrainLeg.Context(
                        startCode: stopRange.startCode,
                        endCode: stopRange.endCode,
                        stopEstimations: []
                    )
                }

                taskGroup.addTask {
                    // TODO: actually project the estimations
                    let rawEstimatesForRanges: [[TrainStopArrivalEstimates]] = .init(repeating: [], count: stopRanges.count)
                    for stopRange in stopRanges {
                    }
//                    try await self.estimator.track(
//                        stopRangesOfInterest: stopRanges.map { ($0.startCode, $0.endCode) },
//                        serviceNo: serviceNo
//                    )

                    var estimatesForRanges: [JourneyTrainLegContextWithId] = []
                    for (stopRange, rawEstimatesForRange) in zip(stopRanges, rawEstimatesForRanges) {
                        estimatesForRanges.append(
                            .init(
                                contextId: stopRange.contextId,
                                context: .init(
                                    startCode: stopRange.startCode,
                                    endCode: stopRange.endCode,
                                    stopEstimations: rawEstimatesForRange
                                )
                            )
                        )
                    }

                    return estimatesForRanges
                }
            }

            for try await resultGroup in taskGroup {
                for result in resultGroup {
                    context.edgeContext[result.contextId] = result.context
                    stopCodes.append(contentsOf: result.context.stopEstimations.map { $0.stopId })
                }
            }
        }

        // get details for each stop in parallel
        try await withThrowingTaskGroup(of: JourneyIntermediateTrainNodeContextWithId?.self, returning: Void.self) { taskGroup in
            for stopCode in stopCodes {
                taskGroup.addTask {
                    // TODO: actually get information about the stop
                    return nil
//                    if let stopInfo = try await self.estimator.data.getStopInfo(busStopCode: stopCode) {
//                        return .init(contextId: stopCode, context: stopInfo)
//                    } else {
//                        return nil
//                    }
                }
            }

            for try await result in taskGroup {
                guard let result else { continue }
                context.nodeContext[result.contextId] = result.context
            }
        }
    }

    private func getWalkContext(walkRequests: [WalkRequest]) {
        for request in walkRequests {
            guard let startNodeContext = context.nodeContext[request.startContextId],
                  let endNodeContext = context.nodeContext[request.endContextId]
            else { continue }

            let startCoordinate = CLLocation(latitude: startNodeContext.latitude, longitude: startNodeContext.longitude)
            let endCoordinate = CLLocation(latitude: endNodeContext.latitude, longitude: endNodeContext.longitude)

            let distMeters = startCoordinate.distance(from: endCoordinate)
            let timeSeconds = distMeters / 1.0 // 1 m/s is a slightly slow walking speed, which accounts for roads/twists
            context.edgeContext[request.contextId] = JourneyWalkLeg.Context(
                estimatedDistance: distMeters / 1000,
                walkTime: .secs(timeSeconds)
            )
        }
    }

    private struct StopRangeRequest {
        var startCode: String
        var endCode: String
        var contextId: JourneyLegContextID
    }

    private struct WalkRequest {
        var startContextId: JourneyNodeContextID
        var endContextId: JourneyNodeContextID
        var contextId: JourneyLegContextID
    }
}
