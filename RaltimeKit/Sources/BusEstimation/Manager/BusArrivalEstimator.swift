import Foundation
import LTAAPI

// --------------------------------------------------------------------------
// Core estimator
// --------------------------------------------------------------------------

// This class has a lot of functionality, and is therefore split into several files:
// - BusArrivalEstimator (this file):   Properties and initialiser
// - BusArrivalEstimator+estimate:      The main function, `estimate`
// - BusArrivalEstimator+data:          Retrieves data from the cache/API
// - BusArrivalEstimator+align:         Aligns the bus estimations of different bus stops
// - BusArrivalEstimator+extrapolate:   Extrapolates future bus timings using frequency information
public final class BusArrivalEstimator {
    /// The underlying API client. This should never be called directly - use `data` instead.
    public let client: LTAClient
    /// The reference "current time" estimates are computed relative to.
    public var now: Date
    /// The cached data source wrapping `client`'s non-live endpoints.
    public let data: CachedDataSource

    /// Creates an estimator.
    ///
    /// - Parameters:
    ///   - client: The LTA API client to use.
    ///   - now: The reference time to use as "now". Defaults to the current
    ///     time.
    ///   - cacheDir: Directory for the on-disk non-live data cache.
    ///   - cacheTTLHours: How long, in hours, cached non-live data stays
    ///     valid.
    public init(
        client: LTAClient,
        now: Date? = nil,
        cacheDir: String = "lta_cache",
        cacheTTLHours: Double = 24.0 * 30 // 30 days
    ) {
        self.client = client
        self.now = now ?? .now
        self.data = CachedDataSource(client: client, cache: DiskCache(root: cacheDir, ttl: cacheTTLHours * 3600))
    }
}

/// Errors thrown by ``BusArrivalEstimator``.
public enum BusArrivalEstimatorError: Error {
    /// No BusRoutes data exists at all for the requested service.
    case noRouteData(serviceNo: String)
    /// The requested stop isn't on any direction of the requested service.
    case stopNotFound(stopCode: String, serviceNo: String)
}
