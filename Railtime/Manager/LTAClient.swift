import Foundation

// --------------------------------------------------------------------------
// Low-level API client
// --------------------------------------------------------------------------

/// Errors thrown by ``LTAClient``.
enum LTAClientError: Error {
    /// No AccountKey was supplied to the initializer and none was found in
    /// the `LTA_ACCOUNT_KEY` environment variable.
    case missingAccountKey
    /// The HTTP response's status code was outside the 200..<300 range.
    case httpError(statusCode: Int, body: String)
    /// The response body could not be decoded into the expected shape.
    case decodingError(underlying: Error)
}

/// Low-level client for the LTA DataMall API.
final class LTAClient {
    /// The LTA DataMall AccountKey used to authenticate every request.
    let accountKey: String
    /// The URLSession used to issue HTTP requests.
    let session: URLSession

    /// Creates a client using the given AccountKey, or falling back to the
    /// `LTA_ACCOUNT_KEY` environment variable.
    ///
    /// - Parameters:
    ///   - accountKey: An explicit AccountKey to use. If `nil`, the
    ///     `LTA_ACCOUNT_KEY` environment variable is used instead.
    ///   - session: The `URLSession` to issue requests with. Defaults to
    ///     `.shared`.
    /// - Throws: ``LTAClientError/missingAccountKey`` if no AccountKey is
    ///   available from either source.
    init(accountKey: String? = nil, session: URLSession = .shared) throws {
        let resolvedKey = accountKey ?? ProcessInfo.processInfo.environment["LTA_ACCOUNT_KEY"]
        guard let resolvedKey, !resolvedKey.isEmpty else {
            throw LTAClientError.missingAccountKey
        }
        self.accountKey = resolvedKey
        self.session = session
    }

    /// Issues a single GET request against `{BASE_URL}/{path}` and decodes
    /// the JSON response as `T`.
    ///
    /// - Parameters:
    ///   - path: The endpoint path, relative to `BASE_URL`.
    ///   - params: Query parameters to attach to the request.
    /// - Returns: The decoded response body.
    /// - Throws: ``LTAClientError`` on network, HTTP, or decoding failure.
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
    ///
    /// - Parameters:
    ///   - path: The endpoint path, relative to `BASE_URL`.
    ///   - params: Query parameters to attach to every page's request.
    /// - Returns: The concatenation of every page's `value` array.
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

    /// Fetches live arrival information for a stop, optionally filtered to
    /// a single service.
    ///
    /// - Parameters:
    ///   - busStopCode: The bus stop code to query.
    ///   - serviceNo: If provided, restricts the response to this service.
    /// - Returns: The decoded BusArrival response.
    func busArrival(busStopCode: String, serviceNo: String? = nil) async throws -> BusArrivalResponse {
        var params = ["BusStopCode": busStopCode]
        if let serviceNo {
            params["ServiceNo"] = serviceNo
        }
        print("Getting bus arrival data for stop", busStopCode, "and service", serviceNo as Any)
        return try await get(path: "v3/BusArrival", params: params)
    }

    // ---- 2.2 Bus Services --------------------------------------------------

    /// Fetches static BusServices rows, optionally filtered to a single
    /// service.
    ///
    /// - Parameter serviceNo: If provided, restricts the response to this
    ///   service.
    /// - Returns: Every matching BusServices row, across all pages.
    func busServices(serviceNo: String? = nil) async throws -> [BusServiceInfo] {
        let params: [String: String] = serviceNo.map { ["ServiceNo": $0] } ?? [:]
        print("Getting bus service data for service", serviceNo as Any)
        return try await getAllPages(path: "BusServices", params: params)
    }

    // ---- 2.3 Bus Routes ----------------------------------------------------

    /// Fetches every BusRoutes row for the entire network.
    ///
    /// BusRoutes has no filter param in the API; pull everything and filter
    /// client-side (a real deployment should cache this, since Update Freq
    /// is "Ad hoc").
    ///
    /// - Returns: Every BusRoutes row, across all pages.
    func busRoutes() async throws -> [BusRouteRow] {
        print("Getting all bus routes (this will take a while)")
        return try await getAllPages(path: "BusRoutes")
    }

    // ---- 2.4 Bus Stops -------------------------------------------------

    /// Fetches static information about a single bus stop.
    ///
    /// - Parameter busStopCode: The bus stop code to look up.
    /// - Returns: The matching BusStops row, or `nil` if none was found.
    func busStop(busStopCode: String) async throws -> BusStopInfo? {
        print("Getting bus stop info for code", busStopCode)
        let results: [BusStopInfo] = try await getAllPages(path: "BusStops", params: ["BusStopCode": busStopCode])
        return results.first
    }
}
