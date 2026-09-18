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
public final class DiskCache {
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
    public let root: URL
    /// How long a cached payload remains valid before it's treated as stale.
    public let ttl: TimeInterval

    /// Creates a cache rooted at `root`, with entries expiring after `ttl`
    /// seconds.
    ///
    /// - Parameters:
    ///   - root: The directory cache files are stored under. Created lazily
    ///     as categories are written.
    ///   - ttl: How long, in seconds, a cached payload remains valid.
    public init(root: String, ttl: TimeInterval) {
        self.root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appending(path: root)
        self.ttl = ttl
    }

    /// Computes the on-disk path for a given category/key pair, creating the
    /// category directory if needed.
    func path(category: String, key: String) -> URL {
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
    public func read<T: Codable>(category: String, key: String, as type: T.Type = T.self) -> T? {
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
    public func write<T: Codable>(category: String, key: String, data: T) {
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
