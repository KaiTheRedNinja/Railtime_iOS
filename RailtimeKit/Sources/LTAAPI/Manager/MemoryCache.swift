//
//  MemoryCache.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 19/9/26.
//

import Foundation

/// Simple per-key cache that simply stores artefacts in memory. Intended for live data and stores it for its valid range
public final class MemoryCache {
    /// On-disk envelope wrapping cached `data` with the time it was fetched,
    /// mirroring the Python cache file's `{"fetched_at": ..., "data": ...}`
    /// shape.
    private struct CachePayload {
        /// When this payload was written to disk.
        let fetchedAt: Date
        /// The cached value itself.
        let data: Any
    }

    /// How long a cached payload remains valid before it's treated as stale.
    public let ttl: TimeInterval

    /// The cache
    private var cache: [String: [String: CachePayload]]

    /// Creates a cache rooted at `root`, with entries expiring after `ttl`
    /// seconds.
    ///
    /// - Parameters:
    ///   - root: The directory cache files are stored under. Created lazily
    ///     as categories are written.
    ///   - ttl: How long, in seconds, a cached payload remains valid.
    public init(ttl: TimeInterval) {
        self.ttl = ttl
        self.cache = [:]
    }

    /// Returns the keys in a category, or `nil` if the category does not exist.
    public func keys(inCategory category: String) -> [String]? {
        if let keys = cache[category]?.keys {
            return Array(keys)
        }
        return nil
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
    public func read<T>(category: String, key: String, as type: T.Type = T.self, expiry: TimeInterval? = nil) -> T? {
        guard let payload = cache[category]?[key],
              Date().timeIntervalSince(payload.fetchedAt) > expiry ?? ttl
        else { return nil }
        return payload.data as? T
    }

    /// Writes `data` to the cache under `category`/`key`, stamped with the
    /// current time.
    ///
    /// - Parameters:
    ///   - category: The cache category (e.g. "routes", "services", "stops").
    ///   - key: The cache key within that category.
    ///   - data: The `Encodable` value to persist.
    public func write(category: String, key: String, data: Any) {
        cache[category, default: [:]][key] = .init(fetchedAt: Date(), data: data)
    }
}
