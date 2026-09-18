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
    public let cache: DiskCache
    /// In-memory cache for the current run, keyed by (bus stop code, service
    /// number).
    private var shortTermCache: [ShortTermCacheKey: (fetchedAt: Date, data: LTABusArrivalResponse)] = [:]

    /// Creates a cached data source wrapping `client`, using `cache` for
    /// its on-disk non-live cache.
    public init(client: LTAClient, cache: DiskCache) {
        self.client = client
        self.cache = cache
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
        let cacheKey = ShortTermCacheKey(busStopCode: busStopCode, serviceNo: serviceNo)
        if let cached = shortTermCache[cacheKey], Date().timeIntervalSince(cached.fetchedAt) < 5 {
            return cached.data
        }

        let data = try await client.busArrival(busStopCode: busStopCode, serviceNo: serviceNo)
        shortTermCache[cacheKey] = (Date(), data)
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
        if let cached: [LTABusRouteRow] = cache.read(category: "routes", key: serviceNo) {
            return cached
        }

        let allRows = try await client.busRoutes()
        var byService: [String: [LTABusRouteRow]] = [:]
        for row in allRows {
            byService[row.serviceNo, default: []].append(row)
        }
        for (svc, rows) in byService {
            cache.write(category: "routes", key: svc, data: rows)
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
        if let cached: [LTABusServiceInfo] = cache.read(category: "services", key: serviceNo) {
            return cached.first
        }
        let rows = try await client.busServices(serviceNo: serviceNo)
        cache.write(category: "services", key: serviceNo, data: rows)
        return rows.first
    }

    /// Returns static BusStops information for `busStopCode`, using the
    /// on-disk cache when possible.
    ///
    /// - Parameter busStopCode: The bus stop code to look up.
    /// - Returns: The stop's info, or `nil` if the stop doesn't exist.
    public func getStopInfo(busStopCode: String) async throws -> LTABusStopInfo? {
        print("Getting stop info for", busStopCode)
        if let cached: LTABusStopInfo = cache.read(category: "stops", key: busStopCode) {
            return cached
        }
        let info = try await client.busStop(busStopCode: busStopCode)
        if let info {
            cache.write(category: "stops", key: busStopCode, data: info)
        }
        return info
    }

    /// Get the MRT stop and schedule information
    public func getMrtSchedleInfo() async throws {
        let destinationURL = cache.root
            .appending(path: "mrt/gtfs")

        if FileManager.default.fileExists(atPath: destinationURL.path()) {
            // use that instead
            print("File already exists!")
        } else {
            guard let url = try await client.mrtSchedule() else {
                print("Could not get MRT URL!")
                return
            }
            // download and move
            let (tempURL, response) = try await URLSession.shared.download(from: url)
            let downloadLocation = FileManager.default.temporaryDirectory
                .appendingPathComponent("gtfs_archive.zip")
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            if FileManager.default.fileExists(atPath: downloadLocation.path) {
                try FileManager.default.removeItem(at: downloadLocation)
            }
            try FileManager.default.moveItem(at: tempURL, to: downloadLocation)

            // unzip
            try FileManager.default.createDirectory(
                at: destinationURL,
                withIntermediateDirectories: true
            )

            try FileManager.default.unzipItem(
                at: downloadLocation,
                to: destinationURL
            )
        }
    }
}
