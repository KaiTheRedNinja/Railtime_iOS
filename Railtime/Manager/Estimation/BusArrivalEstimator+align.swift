//
//  BusArrivalEstimator+align.swift
//  Railtime
//
//  Created by Kai Quan Tay on 7/9/26.
//

import Foundation

extension BusArrivalEstimator {
    /// Aligns a newly-fetched upstream stop's live window against the
    /// sequence of stops already known, merges in any newly-discovered
    /// buses, and projects those new buses onto every already-known stop.
    ///
    /// - Parameters:
    ///   - known: The stops resolved so far, target-first.
    ///   - rawWindow: The newly-fetched live window for the upstream stop
    ///     being merged in.
    ///   - currentBusCount: The caller's current running count of distinct
    ///     buses found. Threaded through unchanged whenever this function
    ///     takes one of its "add verbatim, nothing new to merge" early
    ///     exits.
    ///
    ///     (In the Python source, those early exits `return (known,
    ///     raw_window.delta_time)` — a two-element tuple, even though the
    ///     function is annotated to return three elements and its caller
    ///     always unpacks three. Reaching that code path there would raise
    ///     `ValueError: not enough values to unpack`. This translation
    ///     avoids that crash by taking the previous count as a parameter
    ///     and returning it unchanged, which matches the evident intent of
    ///     "this stop told us nothing new".)
    /// - Returns: The updated `known` list, the drift applied to align
    ///   `rawWindow`, and the new total number of distinct buses found.
    static internal func alignMergeAndProjectWindow(
        known: [StopArrivalEstimates],
        rawWindow: StopArrivalEstimates,
        currentBusCount: Int
    ) -> (known: [StopArrivalEstimates], drift: TimeDelta, busCount: Int) {
        var known = known

        guard !rawWindow.estimates.isEmpty else {
            // if no estimates are available, just add it verbatim.
            print("No estimates available for stop", rawWindow.stopId, "— adding verbatim")
            known.append(rawWindow)
            return (known, rawWindow.deltaTime, currentBusCount)
        }

        // get the arrivals from the stop closest to this
        // that actually has estimates. This is the "tail" of the known sequence.
        guard let tail = known.reversed().first(where: { !$0.estimates.isEmpty }) else {
            print("No tail stop found for stop", rawWindow.stopId, "— adding verbatim")
            known.append(rawWindow)
            return (known, rawWindow.deltaTime, currentBusCount)
        }
        print("Tail stop:", tail.stopId)

        // determine the best alignment
        let (resolvedBestOffset, resolvedBestError, bestDrift) = getBestAlignment(tail: tail, rawWindow: rawWindow)

        print("Best offset: ", resolvedBestOffset)
        print("Best drift: ", bestDrift, "seconds")

        let overlapLen = min(rawWindow.estimates.count, tail.estimates.count - resolvedBestOffset)

        let lastKnownBusIdNum: Int = tail.estimates.compactMap { $0.busId.index }.max() ?? known.count * 3
        let firstBusNumForThisStop = lastKnownBusIdNum - tail.estimates.count + resolvedBestOffset + 1
        var rawWindowEstimates = rawWindow.estimates
        for i in rawWindowEstimates.indices {
            rawWindowEstimates[i].busId = .ordered(index: firstBusNumForThisStop + i)
        }
        let thisStop = StopArrivalEstimates(
            stopId: rawWindow.stopId,
            deltaTime: rawWindow.deltaTime + bestDrift,
            deltaError: rawWindow.deltaError + resolvedBestError,
            estimates: rawWindowEstimates
        )

        // project any new busses to downstream bus stops
        for estimate in thisStop.estimates[overlapLen...] {
            // go down the downstream stops
            for i in known.indices {
                let projectedETA = estimate.eta.incrementingBy(timeDelta: thisStop.deltaTime - known[i].deltaTime)
                known[i].estimates.append(BusArrivalEstimate(
                    busId: estimate.busId,
                    busServiceNo: estimate.busServiceNo,
                    eta: projectedETA,
                    source: .projected,
                    projectedFromStop: thisStop.stopId,
                    load: estimate.load,
                    feature: estimate.feature,
                    busType: estimate.busType
                ))
            }
        }

        known.append(thisStop)
        return (known, bestDrift, firstBusNumForThisStop + rawWindow.estimates.count)
    }

    private static func getBestAlignment(
        tail: StopArrivalEstimates,
        rawWindow: StopArrivalEstimates,
    ) -> (
        bestOffset: Int,
        bestError: TimeDelta,
        bestDrift: TimeDelta
    ) {
        let projectedETAs = rawWindow.estimates.map {
            $0.eta.incrementingBy(timeDelta: rawWindow.deltaTime - tail.deltaTime)
        }

        // compare the ETAs for both AT THEIR RESPECTIVE TIMES, then with the projected delta time of the raw window
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        print()
        print(tail.deltaTime.seconds / 60, "min Tail ETAs:", tail.estimates.map { formatter.string(from: $0.eta) }.joined(separator: " | "))
        print(rawWindow.deltaTime.seconds / 60, "min Raw ETAs:", rawWindow.estimates.map { formatter.string(from: $0.eta) }.joined(separator: " | "))
        print("PROJECTED ETAs:", projectedETAs.map { formatter.string(from: $0) }.joined(separator: " | "))
        print()

        // get best alignment
        var bestOffset: Int?
        var bestError: TimeDelta?
        var bestDrift: TimeDelta = .zero
        // Mirrors the Python source's use of the for-loop's `drift`
        // variable after the loop ends (Python for-loops don't introduce a
        // new scope, so the last value assigned to `drift` survives past
        // the loop) — used by the "no plausible alignment" fallback below.
        var lastLoopDrift: TimeDelta = .zero

        for offset in 0...tail.estimates.count {
            // get the number of overlapping elements
            let overlapLen = min(rawWindow.estimates.count, tail.estimates.count - offset)
            let drift: TimeDelta
            let error: TimeDelta
            if overlapLen > 0 {
                let diffs = (0..<overlapLen).map { i in
                    // positive value = upstream bus is early, negative value = upstream bus is late
                    tail.estimates[offset + i].eta.timeDelta(since: projectedETAs[i])
                }

                // a positive drift means the bus is early, adding the drift would make it on time.
                drift = diffs.reduce(.zero, +).scale(by: 1 / Double(overlapLen))
                error = max(.zero, diffs.map { $0.magnitude() }.reduce(.zero, +).scale(by: 1 / Double(overlapLen)))
                lastLoopDrift = drift

                if error > MAX_ALIGNMENT_ERROR {
                    // if the offset is 0 and the drift is positive (ie. upstream busses are early), then
                    // we do not discard this offset, because upstream busses can be as early as we want.
                    if offset == 0 && drift > .zero {
                        print("[overlap] Error for offset", offset, ":", error, "seconds — exceeds max alignment error, but drift is positive, keeping")
                    } else {
                        print("[overlap] Error for offset", offset, ":", error, "seconds — exceeds max alignment error, skipping")
                        // a positive error means that upstream is late. If it is too late,
                        // it is implausible.

                        // a negative error is early, there is no such thing as "too early"
                        // because busses come in order.
                        continue
                    }
                } else {
                    print("[overlap] Error for offset", offset, ":", error, "seconds")
                }
            } else {
                // Zero overlap only makes sense if this window starts after
                // everything we already know — otherwise it can't be a
                // valid alignment (it would imply a bus arriving *before*
                // one we've already confirmed, which breaks FIFO ordering).

                // if the earliest projected ETA could feasibly be the same bus as the last bus in the tail,
                // we disregard this offset because it is probably a ghost bus.
                if projectedETAs[0] <= tail.estimates.last!.eta.incrementingBy(timeDelta: MAX_ALIGNMENT_ERROR) {
                    print("[non-overlap] Has plausible alignment, but window starts before tail, skipping")
                    continue
                }
                drift = .zero
                error = .zero
                lastLoopDrift = drift
                print("[non-overlap] Error for offset", offset, ":", error, "seconds")
            }

            if bestError == nil || error < bestError! {
                bestError = error
                bestOffset = offset
                bestDrift = drift
            }
        }

        if bestOffset == nil {
            // No plausible alignment found (e.g. very noisy projection).
            // Fall back to the conservative option: assume full overlap
            // with the tail (i.e. treat this window as telling us nothing
            // new) rather than risk fabricating or duplicating a bus.
            bestOffset = 0

            let overlapLen = min(rawWindow.estimates.count, tail.estimates.count)
            if overlapLen > 0 {
                let diffs = (0..<overlapLen).map { i in
                    projectedETAs[i].timeDelta(since: tail.estimates[bestOffset! + i].eta)
                }
                bestDrift = lastLoopDrift - (diffs.reduce(.zero, +).scale(by: 1 / Double(overlapLen)))
            }
            // NOTE: the Python source leaves `best_error` as `None` in this
            // branch (it's never assigned here), which would raise a
            // `TypeError` a few lines later when computing
            // `raw_window.delta_error + best_error`. This translation
            // treats a still-unset `bestError` as zero instead of crashing.
        }

        return (bestOffset ?? 0, bestError ?? .zero, bestDrift)
    }
}
