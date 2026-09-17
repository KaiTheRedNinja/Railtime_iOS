//
//  JourneyManager+calculateJourney.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 17/9/26.
//

extension JourneyManager {
    /// Obtains the full edge context for the `journey`
    public func calculateJourney() async throws {
        async let stopContextTask: () = updateStopContext()

        // estimate each leg in parallel
        var stopCodes: [String] = []

        var rangesToQuery: [String: [StopRangeRequest]] = [:]

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
                    rangesToQuery[leg.serviceNo, default: []].append(
                        .init(startCode: legStartNode.busStopCode, endCode: legEndNode.busStopCode, contextId: leg.contextId)
                    )
                }

                // add end node to nodes to explore
                nodesToExplore.append(legEndNode)
            }
        }

        try await withThrowingTaskGroup(of: [JourneyBusLegContextWithId].self, returning: Void.self) { taskGroup in
            for (serviceNo, stopRanges) in rangesToQuery {
                // add a temporary empty context for each range
                for stopRange in stopRanges {
                    context.edgeContext[stopRange.contextId] = JourneyBusLeg.Context(
                        startCode: stopRange.startCode,
                        endCode: stopRange.endCode,
                        stopEstimations: []
                    )
                }

                taskGroup.addTask {
                    let rawEstimatesForRanges = try await self.estimator.track(
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

    private struct StopRangeRequest {
        var startCode: String
        var endCode: String
        var contextId: JourneyLegContextID
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
