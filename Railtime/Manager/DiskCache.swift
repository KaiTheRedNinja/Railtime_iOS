import Foundation

// --------------------------------------------------------------------------
// Disk cache for non-live data (BusRoutes / BusServices / BusStops)
// --------------------------------------------------------------------------

/// Replaces every run of characters outside `[A-Za-z0-9_-]` with a single
/// underscore, mirroring the Python module's `_SAFE_KEY_RE` regex, so cache
/// keys are always safe to use as file names.
///
/// - Parameter key: The raw cache key.
/// - Returns: A filesystem-safe version of `key`, or `"default"` if `key`
///   sanitizes down to nothing.
private func sanitizedCacheKey(_ key: String) -> String {
    let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")
    var result = ""
    var lastCharWasReplaced = false
    for scalar in key.unicodeScalars {
        if allowed.contains(scalar) {
            result.unicodeScalars.append(scalar)
            lastCharWasReplaced = false
        } else if !lastCharWasReplaced {
            result.append("_")
            lastCharWasReplaced = true
        }
    }
    return result.isEmpty ? "default" : result
}

/// Simple per-key JSON file cache with a TTL.
///
/// Deliberately never touches BusArrival (2.1) — that endpoint is live and
/// updates every 20 seconds, so caching it would return stale ETAs.
/// BusRoutes/BusServices/BusStops update "Ad hoc" per the API guide, so a
/// TTL-based disk cache is a safe way to cut down repeat API calls.
final class DiskCache {
    /// On-disk envelope wrapping cached `data` with the time it was fetched,
    /// mirroring the Python cache file's `{"fetched_at": ..., "data": ...}`
    /// shape.
    private struct CachePayload<T: Codable>: Codable {
        /// When this payload was written to disk.
        let fetchedAt: Date
        /// The cached value itself.
        let data: T

        enum CodingKeys: String, CodingKey {
            case fetchedAt = "fetched_at"
            case data
        }
    }

    /// The directory cache files are stored under.
    let root: URL
    /// How long a cached payload remains valid before it's treated as stale.
    let ttl: TimeInterval

    /// Creates a cache rooted at `root`, with entries expiring after `ttl`
    /// seconds.
    ///
    /// - Parameters:
    ///   - root: The directory cache files are stored under. Created lazily
    ///     as categories are written.
    ///   - ttl: How long, in seconds, a cached payload remains valid.
    init(root: String, ttl: TimeInterval) {
        self.root = URL(fileURLWithPath: root)
        self.ttl = ttl
    }

    /// Computes the on-disk path for a given category/key pair, creating the
    /// category directory if needed.
    private func path(category: String, key: String) -> URL {
        let safeKey = sanitizedCacheKey(key)
        let directory = root.appendingPathComponent(category, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("\(safeKey).json")
    }

    /// Returns the cached payload for `category`/`key`, or `nil` if
    /// missing/stale/corrupt.
    ///
    /// - Parameters:
    ///   - category: The cache category (e.g. "routes", "services", "stops").
    ///   - key: The cache key within that category.
    ///   - type: The `Decodable` type to decode the cached payload as.
    /// - Returns: The decoded value, or `nil` if the entry is missing,
    ///   older than `ttl`, or fails to decode.
    func read<T: Codable>(category: String, key: String, as type: T.Type = T.self) -> T? {
        let filePath = path(category: category, key: key)
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            return nil
        }
        guard let fileData = try? Data(contentsOf: filePath) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let payload = try? decoder.decode(CachePayload<T>.self, from: fileData) else {
            return nil
        }
        if Date().timeIntervalSince(payload.fetchedAt) > ttl {
            return nil
        }
        return payload.data
    }

    /// Writes `data` to the cache under `category`/`key`, stamped with the
    /// current time.
    ///
    /// - Parameters:
    ///   - category: The cache category (e.g. "routes", "services", "stops").
    ///   - key: The cache key within that category.
    ///   - data: The `Encodable` value to persist.
    func write<T: Codable>(category: String, key: String, data: T) {
        let filePath = path(category: category, key: key)
        let payload = CachePayload(fetchedAt: Date(), data: data)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        guard let encoded = try? encoder.encode(payload) else {
            return
        }
        try? encoded.write(to: filePath)
    }
}

/// Wraps LTAClient's non-live endpoints with disk caching.
///
/// Route data is cached one file per service (routes/<ServiceNo>.json) so
/// the cache directory stays human-manageable instead of one giant blob
/// for the whole bus network — even though the underlying BusRoutes API
/// itself has no server-side filter and must be pulled in full on a cache
/// miss. That one full pull is used to (re)populate the per-service files
/// for *every* service seen, not just the one requested, so subsequent
/// lookups for other services are usually cache hits too.
final class CachedDataSource {
    /// Key identifying a single in-memory short-term cache entry for a live
    /// BusArrival lookup.
    private struct ShortTermCacheKey: Hashable {
        /// The bus stop code that was queried.
        let busStopCode: String
        /// The service number filter that was applied, if any.
        let serviceNo: String?
    }

    /// The underlying API client.
    let client: LTAClient
    /// The on-disk cache for non-live (BusRoutes/BusServices/BusStops) data.
    let cache: DiskCache
    /// In-memory cache for the current run, keyed by (bus stop code, service
    /// number).
    private var shortTermCache: [ShortTermCacheKey: (fetchedAt: Date, data: LTABusArrivalResponse)] = [:]

    /// Creates a cached data source wrapping `client`, using `cache` for
    /// its on-disk non-live cache.
    init(client: LTAClient, cache: DiskCache) {
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
    func getBusArrival(busStopCode: String, serviceNo: String? = nil) async throws -> LTABusArrivalResponse {
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
    func getServiceRoutes(serviceNo: String) async throws -> [LTABusRouteRow] {
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
    func getServiceInfo(serviceNo: String) async throws -> LTABusServiceInfo? {
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
    func getStopInfo(busStopCode: String) async throws -> LTABusStopInfo? {
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
}
