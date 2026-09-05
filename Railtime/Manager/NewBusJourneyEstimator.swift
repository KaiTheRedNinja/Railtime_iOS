import Foundation

// --------------------------------------------------------------------------
// Journey estimator
// --------------------------------------------------------------------------

/// Errors thrown by ``NewBusJourneyEstimator``.
enum BusJourneyEstimatorError: Error {
    /// Neither an existing `NewBusArrivalEstimator` nor an `LTAClient` was
    /// supplied to the initializer.
    case missingArrivalEstimatorOrClient
    /// The requested service doesn't serve the destination stop at all (in
    /// this direction).
    case destinationNotServed(serviceNo: String, destinationStopCode: String)
    /// The destination stop exists on the route, but isn't downstream of
    /// the target stop.
    case destinationNotDownstream(destinationStopCode: String, busStopCode: String, serviceNo: String)
}

/// Wraps a `NewBusArrivalEstimator` to additionally estimate arrivals at a
/// downstream destination stop. `NewBusArrivalEstimator` already knows how
/// to look *upstream* of a target stop to fill in future arrivals; this
/// class reuses it for the "upstream -> target" leg, then walks
/// *downstream* from the target to the destination using a mirrored
/// version of the same alignment/drift/projection technique.
///
/// Key difference from the upstream walk: we do NOT apply a stop gap. The
/// upstream walk skips upstream stops that are "too close" to the target
/// because it only cares about the target stop's arrivals. Here, the user
/// wants to see the bus's progress at every stop between the target and the
/// destination, so every intermediate stop is queried and returned.
final class NewBusJourneyEstimator {
    /// The wrapped arrival estimator used for the upstream -> target leg.
    let arrivalEstimator: NewBusArrivalEstimator
    /// Convenience passthrough so callers can treat this like a
    /// self-contained object without reaching into `arrivalEstimator`.
    let client: LTAClient
    /// Convenience passthrough so callers can treat this like a
    /// self-contained object without reaching into `arrivalEstimator`.
    let data: CachedDataSource
    /// Convenience passthrough so callers can treat this like a
    /// self-contained object without reaching into `arrivalEstimator`.
    var now: Date

    /// Creates a journey estimator, either wrapping an existing
    /// `NewBusArrivalEstimator` or building one from `client`.
    ///
    /// - Parameters:
    ///   - arrivalEstimator: An existing arrival estimator to wrap. Takes
    ///     precedence over `client` if both are supplied.
    ///   - client: An API client to build a new arrival estimator from, if
    ///     `arrivalEstimator` isn't supplied.
    ///   - now: The reference "current time" to use, if building a new
    ///     arrival estimator.
    ///   - cacheDir: Directory for the on-disk non-live data cache, if
    ///     building a new arrival estimator.
    ///   - cacheTTLHours: How long, in hours, cached non-live data stays
    ///     valid, if building a new arrival estimator.
    /// - Throws: ``BusJourneyEstimatorError/missingArrivalEstimatorOrClient``
    ///   if neither `arrivalEstimator` nor `client` is supplied.
    init(
        arrivalEstimator: NewBusArrivalEstimator? = nil,
        client: LTAClient? = nil,
        now: Date? = nil,
        cacheDir: String = "./lta_cache",
        cacheTTLHours: Double = 24.0
    ) throws {
        if let arrivalEstimator {
            self.arrivalEstimator = arrivalEstimator
        } else {
            guard let client else {
                throw BusJourneyEstimatorError.missingArrivalEstimatorOrClient
            }
            self.arrivalEstimator = NewBusArrivalEstimator(
                client: client, now: now, cacheDir: cacheDir, cacheTTLHours: cacheTTLHours
            )
        }

        // convenience passthroughs so callers can treat this like a
        // self-contained object without reaching into arrival_estimator
        self.client = self.arrivalEstimator.client
        self.data = self.arrivalEstimator.data
        self.now = self.arrivalEstimator.now
    }

    // -- main entry point --------------------------------------------------

    /// Estimates arrivals at `busStopCode`, and — if `destinationStopCode`
    /// is provided — continues the walk downstream all the way to that
    /// destination.
    ///
    /// - Parameters:
    ///   - busStopCode: The target stop for the upstream leg.
    ///   - serviceNo: The bus service to estimate.
    ///   - numTarget: The desired number of upcoming buses at the target
    ///     stop.
    ///   - maxLookbackStops: The maximum number of upstream stops to poll.
    ///   - inDirection: If provided, restricts the route lookup to this
    ///     direction.
    ///   - destinationStopCode: If provided, a stop downstream of
    ///     `busStopCode` to walk the journey out to.
    /// - Returns: The full upstream-to-destination sequence of
    ///   `StopArrivalEstimates`.
    func estimate(
        busStopCode: String,
        serviceNo: String,
        numTarget: Int = 5,
        maxLookbackStops: Int = 12,
        inDirection: Int? = nil,
        destinationStopCode: String? = nil
    ) async throws -> [StopArrivalEstimates] {
        // 1) Get the upstream -> target leg verbatim from NewBusArrivalEstimator.
        let upstreamEstimates = try await arrivalEstimator.estimate(
            busStopCode: busStopCode,
            serviceNo: serviceNo,
            numTarget: numTarget,
            maxLookbackStops: maxLookbackStops,
            inDirection: inDirection
        )

        guard let destinationStopCode else {
            return upstreamEstimates
        }

        // 2) Validate the destination stop and figure out how far downstream it is.
        let (stops, targetIdx) = try await arrivalEstimator.routeFor(
            serviceNo: serviceNo, busStopCode: busStopCode, inDirection: inDirection
        )

        var destinationIdx: Int?
        for (i, s) in stops.enumerated() {
            if s.busStopCode == destinationStopCode {
                destinationIdx = i
                break
            }
        }

        guard let destinationIdx else {
            // a) this bus doesn't serve that stop at all (in this direction)
            throw BusJourneyEstimatorError.destinationNotServed(
                serviceNo: serviceNo, destinationStopCode: destinationStopCode
            )
        }
        if destinationIdx <= targetIdx {
            // b) the stop exists, but it's not downstream of the target
            throw BusJourneyEstimatorError.destinationNotDownstream(
                destinationStopCode: destinationStopCode, busStopCode: busStopCode, serviceNo: serviceNo
            )
        }

        // c) how far downstream it is
        let numStopsDownstream = destinationIdx - targetIdx
        print("Destination \(destinationStopCode) is \(numStopsDownstream) stop(s) downstream of target \(busStopCode)")

        let currentDayType = dayType(for: now)
        let targetRow = stops[targetIdx]

        // `known` mirrors the internal (pre-reversal) list used by
        // NewBusArrivalEstimator.estimate: it grows one stop at a time, and
        // delta_time is measured as (this stop's time - target's time), so
        // it starts at 0 for the target stop itself and grows *positive* as
        // we move further downstream (no inversion needed here, since these
        // stops are already in "target-first" order, same as the final
        // result should be).
        let targetEntry = upstreamEstimates[upstreamEstimates.count - 1]
        var known: [StopArrivalEstimates] = [
            StopArrivalEstimates(
                stopId: targetEntry.stopId,
                deltaTime: .zero,
                deltaError: targetEntry.deltaError,
                estimates: targetEntry.estimates
            )
        ]

        var currentDelta: TimeDelta = .zero
        var currentScheduleDelta: TimeDelta = .zero

        for offset in 1...numStopsDownstream {
            let downstreamIdx = targetIdx + offset
            let downstreamRow = stops[downstreamIdx]
            let downstreamCode = downstreamRow.busStopCode

            // Schedule delta is always computed relative to the fixed target
            // row (same pattern NewBusArrivalEstimator uses upstream), then
            // we take the incremental difference from the previous stop's
            // schedule delta to get the hop-by-hop travel time.
            var downstreamScheduleDelta = arrivalEstimator.scheduleDelta(
                upstreamRow: targetRow, targetRow: downstreamRow, dayType: currentDayType
            )
            if downstreamScheduleDelta == nil {
                // No schedule data for this stop pairing — fall back to no
                // additional schedule-implied travel time for this hop
                // rather than skipping the stop outright (we must return an
                // entry for every intermediate stop).
                downstreamScheduleDelta = currentScheduleDelta
            }
            let resolvedDownstreamScheduleDelta = downstreamScheduleDelta!

            let scheduleDeltaSinceLast = resolvedDownstreamScheduleDelta - currentScheduleDelta
            let estimatedDeltaTime = currentDelta + scheduleDeltaSinceLast
            // NOTE: no stop gap here, unlike the upstream walk — every
            // intermediate stop gets queried and returned.

            print(
                "Checking downstream stop", downstreamCode,
                "— schedule delta", resolvedDownstreamScheduleDelta, "min,",
                "estimated delta", estimatedDeltaTime.seconds / 60.0, "min"
            )

            let downstreamBusArrival: BusArrivalResponse
            do {
                downstreamBusArrival = try await data.getBusArrival(busStopCode: downstreamCode, serviceNo: serviceNo)
            } catch {
                // Live data unavailable for this stop. We still need an
                // entry for it (it's a required intermediate stop on the
                // journey), so fall back to a pure schedule-based projection
                // of whatever we already know.
                known = NewBusJourneyEstimator.projectKnownForward(
                    known: known, stopId: downstreamCode, deltaTime: estimatedDeltaTime
                )
                currentDelta = estimatedDeltaTime
                currentScheduleDelta = resolvedDownstreamScheduleDelta
                continue
            }

            var rawWindow = StopArrivalEstimates(
                stopId: downstreamCode, deltaTime: estimatedDeltaTime, deltaError: .zero, estimates: []
            )
            if let service = downstreamBusArrival.services.first { // filtered by ServiceNo, so at most one entry
                for nextBusN in service.nextBuses {
                    guard let nextBusN,
                          let etaDownstream = parseISO(nextBusN.estimatedArrival)
                    else { continue }
                    rawWindow.estimates.append(BusArrivalEstimate(
                        busId: "UNASSIGNED",
                        busServiceNo: serviceNo,
                        eta: etaDownstream,
                        source: .live,
                        load: nextBusN.load,
                        feature: nextBusN.feature,
                        busType: nextBusN.type
                    ))
                }
            }

            let mergeResult = NewBusJourneyEstimator.alignMergeAndProjectDownstream(known: known, rawWindow: rawWindow)
            known = mergeResult.known
            let drift = mergeResult.drift
            let realDeltaTime = estimatedDeltaTime + drift
            print("New drift:", drift, "seconds")

            currentDelta = realDeltaTime
            currentScheduleDelta = resolvedDownstreamScheduleDelta
        }

        // 3) Combine: upstream_estimates already ends with the target stop
        // (known[0] is that same target stop again), so drop the duplicate
        // and append every downstream stop we just resolved.
        return Array(upstreamEstimates.dropLast()) + known
    }

    // -- helpers --------------------------------------------------

    /// Used when live data for a downstream stop couldn't be fetched:
    /// project every bus we already know about (from the nearest
    /// previously-resolved stop) forward onto this stop using pure
    /// schedule delta, since there's no live data available to correct
    /// against.
    ///
    /// - Parameters:
    ///   - known: The stops resolved so far, target-first.
    ///   - stopId: The stop code that couldn't be queried live.
    ///   - deltaTime: The schedule-implied delta time for this stop,
    ///     relative to the target stop.
    /// - Returns: `known`, with a schedule-only projected entry appended
    ///   for `stopId`.
    static func projectKnownForward(
        known: [StopArrivalEstimates], stopId: String, deltaTime: TimeDelta
    ) -> [StopArrivalEstimates] {
        var known = known
        var tail: StopArrivalEstimates?
        for candidate in known.reversed() {
            if !candidate.estimates.isEmpty {
                tail = candidate
                break
            }
        }

        var thisStop = StopArrivalEstimates(
            stopId: stopId,
            deltaTime: deltaTime,
            deltaError: tail?.deltaError ?? .zero,
            estimates: []
        )
        if let tail {
            for e in tail.estimates {
                thisStop.estimates.append(BusArrivalEstimate(
                    busId: e.busId,
                    busServiceNo: e.busServiceNo,
                    eta: e.eta.incrementingBy(timeDelta: deltaTime - tail.deltaTime),
                    source: .projected,
                    projectedFromStop: tail.stopId,
                    load: e.load,
                    feature: e.feature,
                    busType: e.busType
                ))
            }
        }
        known.append(thisStop)
        return known
    }

    /// Downstream counterpart to
    /// `NewBusArrivalEstimator.alignMergeAndProjectWindow`.
    ///
    /// The direction of travel is reversed relative to the upstream case:
    ///   - `known` grows from the target stop outward towards the destination.
    ///   - `tail` is the most recently resolved stop, which is UPSTREAM of
    ///     `rawWindow`'s stop (i.e. closer to the target, already processed).
    ///   - Any bus known at `tail` must eventually reach `rawWindow`'s stop,
    ///     so when `rawWindow`'s live snapshot (only ever up to 3 buses)
    ///     doesn't cover all of `tail`'s known buses, we PROJECT `tail`'s
    ///     remaining buses forward onto the new stop — the mirror image of
    ///     the upstream code, which projects newly-seen buses backwards
    ///     onto stops it already knows about.
    ///   - Conversely, `rawWindow` can show buses that had already passed
    ///     `tail`'s stop by the time `tail` was queried (its live snapshot
    ///     is just a snapshot in time), so here it is `rawWindow` that can
    ///     have unmatched LEADING entries — the mirror image of `tail`
    ///     having unmatched leading entries in the upstream code.
    ///
    /// - Parameters:
    ///   - known: The downstream stops resolved so far, target-first.
    ///   - rawWindow: The newly-fetched live window for the downstream
    ///     stop being merged in.
    /// - Returns: The updated `known` list and the drift applied to align
    ///   `rawWindow`.
    static func alignMergeAndProjectDownstream(
        known: [StopArrivalEstimates],
        rawWindow: StopArrivalEstimates
    ) -> (known: [StopArrivalEstimates], drift: TimeDelta) {
        var known = known

        if rawWindow.estimates.isEmpty {
            print("No estimates available for stop", rawWindow.stopId, "— adding verbatim")
            known.append(rawWindow)
            return (known, rawWindow.deltaTime)
        }

        var tail: StopArrivalEstimates?
        for candidate in known.reversed() {
            if !candidate.estimates.isEmpty {
                tail = candidate
                break
            }
        }
        print("Tail stop:", tail?.stopId ?? "None")
        guard let tail else {
            print("No tail stop found for stop", rawWindow.stopId, "— adding verbatim")
            known.append(rawWindow)
            return (known, rawWindow.deltaTime)
        }

        // Bring raw_window's ETAs back onto tail's timeline for comparison.
        let projectedETAs = rawWindow.estimates.map {
            $0.eta.incrementingBy(timeDelta: .zero - (rawWindow.deltaTime - tail.deltaTime))
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        print()
        print(tail.deltaTime / 60, "min Tail ETAs:", tail.estimates.map { formatter.string(from: $0.eta) }.joined(separator: " | "))
        print(rawWindow.deltaTime / 60, "min Raw ETAs:", rawWindow.estimates.map { formatter.string(from: $0.eta) }.joined(separator: " | "))
        print("PROJECTED ETAs:", projectedETAs.map { formatter.string(from: $0) }.joined(separator: " | "))
        print()

        // offset now walks over raw_window instead of tail (see the doc comment above).
        var bestOffset: Int?
        var bestError: TimeDelta?
        var bestDrift: TimeDelta = .zero

        for offset in 0...rawWindow.estimates.count {
            let overlapLen = min(tail.estimates.count, rawWindow.estimates.count - offset)
            guard overlapLen > 0 else {
                // Zero overlap here means we're treating ALL of raw_window's
                // buses as unmatched/new. Unlike the upstream case, this is
                // not a very informative alignment (we can't compare against
                // anything), so we conservatively skip it and let the
                // fallback below (assume offset 0, full overlap) take over
                // if nothing better is found.
                continue
            }

            // positive value = downstream bus is running later than the
            // naive schedule-based projection, negative = running early
            let diffs = (0..<overlapLen).map { i in
                projectedETAs[offset + i].timeDelta(since: tail.estimates[i].eta)
            }
            let drift = diffs.reduce(.zero, +) / Double(overlapLen)
            let error = max(.zero, diffs.map { $0.magnitude() }.reduce(.zero, +) / Double(overlapLen))

            if error > MAX_ALIGNMENT_ERROR {
                // If offset==0 (nothing dropped from raw_window) and the
                // bus is running late, keep it anyway — a downstream bus
                // can always be arbitrarily late (traffic, etc). There's
                // no such thing as "too late" downstream, only "too
                // early" (physically implausible) is worth discarding.
                if offset == 0 && drift > .zero {
                    print("[overlap] Error for offset", offset, ":", error, "seconds — exceeds max alignment error, but drift is positive (late), keeping")
                } else {
                    print("[overlap] Error for offset", offset, ":", error, "seconds — exceeds max alignment error, skipping")
                    continue
                }
            } else {
                print("[overlap] Error for offset", offset, ":", error, "seconds")
            }

            if bestError == nil || error < bestError! {
                bestError = error
                bestOffset = offset
                bestDrift = drift
            }
        }

        if bestOffset == nil {
            // No plausible alignment found — fall back to the conservative
            // option of assuming full overlap starting at offset 0, rather
            // than risk fabricating or duplicating a bus.
            bestOffset = 0
            let overlapLen = min(tail.estimates.count, rawWindow.estimates.count)
            if overlapLen > 0 {
                let diffs = (0..<overlapLen).map { i in
                    projectedETAs[i].timeDelta(since: tail.estimates[i].eta)
                }
                bestDrift = diffs.reduce(.zero, +) / Double(overlapLen)
            }
        }
        let resolvedBestOffset = bestOffset ?? .zero
        let resolvedBestError = bestError ?? .zero

        print("Best offset: ", resolvedBestOffset)
        print("Best drift: ", bestDrift, "seconds")

        let overlapLen = min(tail.estimates.count, rawWindow.estimates.count - resolvedBestOffset)

        var thisStop = StopArrivalEstimates(
            stopId: rawWindow.stopId,
            deltaTime: rawWindow.deltaTime + bestDrift,
            deltaError: rawWindow.deltaError + resolvedBestError,
            estimates: rawWindow.estimates
        )

        // Entries at [best_offset, best_offset + overlap_len) match known
        // buses from tail — carry their bus_id over. Any leading entries
        // before best_offset are buses we didn't previously know about (they
        // must have already passed tail's stop by the time tail was
        // queried), so give them fresh IDs.
        var newBusCounter = 0
        for i in thisStop.estimates.indices {
            if resolvedBestOffset <= i && i < resolvedBestOffset + overlapLen {
                thisStop.estimates[i].busId = tail.estimates[i - resolvedBestOffset].busId
            } else {
                newBusCounter += 1
                thisStop.estimates[i].busId = "bus_new_\(rawWindow.stopId)_\(newBusCounter)"
            }
        }

        // Project any of tail's buses that raw_window's snapshot didn't
        // reach (it only ever reports up to 3) forward onto this new stop —
        // i.e. predict when buses we already know about will get here.
        for tailEstimate in tail.estimates[overlapLen...] {
            let projectedETA = tailEstimate.eta.incrementingBy(timeDelta: thisStop.deltaTime - tail.deltaTime)
            thisStop.estimates.append(BusArrivalEstimate(
                busId: tailEstimate.busId,
                busServiceNo: tailEstimate.busServiceNo,
                eta: projectedETA,
                source: .projected,
                projectedFromStop: tail.stopId,
                load: tailEstimate.load,
                feature: tailEstimate.feature,
                busType: tailEstimate.busType
            ))
        }

        thisStop.estimates.sort { $0.eta < $1.eta }

        known.append(thisStop)
        return (known, bestDrift)
    }
}
