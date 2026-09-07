//
//  BusArrivalEstimator+data.swift
//  Railtime
//
//  Created by Kai Quan Tay on 7/9/26.
//

extension BusArrivalEstimator {
    // -- data loading --------------------------------------------------

    /// Returns (ordered stops for the correct direction, index of the
    /// target stop).
    ///
    /// - Parameters:
    ///   - serviceNo: The service to look up routes for.
    ///   - busStopCode: The stop to locate along the route.
    ///   - inDirection: If provided, restricts the search to this
    ///     direction.
    internal func routeFor(
        serviceNo: String, busStopCode: String, inDirection: Int? = nil
    ) async throws -> ([LTABusRouteRow], Int) {
        print("Loading route info for service", serviceNo, "and stop", busStopCode)
        let rows = try await data.getServiceRoutes(serviceNo: serviceNo)
        if rows.isEmpty {
            throw BusArrivalEstimatorError.noRouteData(serviceNo: serviceNo)
        }

        // Swift's Dictionary doesn't preserve insertion order the way
        // Python's dict does, so directions are tracked separately to keep
        // iteration order matching the order directions were first seen.
        var directionOrder: [Int] = []
        var byDirection: [Int: [LTABusRouteRow]] = [:]
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
    internal func serviceFreq(serviceNo: String) async throws -> LTABusServiceInfo? {
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
    internal func scheduleDelta(
        upstreamRow: LTABusRouteRow, targetRow: LTABusRouteRow, dayType: String
    ) -> TimeDelta? {
        let timeTargets = [
            "\(dayType)_FirstBus",
            "\(dayType)_LastBus",

            // fallback to regular bus frequencies if today's type is unavailable
            "WD_FirstBus",
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

    /// Fetches confirmed (i.e. live, at the exact target stop) arrivals for
    /// `serviceNo` at `busStopCode`.
    internal func confirmedArrivals(busStopCode: String, serviceNo: String) async throws -> StopArrivalEstimates {
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
                eta: eta,
                source: .live,
                projectedFromStop: nil,
                load: nextBus.load,
                feature: nextBus.feature,
                busType: nextBus.type
            ))
        }
        return StopArrivalEstimates(stopId: busStopCode, deltaTime: .zero, deltaError: .zero, estimates: out)
    }
}
