//
//  BusArrivalEstimator+extrapolate.swift
//  Railtime
//
//  Created by Kai Quan Tay on 7/9/26.
//

import Foundation

extension BusArrivalEstimator {
    /// Fills in any still-missing target-stop arrivals by extrapolating
    /// from the service's scheduled dispatch frequency, then back-projects
    /// those extrapolated buses onto every upstream stop already known.
    ///
    /// - Parameters:
    ///   - estimates: The stops resolved so far, target-first.
    ///   - serviceNo: The service being estimated.
    ///   - numTarget: The desired total number of buses at the target stop.
    ///   - currentCount: How many buses have already been found.
    /// - Returns: `estimates`, with extrapolated buses appended where
    ///   needed.
    internal func extrapolateWithFrequency(
        estimates: [StopArrivalEstimates], serviceNo: String, numTarget: Int, currentCount: Int
    ) async throws -> [StopArrivalEstimates] {
        guard let freq = try await serviceFreq(serviceNo: serviceNo) else {
            return estimates // nothing to extrapolate with
        }
        var estimates = estimates
        let anchor = estimates.last?.estimates
            .map { $0.eta }
            .max() ?? now
        //        let calendar = Calendar.current

        func bandMidpoint(_ band: String?) -> Double? {
            let trimmed = (band ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.contains("-") else {
                return nil
            }
            let parts = trimmed.split(separator: "-", maxSplits: 1)
            guard parts.count == 2, let lo = Double(parts[0]), let hi = Double(parts[1]) else {
                return nil
            }
            return (lo + hi) / 2
        }

        var gap: Double?
        let anchorTOD = TimeOfDay(date: anchor)
        if anchorTOD.isBetween(earliest: .init(hh: 6, mm: 30), latest: .init(hh: 8, mm: 30)) {
            gap = bandMidpoint(freq.amPeakFreq)
        } else if anchorTOD.isBetween(earliest: .init(hh: 17, mm: 00), latest: .init(hh: 19, mm: 00)) {
            gap = bandMidpoint(freq.pmPeakFreq)
        } else if anchorTOD.isBetween(earliest: .init(hh: 19, mm: 00)) {
            gap = bandMidpoint(freq.pmOffpeakFreq)
        } else {
            gap = bandMidpoint(freq.amOffpeakFreq)
        }
        let resolvedGap = gap ?? 12.0 // last-resort default spacing in minutes

        // create the extra busses for the target stop, then we will back-project them to the upstream stops
        var extrapolated: [BusArrivalEstimate] = []
        if currentCount + 1 <= numTarget { // note: i is the ID of the bus
            for i in (currentCount + 1)...numTarget {
                let eta = anchor.incrementingBy(timeDelta: .mins(resolvedGap * Double(i - currentCount)))
                extrapolated.append(BusArrivalEstimate(
                    busId: "bus_\(i)",
                    busServiceNo: serviceNo,
                    eta: eta,
                    source: .extrapolated,
                    projectedFromStop: nil
                ))
            }
        }
        guard let lastIndex = estimates.indices.last else {
            return estimates
        }
        estimates[lastIndex].estimates.append(contentsOf: extrapolated)

        // project the extrapolated busses to the upstream stops
        for estimate in extrapolated {
            for i in estimates.indices where i != lastIndex {
                let projectedETA = estimate.eta.incrementingBy(timeDelta: estimates[lastIndex].deltaTime - estimates[i].deltaTime)
                estimates[i].estimates.append(BusArrivalEstimate(
                    busId: estimate.busId,
                    busServiceNo: estimate.busServiceNo,
                    eta: projectedETA,
                    source: .extrapolated,
                    projectedFromStop: nil
                ))
            }
        }
        return estimates
    }
}
