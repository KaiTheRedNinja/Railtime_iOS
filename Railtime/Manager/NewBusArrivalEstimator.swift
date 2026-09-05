import Foundation

// --------------------------------------------------------------------------
// Array helper
// --------------------------------------------------------------------------

extension Array {
    /// Indexes into the array the way Python's `list` does: a negative
    /// index counts backwards from the end (`stops[-1]` is the last
    /// element). Used to faithfully mirror a couple of spots in the
    /// original Python where an index can legitimately go negative and
    /// Python's wraparound (rather than a crash) is the observed behaviour.
    /// Just like Python, an index that is out of range even after
    /// wraparound will trap.
    subscript(pythonIndex index: Int) -> Element {
        let resolvedIndex = index >= 0 ? index : count + index
        return self[resolvedIndex]
    }
}

// --------------------------------------------------------------------------
// Data models
// --------------------------------------------------------------------------

/// An estimate for when a bus, with a given ID, will arrive at a given stop.
struct BusArrivalEstimate {
    /// The ID of this bus.
    var busId: String
    /// The service number of this bus.
    var busServiceNo: String
    /// The projected arrival time at the target stop.
    var eta: TimeOfDay

    /// Where the information for the bus's arrival came from
    var source: DataSource
    /// The upstream stop code used for this projection.
    var projectedFromStop: String?

    /// Optional metadata from the API.
    var load: String?
    /// Optional metadata from the API.
    var feature: String?
    /// Optional metadata from the API.
    var busType: String?

    /// Where the information for a bus' arrival comes from
    enum DataSource {
        /// The data was obtained directly from the LTA Live Bus API
        case live
        /// The data was projected from an up/downstream `live` bus
        case projected
        /// The data was extrapolated from the last known `live` or `projected` bus using known frequency data
        case extrapolated
    }

    /// Optional metadata from the API.
    init(
        busId: String,
        busServiceNo: String,
        eta: TimeOfDay,
        source: DataSource,
        projectedFromStop: String? = nil,
        load: String? = nil,
        feature: String? = nil,
        busType: String? = nil
    ) {
        self.busId = busId
        self.busServiceNo = busServiceNo
        self.eta = eta
        self.source = source
        self.projectedFromStop = projectedFromStop
        self.load = load
        self.feature = feature
        self.busType = busType
    }

    /// The time delta from `ref` until this bus's ETA.
    func minutesFrom(_ ref: Date) -> TimeDelta {
        eta.timeDelta(since: .init(date: ref))
    }
}

/// All the estimates for when busses will arrive at this stop.
struct StopArrivalEstimates {
    /// The ID of this stop.
    var stopId: String
    /// The delta-time of this stop, relative to some downstream target, in
    /// seconds (equivalent to the Python `timedelta` field of the same
    /// name).
    var deltaTime: TimeDelta
    /// The error in the delta-time of this stop, relative to some
    /// downstream target, in seconds.
    var deltaError: TimeDelta
    /// The arrival estimates, first.
    var estimates: [BusArrivalEstimate]
}

/// Errors thrown by ``NewBusArrivalEstimator``.
enum BusArrivalEstimatorError: Error {
    /// No BusRoutes data exists at all for the requested service.
    case noRouteData(serviceNo: String)
    /// The requested stop isn't on any direction of the requested service.
    case stopNotFound(stopCode: String, serviceNo: String)
}

// --------------------------------------------------------------------------
// Core estimator
// --------------------------------------------------------------------------

final class NewBusArrivalEstimator {
    /// The underlying API client.
    let client: LTAClient
    /// The reference "current time" estimates are computed relative to.
    var now: Date
    /// The cached data source wrapping `client`'s non-live endpoints.
    let data: CachedDataSource

    /// Creates an estimator.
    ///
    /// - Parameters:
    ///   - client: The LTA API client to use.
    ///   - now: The reference time to use as "now". Defaults to the current
    ///     time.
    ///   - cacheDir: Directory for the on-disk non-live data cache.
    ///   - cacheTTLHours: How long, in hours, cached non-live data stays
    ///     valid.
    init(
        client: LTAClient,
        now: Date? = nil,
        cacheDir: String = "./lta_cache",
        cacheTTLHours: Double = 24.0
    ) {
        self.client = client
        self.now = now ?? .now
        self.data = CachedDataSource(client: client, cache: DiskCache(root: cacheDir, ttl: cacheTTLHours * 3600))
    }

    // -- main entry point --------------------------------------------------

    /// Estimate the arrival times of a bus at a given bus stop, based on the
    /// arrival times of that bus at previous stops along its route.
    ///
    /// - Parameters:
    ///   - busStopCode: The target stop to estimate arrivals at.
    ///   - serviceNo: The bus service to estimate.
    ///   - numTarget: The desired number of upcoming buses to estimate.
    ///   - maxLookbackStops: The maximum number of upstream stops to poll.
    ///   - inDirection: If provided, restricts the route lookup to this
    ///     direction.
    /// - Returns: A list of `StopArrivalEstimates`, one for each stop along
    ///   the route, in upstream-to-downstream order (so the first stop in
    ///   the list is the furthest upstream, and the last stop in the list
    ///   is the target stop).
    func estimate(
        busStopCode: String,
        serviceNo: String,
        numTarget: Int = 5,
        maxLookbackStops: Int = 12,
        inDirection: Int? = nil
    ) async throws -> [StopArrivalEstimates] {
        let (stops, targetIdx) = try await routeFor(serviceNo: serviceNo, busStopCode: busStopCode, inDirection: inDirection)
        let targetRow = stops[targetIdx]
        let currentDayType = dayType(for: now)

        // Confirmed arrivals directly at the target stop.
        let confirmed = try await confirmedArrivals(busStopCode: busStopCode, serviceNo: serviceNo)

        // estimates are from the target stop first, upstream stops later. The earliest
        // stop in a bus's route will be the last in the list for ease of appending.
        // this will be inverted at the bottom.
        var estimates: [StopArrivalEstimates] = [confirmed]

        if estimates.count >= numTarget {
            // NOTE: the Python source sorts this branch with
            // `sorted(estimates, key=lambda e: e.eta)`, but `.eta` is a
            // property of `BusArrivalEstimate`, not `StopArrivalEstimates`
            // — this branch would raise an `AttributeError` if it were ever
            // reached (only possible when `numTarget <= 1`). This
            // translation sorts by each stop's earliest estimate instead,
            // which best matches the apparent intent.
            let sorted = estimates.sorted { lhs, rhs in
                if let lhs = lhs.estimates.first?.eta, let rhs = rhs.estimates.first?.eta {
                    lhs.isBetween(latest: rhs)
                } else {
                    // one or both missing - return false
                    false
                }
            }
            return Array(sorted.prefix(numTarget))
        }

        var stopGap: TimeDelta = .zero
        if !confirmed.estimates.isEmpty {
            // we would like to use the 2nd confirmed ETA, but we will make do with the 1st if there is only one.
            let secondOrFirstIndex = min(confirmed.estimates.count - 1, 1)
            let firstETADelta = confirmed.estimates[secondOrFirstIndex].eta.timeDelta(since: TimeOfDay(date: now))
            stopGap = min(firstETADelta * STOP_GAP_PERCENTAGE, MAX_STOP_GAP) // Cap the stop gap at the maximum allowed
        }

        // Walk upstream stops, closest to target first, projecting their
        // live buses forward to the target stop.
        let lookback = min(maxLookbackStops, targetIdx) // don't look back past the first stop
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

        while attempted < lookback {
            print("Attempt #", attempted + 1, "of", lookback, "— bus count:", busCount, "of", numTarget)

            stopOffset += 1
            if busCount >= numTarget {
                break
            }
            let upstreamIdx = targetIdx - stopOffset
            // Mirrors Python's negative-index wraparound: if `stopOffset`
            // ever runs past `targetIdx` (possible since `attempted` is
            // only bumped on a successful, far-enough-upstream poll), this
            // indexes from the end of `stops`, exactly like the Python
            // source's `stops[upstream_idx]` would.
            let upstreamRow = stops[pythonIndex: upstreamIdx]
            let upstreamCode = upstreamRow.busStopCode

            guard let upstreamScheduleDelta = scheduleDelta(upstreamRow: upstreamRow, targetRow: targetRow, dayType: currentDayType) else {
                // attempt not made
                continue
            }

            // the current estimated delta time, which is calculated using:
            // D_curr,est = D_prev + (D_prev,sched - D_curr,sched)
            let scheduleDeltaSinceLast = (upstreamScheduleDelta - currentScheduleDelta) * 60
            let estimatedDeltaTime = currentDelta + scheduleDeltaSinceLast
            if scheduleDeltaSinceLast < stopGap {
                print(
                    "Skipping upstream stop", upstreamCode,
                    "— projected delta", upstreamScheduleDelta,
                    "min,", scheduleDeltaSinceLast / 60.0,
                    "min from last is less than stop gap", stopGap / 60.0, "min"
                )
                // attempt not made
                continue // too close to target stop to be useful
            }

            print(
                "Checking upstream stop", upstreamCode,
                "— projected delta", upstreamScheduleDelta,
                "min,", scheduleDeltaSinceLast / 60.0,
                "min, estimated delta", estimatedDeltaTime / 60.0, "min"
            )

            let upstreamBusArrival: BusArrivalResponse
            do {
                upstreamBusArrival = try await data.getBusArrival(busStopCode: upstreamCode, serviceNo: serviceNo)
            } catch {
                // attempt failed, do not count as an attempt
                continue
            }

            attempted += 1 // attempt made, regardless of whether we got a valid response
            guard let service = upstreamBusArrival.services.first else { // filtered by ServiceNo, so at most one entry
                continue
            }

            // Build this stop's window: up to 3 buses, in the temporal
            // order the API already returns them, each projected forward
            // to the target stop's timeline.
            // this window is for THIS STOP!! It will be projected to future stops later.
            var rawWindow = StopArrivalEstimates(
                stopId: upstreamCode,
                deltaTime: estimatedDeltaTime,
                deltaError: .zero,
                estimates: []
            )

            // get the next 3 busses and save them as arrivals at this (upstream) stop.
            // projection will be done during merging.
            for nextBusN in service.nextBuses {
                // get the ETA for the next bus at this location
                guard let nextBusN, let etaUpstream = parseISO(nextBusN.estimatedArrival) else { continue }

                // add the arrival at the UPSTREAM stop to the current window
                rawWindow.estimates.append(BusArrivalEstimate(
                    busId: "UNASSIGNED",
                    busServiceNo: serviceNo,
                    eta: TimeOfDay(date: etaUpstream),
                    source: .live,
                    load: nextBusN.load,
                    feature: nextBusN.feature,
                    busType: nextBusN.type
                ))
            }

            let mergeResult = NewBusArrivalEstimator.alignMergeAndProjectWindow(
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
                    let candidateGap = min(etas[idx].eta.timeDelta(since: TimeOfDay(date: now)) * STOP_GAP_PERCENTAGE, MAX_STOP_GAP)
                    stopGap = max(stopGap, candidateGap)
                }
            }
            print("New drift: ", drift, "seconds")
            print("New stop gap: ", stopGap, "seconds")

            currentDelta = realDeltaTime
            currentScheduleDelta = upstreamScheduleDelta
        }

        // 3) Fallback: extrapolate using BusServices dispatch frequency if
        //    we still don't have enough.
        if estimates.count < numTarget {
            estimates = try await extrapolateWithFrequency(
                estimates: estimates, serviceNo: serviceNo, numTarget: numTarget, currentCount: busCount
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

    // -- data loading --------------------------------------------------

    /// Returns (ordered stops for the correct direction, index of the
    /// target stop).
    ///
    /// - Parameters:
    ///   - serviceNo: The service to look up routes for.
    ///   - busStopCode: The stop to locate along the route.
    ///   - inDirection: If provided, restricts the search to this
    ///     direction.
    func routeFor(
        serviceNo: String, busStopCode: String, inDirection: Int? = nil
    ) async throws -> ([BusRouteRow], Int) {
        print("Loading route info for service", serviceNo, "and stop", busStopCode)
        let rows = try await data.getServiceRoutes(serviceNo: serviceNo)
        if rows.isEmpty {
            throw BusArrivalEstimatorError.noRouteData(serviceNo: serviceNo)
        }

        // Swift's Dictionary doesn't preserve insertion order the way
        // Python's dict does, so directions are tracked separately to keep
        // iteration order matching the order directions were first seen.
        var directionOrder: [Int] = []
        var byDirection: [Int: [BusRouteRow]] = [:]
        for r in rows {
            if byDirection[r.direction] == nil {
                directionOrder.append(r.direction)
            }
            byDirection[r.direction, default: []].append(r)
        }

        for direction in directionOrder {
            if let inDirection, direction != inDirection {
                continue
            }
            guard var stops = byDirection[direction] else { continue }
            stops.sort { $0.stopSequence < $1.stopSequence }
            for (i, s) in stops.enumerated() {
                if s.busStopCode == busStopCode {
                    print("Identified bus stop, direction", direction)
                    return (stops, i)
                }
            }
        }

        throw BusArrivalEstimatorError.stopNotFound(stopCode: busStopCode, serviceNo: serviceNo)
    }

    /// Returns static BusServices dispatch-frequency information for
    /// `serviceNo`.
    func serviceFreq(serviceNo: String) async throws -> BusServiceInfo? {
        try await data.getServiceInfo(serviceNo: serviceNo)
    }

    /// Minutes the schedule implies it takes to travel from the upstream
    /// stop to the target stop, derived from the first-bus-of-the-day
    /// timings. Falls back to a distance-based average speed if schedule
    /// times are missing for either stop.
    ///
    /// - Parameters:
    ///   - upstreamRow: The upstream stop's BusRoutes row.
    ///   - targetRow: The target stop's BusRoutes row.
    ///   - dayType: `"WD"`, `"SAT"`, or `"SUN"`, as returned by
    ///     ``dayType(for:)``.
    /// - Returns: The schedule-implied travel time, in minutes, or `nil` if
    ///   it can't be determined.
    func scheduleDelta(
        upstreamRow: BusRouteRow, targetRow: BusRouteRow, dayType: String
    ) -> TimeDelta? {
        // NOTE: the first two entries below are a direct, literal
        // translation of the Python source's `"{day_type}_FirstBus"` /
        // `"{day_type}_LastBus"` — these read like they were meant to be
        // f-strings interpolating `day_type`, but as written in the
        // original they are plain literal strings that never match a real
        // BusRoutes column name. That bug is preserved here:
        // `scheduleColumn(named:)` returns `nil` for these two entries, so
        // evaluation always falls through to the WD/SAT/SUN fallbacks
        // below, exactly as it does in the Python source.
        let timeTargets = [
            "{day_type}_FirstBus",
            "{day_type}_LastBus",

            // fallback to regular bus frequencies if today's type is unavailable
            "WD_LastBus",
            "SAT_FirstBus",
            "SAT_LastBus",
            "SUN_FirstBus",
            "SUN_LastBus",
        ]

        for target in timeTargets {
            let tUp = upstreamRow.scheduleColumn(named: target)
            let tTgt = targetRow.scheduleColumn(named: target)
            if let tUp, let tTgt {
                let delta = tTgt.timeDelta(since: tUp)
                // sometimes the schedule is weird and returns negative data.
                // therefore we sometimes have to use backup data.
                if delta >= .zero {
                    return delta
                }
            }
        }

        // Fallback: assume ~20 km/h average scheduled speed using route
        // distance (BusRoutes 'Distance' is cumulative km from origin).
        let distDelta = targetRow.distance - upstreamRow.distance
        if distDelta < 0 {
            return nil
        }
        let avgSpeedKmh = 20.0
        return .hours(distDelta / avgSpeedKmh)
    }

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
    static func alignMergeAndProjectWindow(
        known: [StopArrivalEstimates],
        rawWindow: StopArrivalEstimates,
        currentBusCount: Int
    ) -> (known: [StopArrivalEstimates], drift: TimeDelta, busCount: Int) {
        var known = known

        if rawWindow.estimates.isEmpty {
            // if no estimates are available, just add it verbatim.
            print("No estimates available for stop", rawWindow.stopId, "— adding verbatim")
            known.append(rawWindow)
            return (known, rawWindow.deltaTime, currentBusCount)
        }

        // get the arrivals from the stop closest to this
        // that actually has estimates. This is the "tail" of the known sequence.
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
            return (known, rawWindow.deltaTime, currentBusCount)
        }

        let projectedETAs = rawWindow.estimates.map {
            $0.eta.incrementingBy(timeDelta: rawWindow.deltaTime - tail.deltaTime)
        }

        // compare the ETAs for both AT THEIR RESPECTIVE TIMES, then with the projected delta time of the raw window
        print()
        print(tail.deltaTime / 60, "min Tail ETAs:", tail.estimates.map { $0.eta.hhmmdd }.joined(separator: " | "))
        print(rawWindow.deltaTime / 60, "min Raw ETAs:", rawWindow.estimates.map { $0.eta.hhmmdd  }.joined(separator: " | "))
        print("PROJECTED ETAs:", projectedETAs.map { $0.hhmmdd }.joined(separator: " | "))
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
                drift = diffs.reduce(.zero, +) / Double(overlapLen)
                error = max(.zero, diffs.map { $0.magnitude() }.reduce(.zero, +) / Double(overlapLen))
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
                if projectedETAs[0].isBetween(latest: tail.estimates.last!.eta.incrementingBy(timeDelta: MAX_ALIGNMENT_ERROR)) {
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
                bestDrift = lastLoopDrift - (diffs.reduce(.zero, +) / Double(overlapLen))
            }
            // NOTE: the Python source leaves `best_error` as `None` in this
            // branch (it's never assigned here), which would raise a
            // `TypeError` a few lines later when computing
            // `raw_window.delta_error + best_error`. This translation
            // treats a still-unset `bestError` as zero instead of crashing.
        }
        let resolvedBestOffset = bestOffset ?? 0
        let resolvedBestError = bestError ?? .zero

        print("Best offset: ", resolvedBestOffset)
        print("Best drift: ", bestDrift, "seconds")

        let overlapLen = min(rawWindow.estimates.count, tail.estimates.count - resolvedBestOffset)

        // NOTE: `tail.estimates` is always non-empty here, since `tail` was
        // only ever chosen above from a candidate with non-empty
        // `estimates` — so the Python `else len(known) * 3` arm is dead
        // code, kept below only for structural fidelity.
        let lastKnownBusIdNum: Int
        if let lastBusId = tail.estimates.last?.busId,
           let numericSuffix = lastBusId.split(separator: "_").last,
           let parsed = Int(numericSuffix) {
            lastKnownBusIdNum = parsed
        } else {
            lastKnownBusIdNum = known.count * 3
        }

        let firstBusNumForThisStop = lastKnownBusIdNum - tail.estimates.count + resolvedBestOffset + 1
        var rawWindowEstimates = rawWindow.estimates
        for i in rawWindowEstimates.indices {
            rawWindowEstimates[i].busId = "bus_\(firstBusNumForThisStop + i)"
        }
        var thisStop = StopArrivalEstimates(
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

        // literally just append the raw window to whats known, this is only for testing
        known.append(thisStop)
        return (known, bestDrift, firstBusNumForThisStop + rawWindow.estimates.count - 1)
    }

    // -- sub-steps --------------------------------------------------

    /// Fetches confirmed (i.e. live, at the exact target stop) arrivals for
    /// `serviceNo` at `busStopCode`.
    func confirmedArrivals(busStopCode: String, serviceNo: String) async throws -> StopArrivalEstimates {
        let arrival = try await data.getBusArrival(busStopCode: busStopCode, serviceNo: serviceNo)
        guard let svc = arrival.services.first else {
            // NOTE: the Python source returns a bare `[]` here despite the
            // function being declared to return a `StopArrivalEstimates` —
            // a latent type mismatch. This translation returns an empty
            // `StopArrivalEstimates` instead, matching the declared and
            // evidently intended return type.
            return StopArrivalEstimates(stopId: busStopCode, deltaTime: .zero, deltaError: .zero, estimates: [])
        }
        var out: [BusArrivalEstimate] = []
        for nextBus in svc.nextBuses {
            guard let nextBus, let eta = parseISO(nextBus.estimatedArrival) else {
                continue
            }
            out.append(BusArrivalEstimate(
                busId: "bus_\(out.count)",
                busServiceNo: serviceNo,
                eta: TimeOfDay(date: eta),
                source: .live,
                projectedFromStop: nil,
                load: nextBus.load,
                feature: nextBus.feature,
                busType: nextBus.type
            ))
        }
        return StopArrivalEstimates(stopId: busStopCode, deltaTime: .zero, deltaError: .zero, estimates: out)
    }

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
    func extrapolateWithFrequency(
        estimates: [StopArrivalEstimates], serviceNo: String, numTarget: Int, currentCount: Int
    ) async throws -> [StopArrivalEstimates] {
        guard let freq = try await serviceFreq(serviceNo: serviceNo) else {
            return estimates // nothing to extrapolate with
        }
        var estimates = estimates
        let anchor = estimates.last?.estimates
            .map { $0.eta }
            .max(by: { $0.secondsSinceMidnight > $1.secondsSinceMidnight }) ?? TimeOfDay(date: now)
        let calendar = Calendar.current

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
        if anchor.isBetween(earliest: .init(hh: 6, mm: 30), latest: .init(hh: 8, mm: 30)) {
            gap = bandMidpoint(freq.amPeakFreq)
        } else if anchor.isBetween(earliest: .init(hh: 17, mm: 00), latest: .init(hh: 19, mm: 00)) {
            gap = bandMidpoint(freq.pmPeakFreq)
        } else if anchor.isBetween(earliest: .init(hh: 19, mm: 00)) {
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
