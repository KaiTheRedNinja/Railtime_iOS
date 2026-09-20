//
//  LTADataSource.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 18/9/26.
//

import Foundation
import ZIPFoundation

/// Wraps LTAClient's non-live endpoints with disk caching.
///
/// Route data is cached one file per service (routes/<ServiceNo>.json) so
/// the cache directory stays human-manageable instead of one giant blob
/// for the whole bus network — even though the underlying BusRoutes API
/// itself has no server-side filter and must be pulled in full on a cache
/// miss. That one full pull is used to (re)populate the per-service files
/// for *every* service seen, not just the one requested, so subsequent
/// lookups for other services are usually cache hits too.
@MainActor
public final class LTADataSource {
    /// Key identifying a single in-memory short-term cache entry for a live
    /// BusArrival lookup.
    private struct ShortTermCacheKey: Hashable {
        /// The bus stop code that was queried.
        let busStopCode: String
        /// The service number filter that was applied, if any.
        let serviceNo: String?
    }

    /// The underlying API client.
    public let client: LTAClient
    /// The on-disk cache for non-live (BusRoutes/BusServices/BusStops) data.
    public let diskCache: DiskCache
    /// The in-memory cache for live data
    public let memoryCache: MemoryCache

    /// Creates a cached data source wrapping `client`, using `diskCache` for
    /// its on-disk non-live cache.
    public init(client: LTAClient, diskCache: DiskCache, memoryCache: MemoryCache) {
        self.client = client
        self.diskCache = diskCache
        self.memoryCache = memoryCache
    }

    /// Returns the live BusArrival data for a stop/service.
    ///
    /// This is cached for an extremely short time (5 seconds), in the case
    /// where analysis requires retrieving the same stop's data multiple
    /// times in quick succession.
    ///
    /// - Parameters:
    ///   - busStopCode: The bus stop code to query.
    ///   - serviceNo: If provided, restricts the response to this service.
    /// - Returns: The live BusArrival response.
    public func getBusArrival(busStopCode: String, serviceNo: String? = nil) async throws -> LTABusArrivalResponse {
        let cacheKey = "\(busStopCode)_\(serviceNo ?? "X")"
        if let cached: LTABusArrivalResponse = memoryCache.read(category: "busArrival", key: cacheKey, expiry: 5) {
            return cached
        }

        let data = try await client.busArrival(busStopCode: busStopCode, serviceNo: serviceNo)
        memoryCache.write(category: "busArrival", key: cacheKey, data: data)
        return data
    }

    /// Returns every BusRoutes row for `serviceNo`, using the on-disk cache
    /// when possible.
    ///
    /// - Parameter serviceNo: The service number to look up routes for.
    /// - Returns: The route rows for `serviceNo`, or an empty array if none
    ///   exist.
    public func getServiceRoutes(serviceNo: String) async throws -> [LTABusRouteRow] {
        print("Getting service routes for", serviceNo)
        if let cached: [LTABusRouteRow] = diskCache.read(category: "routes", key: serviceNo) {
            return cached
        }

        let allRows = try await client.busRoutes()
        var byService: [String: [LTABusRouteRow]] = [:]
        for row in allRows {
            byService[row.serviceNo, default: []].append(row)
        }
        for (svc, rows) in byService {
            diskCache.write(category: "routes", key: svc, data: rows)
        }
        return byService[serviceNo] ?? []
    }

    /// Returns static BusServices information for `serviceNo`, using the
    /// on-disk cache when possible.
    ///
    /// - Parameter serviceNo: The service number to look up.
    /// - Returns: The service's info row, or `nil` if the service doesn't
    ///   exist.
    public func getServiceInfo(serviceNo: String) async throws -> LTABusServiceInfo? {
        print("Getting service info for", serviceNo)
        if let cached: [LTABusServiceInfo] = diskCache.read(category: "services", key: serviceNo) {
            return cached.first
        }
        let rows = try await client.busServices(serviceNo: serviceNo)
        diskCache.write(category: "services", key: serviceNo, data: rows)
        return rows.first
    }

    /// Returns static BusStops information for `busStopCode`, using the
    /// on-disk cache when possible.
    ///
    /// - Parameter busStopCode: The bus stop code to look up.
    /// - Returns: The stop's info, or `nil` if the stop doesn't exist.
    public func getStopInfo(busStopCode: String) async throws -> LTABusStopInfo? {
        print("Getting stop info for", busStopCode)
        if let cached: LTABusStopInfo = diskCache.read(category: "stops", key: busStopCode) {
            return cached
        }
        let info = try await client.busStop(busStopCode: busStopCode)
        if let info {
            diskCache.write(category: "stops", key: busStopCode, data: info)
        }
        return info
    }

    /// Returns static MRT stops information for an `mrtStopCode`. This ONLY uses on-disk cache - use
    /// `saveMRTStopsToCache` to bulk-save from an external source.
    ///
    /// - Parameter mrtStopCode: The MRT stop code to look up.
    /// - Returns: The stop's info, or `nil` if the stop doesn't exist.
    public func getMRTStopInfo(mrtStopCode: String) -> LTATrainStopInfo? {
        if let cached: LTATrainStopInfo = diskCache.read(category: "stops", key: mrtStopCode) {
            return cached
        }
        return nil
    }

    /// Returns the routes for a given `serviceCode`. This ONLY uses on-disk cache - use
    /// `saveMRTRoutesToCache` to bulk-save from an external source.
    ///
    /// - Parameter serviceCode: The service number to look up routes for.
    /// - Returns: The routes for `serviceCode`, or `nil` if not found.
    public func getMRTServiceRoutes(serviceCode: String) async throws -> LTATrainRoutes? {
        print("Getting MRT service routes for", serviceCode)
        if let cached: LTATrainRoutes = diskCache.read(category: "routes", key: serviceCode) {
            return cached
        }
        return nil
    }

    /// Returns the train service alerts, or nothing if there is not currently a disruption.
    public func getMRTAlerts() async throws -> LTATrainAlertValue? {
        // 1 minute expiry
        if let cached: LTATrainAlertsResponse = memoryCache.read(category: "mrtAlerts", key: "all", expiry: 60) {
            return cached.value
        }
        let response = try await client.trainServiceAlerts()
        if let response {
            memoryCache.write(category: "mrtAlerts", key: "all", data: response)
        }
        return response?.value
    }

    /// Returns the crowdedness for every stop in a given MRT line
    public func getMRTLineCrowd(line: TrainLine) async throws -> [LTAPCDRealTimeItem]? {
        // 10 minute expiry
        if let cached: LTAPCDRealTimeResponse = memoryCache.read(category: "mrtCrowd", key: line.lineAcronym) {
            return cached.value
        }
        let response = try await client.trainStationCrowdDensity(trainLine: line.lineAcronym)
        guard let response else { return nil }
        memoryCache.write(category: "mrtCrowd", key: line.lineAcronym, data: response)
        return response.value
    }

    /// Returns the crowdedness for every MRT line for a given MRT stop. Returns an empty dictionary
    /// if certain line estimates could not be found.
    public func getMRTLineCrowd(stop: LTATrainStopInfo) async throws -> [TrainLine: LTAPCDRealTimeItem] {
        let stopCodes = stop.mrtStopCode.split(separator: "/")
        var result: [TrainLine: LTAPCDRealTimeItem] = [:]
        for code in stopCodes {
            let lineCode = code[code.startIndex..<code.index(code.startIndex, offsetBy: 2)]
            guard let line = TrainLine(String(lineCode)),
                  let lineCrowd = try await getMRTLineCrowd(line: line),
                  let thisStopLineCrowd = lineCrowd.first(where: { code == ($0.station ?? "N/A") })
            else { continue }
            result[line] = thisStopLineCrowd
        }
        return result
    }

    // MARK: Saving bulk data to cache

    /// Saves an external bulk list of MRT stops to the cache
    public func saveMRTStopsToCache(_ stops: [LTATrainStopInfo]) {
        for stopInfo in stops {
            diskCache.write(category: "stops", key: stopInfo.mrtStopCode, data: stopInfo)
        }
    }
    /// Saves an external bulk list of MRT stops to the cache
    public func saveMRTRoutesToCache(_ routes: [LTATrainRoutes]) {
        for routeInfo in routes {
            diskCache.write(category: "routes", key: routeInfo.code, data: routeInfo)
        }
    }

    /// Saves an external bulk list of bus stops to the cache
    public func saveBusStopsToCache(_ stops: [LTABusStopInfo]) {
        for stopInfo in stops {
            diskCache.write(category: "stops", key: stopInfo.busStopCode, data: stopInfo)
        }
    }

    /// Saves an external bulk list of bus routes to the cache
    public func saveBulkRoutesToCache(_ routes: [LTABusRouteRow]) {
        var byService: [String: [LTABusRouteRow]] = [:]
        for row in routes {
            byService[row.serviceNo, default: []].append(row)
        }
        for (svc, rows) in byService {
            diskCache.write(category: "routes", key: svc, data: rows)
        }
    }
}
