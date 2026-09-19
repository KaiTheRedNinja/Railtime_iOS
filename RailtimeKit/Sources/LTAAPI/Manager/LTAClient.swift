import Foundation
import ZIPFoundation

// --------------------------------------------------------------------------
// Low-level API client
// --------------------------------------------------------------------------

/// Errors thrown by ``LTAClient``.
public enum LTAClientError: Error {
    /// No AccountKey was supplied to the initializer and none was found in
    /// the `LTA_ACCOUNT_KEY` environment variable.
    case missingAccountKey
    /// The HTTP response's status code was outside the 200..<300 range.
    case httpError(statusCode: Int, body: String)
    /// The response body could not be decoded into the expected shape.
    case decodingError(underlying: Error)
}

/// Low-level client for the LTA DataMall API.
public final class LTAClient {
    /// The actor responsible for rate limiting API requests. Maximum RPS is 40, we use 20 as a safety margin.
    private let rateLimiter = RateLimiter(requestsPerSecond: 20)

    /// The LTA DataMall AccountKey used to authenticate every request.
    public let accountKey: String
    /// The URLSession used to issue HTTP requests.
    public let session: URLSession

    /// Creates a client using the given AccountKey, or falling back to
    /// UserDefaults ("LTA_ACCOUNT_KEY" / "LTA_API_KEY"), environment variable, or Info.plist.
    ///
    /// - Parameters:
    ///   - accountKey: An explicit AccountKey to use. If `nil`, standard storage/env keys are checked.
    ///   - session: The `URLSession` to issue requests with. Defaults to `.shared`.
    /// - Throws: ``LTAClientError/missingAccountKey`` if no AccountKey is available from any source.
    public init(accountKey: String? = nil, session: URLSession = .shared) throws {
        let savedKey: String? = {
            if let k = UserDefaults.standard.string(forKey: "LTA_ACCOUNT_KEY"), !k.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return k
            }
            if let k = UserDefaults.standard.string(forKey: "LTA_API_KEY"), !k.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return k
            }
            return nil
        }()

        let resolvedKey = accountKey ??
            savedKey ??
            ProcessInfo.processInfo.environment["LTA_ACCOUNT_KEY"] ??
            Bundle.main.object(forInfoDictionaryKey: "LTA_ACCOUNT_KEY") as? String ??
            "19hQsIO6RjOhqlAVh4DRKw=="
        
        guard !resolvedKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LTAClientError.missingAccountKey
        }
        self.accountKey = resolvedKey
        self.session = session
    }

    /// Issues a single GET request against `{BASE_URL}/{path}` and decodes
    /// the JSON response as `T`.
    private func get<T: Decodable>(path: String, params: [String: String] = [:]) async throws -> T {
        var components = URLComponents(string: "\(BASE_URL)/\(path)")!
        if !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        let url = components.url!
        print("Getting at path", "\(BASE_URL)/\(path)", "with params", params)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(accountKey, forHTTPHeaderField: "AccountKey")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.timeoutInterval = 15

        // ensure we are not rate limited by waiting as required
        await rateLimiter.acquire()

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LTAClientError.httpError(statusCode: -1, body: "")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw LTAClientError.httpError(
                statusCode: httpResponse.statusCode,
                body: String(data: data, encoding: .utf8) ?? ""
            )
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw LTAClientError.decodingError(underlying: error)
        }
    }

    /// Some endpoints (BusRoutes, BusServices, BusStops) paginate at 500
    /// records via `$skip`. Keep pulling pages until we get a short page.
    private func getAllPages<Value: Decodable>(path: String, params: [String: String] = [:]) async throws -> [Value] {
        var params = params
        var skip = 0
        var out: [Value] = []
        while true {
            params["$skip"] = String(skip)
            print("Attempting to get page starting at skip", skip)
            let data: LTAPagedResponse<Value> = try await get(path: path, params: params)
            out.append(contentsOf: data.value)
            if data.value.count < PAGE_SIZE {
                break
            }
            skip += PAGE_SIZE
        }
        return out
    }

    // ---- 2.1 Bus Arrival -------------------------------------------------

    public func busArrival(busStopCode: String, serviceNo: String? = nil) async throws -> LTABusArrivalResponse {
        var params = ["BusStopCode": busStopCode]
        if let serviceNo {
            params["ServiceNo"] = serviceNo
        }
        print("Getting bus arrival data for stop", busStopCode, "and service", serviceNo as Any)
        return try await get(path: "v3/BusArrival", params: params)
    }

    // ---- 2.2 Bus Services --------------------------------------------------

    public func busServices(serviceNo: String? = nil) async throws -> [LTABusServiceInfo] {
        let params: [String: String] = serviceNo.map { ["ServiceNo": $0] } ?? [:]
        print("Getting bus service data for service", serviceNo as Any)
        return try await getAllPages(path: "BusServices", params: params)
    }

    // ---- 2.3 Bus Routes ----------------------------------------------------

    public func busRoutes() async throws -> [LTABusRouteRow] {
        print("Getting all bus routes (this will take a while)")
        return try await getAllPages(path: "BusRoutes")
    }

    // ---- 2.4 Bus Stops -------------------------------------------------

    public func busStop(busStopCode: String) async throws -> LTABusStopInfo? {
        print("Getting bus stop info for code", busStopCode)
        let results: [LTABusStopInfo] = try await getAllPages(path: "BusStops", params: ["BusStopCode": busStopCode])
        return results.first
    }

    // ---- 2.11 Train service alerts ------------------------------------------

    public func trainServiceAlerts() async throws -> LTATrainAlertsResponse? {
        let results: LTATrainAlertsResponse? = try await get(path: "TrainServiceAlerts")
        return results
    }

    // ---- 2.24 Station crowd density (realtime) --------------------------------------------

    public func trainStationCrowdDensity(trainLine: String) async throws -> LTAPCDRealTimeResponse? {
        print("Getting crowd density for train line \(trainLine)")
        let results: LTAPCDRealTimeResponse? = try await get(path: "PCDRealTime", params: ["TrainLine": trainLine])
        return results
    }
}
