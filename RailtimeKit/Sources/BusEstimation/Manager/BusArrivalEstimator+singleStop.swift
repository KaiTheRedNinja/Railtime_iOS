//
//  BusArrivalEstimator+singleStop.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 9/10/26.
//

import Foundation
import LTAAPI

extension BusArrivalEstimator {
    /// Returns the arrivals for a single stop
    ///
    /// - Parameters:
    ///   - code: The ranges of stops to return estimates for
    ///   - serviceNo: The bus service to estimate, or `nil` for all of them.
    /// - Returns: A list of `BusStopArrivalEstimates`, one per service.
    public func getSingleStop(
        code busStopCode: String,
        serviceNo: String?,
        inDirection: Int? = nil
    ) async throws -> [BusStopArrivalEstimates] {
        let arrival = try await data.getBusArrival(busStopCode: busStopCode, serviceNo: serviceNo)
        var serviceEstimates: [BusStopArrivalEstimates] = []
        for service in arrival.services {
            var busEstimates: [BusArrivalEstimate] = []
            for nextBus in service.nextBuses {
                guard let nextBus, let eta = parseISO(nextBus.estimatedArrival) else {
                    continue
                }
                busEstimates.append(BusArrivalEstimate(
                    busId: .ordered(index: busEstimates.count),
                    busServiceNo: service.serviceNo,
                    eta: eta,
                    source: .live,
                    projectedFromStop: nil,
                    load: nextBus.load,
                    feature: nextBus.feature,
                    busType: nextBus.type
                ))
            }
            serviceEstimates.append(.init(stopId: busStopCode, deltaTime: .zero, deltaError: .zero, estimates: busEstimates))
        }
        return serviceEstimates
    }
}
