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
    public var estimator: BusArrivalEstimator?

    public init(apiKey: String? = nil) {
        let journey = Journey.emptyBusJourney()
        self.journey = journey
        self.context = .empty
        
        let key = apiKey ??
            UserDefaults.standard.string(forKey: "LTA_ACCOUNT_KEY") ??
            UserDefaults.standard.string(forKey: "LTA_API_KEY")
        if let client = try? LTAClient(accountKey: key) {
            self.estimator = BusArrivalEstimator(client: client)
        } else {
            self.estimator = nil
        }
    }
    
    public func updateAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "LTA_ACCOUNT_KEY")
        UserDefaults.standard.set(key, forKey: "LTA_API_KEY")
        if let client = try? LTAClient(accountKey: key) {
            self.estimator = BusArrivalEstimator(client: client)
        }
    }

    /// Updates the context for stops found in the `journey`
    public func updateStopContext() async throws {
        guard let estimator = estimator else { return }
        
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

    /// Changes a given path segment to another one. If the path item has other subsequent paths, it chooses the first one.
    public func changePath(atIndex index: Int, toPathItem pathItem: JourneyLegID) {
        // determine the path from pathItem
        var newPath: [JourneyLegID] = [pathItem]

        // get the very first leg
        guard let currentPathItem = journey.legs[pathItem],
              var currentEndNode = journey.nodes[currentPathItem.destinationId]
        else { return } // the path is not valid

        // travel down the legs to re-build the path
        while let nextLegId = currentEndNode.nextLegIds.first {
            guard let nextPathItem = journey.legs[nextLegId],
                  let nextEndNode = journey.nodes[nextPathItem.destinationId]
            else { break } // the path is not valid

            newPath.append(nextLegId)
            currentEndNode = nextEndNode
        }

        journey.path = journey.path[0..<index] + newPath
    }
}

public enum JourneyManagerError: Error {
    case journeyNodeEdgeTypeMismatch
    case unsupportedNodeOrEdgeType
    case brokenGraph
}
