//
//  BusArrivalEstimator+track.swift
//  Railtime
//
//  Created by Kai Quan Tay on 7/9/26.
//

import Foundation
import LTAAPI

extension BusArrivalEstimator {
    /// Tracks the arrival times of a bus between a few given stops of interest, based on the
    /// arrival times of that bus at other stops along its route.
    ///
    /// - Parameters:
    ///   - stopIdsOfInterest: The IDs of stops to estimate arrivals at.
    ///   - serviceNo: The bus service to estimate.
    ///   - numTarget: The desired number of upcoming buses to track at each stop of interest
    ///   - maxLookbackStops: The maximum number of stops, upstream of the most upstream stop, that `track` can poll.
    ///   - inDirection: If provided, restricts the route lookup to this
    ///     direction.
    /// - Returns: A list of `StopArrivalEstimates`, one for each stop along
    ///   the route, in upstream-to-downstream order (so the first stop in
    ///   the list is the furthest upstream, and the last stop in the list
    ///   is the most downstream stop of interest).
    public func track(
        stopIdsOfInterest: [String],
        serviceNo: String,
        numTarget: Int = 5,
        maxLookbackStops: Int = 5,
        stopGapOption: StopGapOption = .enabledOutsideInterest,
        inDirection: Int? = nil
    ) async throws -> [StopArrivalEstimates] {
        guard !stopIdsOfInterest.isEmpty else { return [] } // no stops, therefore no results
        var stopIdsSet = Set(stopIdsOfInterest) // stop IDs will be removed as they are processed

        // we choose a "random" (ie. the first) stop ID to get the stops from
        let (stops, _) = try await routeFor(serviceNo: serviceNo, busStopCode: stopIdsOfInterest.first!, inDirection: inDirection)
        // ensure that all stops of interest are present
        let missingStops = stopIdsSet.subtracting(stops.map(\.busStopCode))
        guard missingStops.isEmpty else {
            throw BusArrivalEstimatorError.stopNotFound(stopCode: missingStops.first!, serviceNo: serviceNo)
        }
        let lastTargetStopIdx: Int = stops.lastIndex(where: { stopIdsSet.contains($0.busStopCode) })!
        let lastTargetStop = stops[lastTargetStopIdx]
        let currentDayType = dayType(for: now)

        // Confirmed arrivals directly at the target stop.
        let confirmed = try await confirmedArrivals(busStopCode: lastTargetStop.busStopCode, serviceNo: serviceNo)
        stopIdsSet.remove(lastTargetStop.busStopCode)

        // estimates are from the target stop first, upstream stops later. The earliest
        // stop in a bus's route will be the last in the list for ease of appending.
        // this will be inverted at the bottom.
        var estimates: [StopArrivalEstimates] = [confirmed]

        var stopGap: TimeDelta = .zero
        if !confirmed.estimates.isEmpty {
            // we would like to use the 2nd confirmed ETA, but we will make do with the 1st if there is only one.
            let secondOrFirstIndex = min(confirmed.estimates.count - 1, 1)
            let firstETADelta = confirmed.estimates[secondOrFirstIndex].eta.timeDelta(since: now)
            stopGap = min(firstETADelta.scale(by: STOP_GAP_PERCENTAGE), MAX_STOP_GAP) // Cap the stop gap at the maximum allowed
        }

        // Walk upstream stops, closest to target first, projecting their
        // live buses forward to the target stop.
        var stopOffset = 0
        // the "real" delta, adjusted for drift
        // even though we go backwards, this will increase (+ve) because negative numbers are annoying
        // we will invert the deltas at the end of the function to make them negative again.
        var currentDelta: TimeDelta = .zero
        // the "schedule" delta, based off the schedule. We don't treat the schedule delta as reliable, but we use
        // the difference in schedule delta between stops (ie. delta_23 = delta_13 - delta_12) as a starting point for the drift calculation.
        var currentScheduleDelta: TimeDelta = .zero
        var attempted = 0

        // the number of busses we have found
        var busCount = confirmed.estimates.count
        // the number of busses we want to find. This increases as we discover more target stops.
        var movingTarget = numTarget
        // the number of attempts we are allowed. This only matters after the last target stop.
        var movingAttemptLimit = maxLookbackStops

        while stopOffset < lastTargetStopIdx {
            print("Attempt #", attempted + 1, "of", movingAttemptLimit, "— bus count:", busCount, "of", movingTarget)

            stopOffset += 1
            // if we have found all stops and met the moving target or the attempt limit, break
            if stopIdsSet.isEmpty, busCount >= movingTarget || attempted >= movingAttemptLimit {
                print("Exhausted moving target!")
                break
            }

            let upstreamIdx = lastTargetStopIdx - stopOffset
            let upstreamRow = stops[wrapping: upstreamIdx]
            let upstreamCode = upstreamRow.busStopCode

            // The terminal station is usually an interchange, which has terribly inaccurate data
            // since it is ambiguous whether the busses are incoming or outgoing.
            guard upstreamRow.busStopCode != stops.last?.busStopCode else {
                print("Reached terminal station - skipping due to unreliable data")
                break
            }
            guard let upstreamScheduleDelta = scheduleDelta(upstreamRow: upstreamRow, targetRow: lastTargetStop, dayType: currentDayType) else {
                // attempt not made
                continue
            }
            // the current estimated delta time, which is calculated using:
            // D_curr,est = D_prev + (D_prev,sched - D_curr,sched)
            let scheduleDeltaSinceLast = (upstreamScheduleDelta - currentScheduleDelta)
            let estimatedDeltaTime = currentDelta + scheduleDeltaSinceLast
            // if it is a stop of interest, we always track it. If not, make sure it is past the stop gap.
            let isOfInterest = stopIdsSet.remove(upstreamCode) != nil
            let ignoreStopGap = switch stopGapOption {
            case .disabled: true // always ignore stop gap when disabled
            case .enabledEverywhere: isOfInterest // ignore stop gap if is of interest
            case .enabledOutsideInterest: isOfInterest || !stopIdsSet.isEmpty // ignore stop gap if still in interest region
            }
            guard ignoreStopGap || scheduleDeltaSinceLast >= stopGap else {
                print(
                    "Skipping upstream stop", upstreamCode,
                    "— projected delta", upstreamScheduleDelta,
                    "min,", scheduleDeltaSinceLast.seconds / 60,
                    "min from last is less than stop gap", stopGap.seconds / 60.0, "min"
                )
                // attempt not made
                continue // too close to target stop to be useful, and not a target of interest
            }

            print(
                "Checking upstream stop", upstreamCode,
                "— projected delta", upstreamScheduleDelta,
                "min,", scheduleDeltaSinceLast.seconds / 60.0,
                "min, estimated delta", estimatedDeltaTime.seconds / 60.0, "min"
            )

            attempted += 1 // attempt made, regardless of whether we got a valid response

            // Build this stop's window: up to 3 buses, in the temporal
            // order the API already returns them, each projected forward
            // to the target stop's timeline.
            // this window is for THIS STOP!! It will be projected to future stops later.
            var rawWindow = try await confirmedArrivals(busStopCode: upstreamCode, serviceNo: serviceNo)
            rawWindow.deltaTime = estimatedDeltaTime
            rawWindow.deltaError = .zero
            rawWindow.estimates.modify { $0.busId = .unassigned }

            // align the estimates for this stop with existing estimates
            let mergeResult = BusArrivalEstimator.alignMergeAndProjectWindow(
                known: estimates, rawWindow: rawWindow, currentBusCount: busCount
            )
            estimates = mergeResult.known
            let drift = mergeResult.drift
            busCount = mergeResult.busCount
            let realDeltaTime = estimatedDeltaTime + drift
            if !estimates.isEmpty { // calculate new stop gap
                // we use the last stop. This should be the one we're processing right now
                let etas = estimates[estimates.count - 1].estimates
                if !etas.isEmpty {
                    // again, we want to use the 2nd projected ETA, but we will make do with the 1st if there is only one.
                    // the ETA is the ETA *at* this stop, which is adjusted for delta time. Therefore we only remove now
                    // to get the time until the bus arrives at this stop, which is what we want to use for the stop gap
                    // calculation.
                    let idx = min(etas.count - 1, 1)
                    let candidateGap = min(etas[idx].eta.timeDelta(since: now).scale(by: STOP_GAP_PERCENTAGE), MAX_STOP_GAP)
                    stopGap = max(stopGap, candidateGap)
                }
            }
            print("New drift: ", drift, "seconds")
            print("New stop gap: ", stopGap, "seconds")

            // calculate a new moving target
            if isOfInterest {
                movingTarget = busCount + max(0, numTarget - mergeResult.known.last!.estimates.count)
                movingAttemptLimit = attempted + maxLookbackStops
                print("New moving target: ", movingTarget)
                print("New attempt limit: ", movingAttemptLimit)
            }

            currentDelta = realDeltaTime
            currentScheduleDelta = upstreamScheduleDelta
        }

        // 3) Fallback: extrapolate using BusServices dispatch frequency if
        //    we still don't have enough.
        if busCount < movingTarget {
            estimates = try await extrapolateWithFrequency(
                estimates: estimates, serviceNo: serviceNo, numTarget: movingTarget, currentCount: busCount
            )
        }

        // invert all deltas, because these are upstream stops and their deltas should actually be negative (in the past)
        // we worked with them positive because it simplified the maths, but now we need to invert them back to negative for the final output.
        for i in estimates.indices {
            estimates[i].deltaTime = .zero - estimates[i].deltaTime
        }

        estimates.reverse() // invert the list so that the first stop is the furthest upstream, and the last stop is the target stop
        return estimates
    }

    /// How the stop gap should be enforced
    ///
    /// ```
    /// Option                   | Stops of interest | Stops between interest  | Stops outside interest
    /// -------------------------|-------------------|-------------------------|------------------------
    /// `disabled`               | Always polled     | Always polled           | Always polled
    /// `enabledEverywhere`      | Always polled     | Polled when appropriate | Polled when appropriate
    /// `enabledOutsideInterest` | Always polled     | Always polled           | Polled when appropriate
    /// ```
    public enum StopGapOption {
        /// Stop gaps are disabled in this estimation - every stop will be polled
        case disabled
        /// Stop gaps are enabled in this estimation - every stop of interest will be polled, but stops
        /// in between or outside may not be.
        case enabledEverywhere
        /// Stop gaps are enabled in this estimation, but only outside the area of interest - every
        /// stop of interest and stops in between will be polled, but stops before and after may not be
        case enabledOutsideInterest
    }
}
