import Foundation
import CoreLocation
import Observation
import LTAAPI
import BusEstimation

// MARK: - LTA Service

@Observable
class LTAService {
    var dataSource: LTADataSource { estimator.data }
    var estimator: BusArrivalEstimator

    var allBusStops: [BusStop] = [] {
        didSet {
            rebuildBusStopsById()
        }
    }
    private(set) var spatialIndex: BusStopSpatialIndex = .init(stops: [])
    var allStations: [Station] = [] {
        didSet {
            sortedStationsByLength = allStations.sorted { $0.name.count > $1.name.count }

            allStationsById = .init(uniqueKeysWithValues: allStations.map { ($0.id, $0) })
        }
    }
    private(set) var allStationsById: [Station.ID: Station] = [:]
    var allMRTRoutes: [LTATrainRoutes] = []

    private(set) var busStopsById: [String: BusStop] = [:]
    private(set) var sortedStationsByLength: [Station] = []

    var trainServiceAlert: String? = nil
    var isTrainStatusNormal: Bool = true
    var isLoadingStops: Bool = false
    
    init() {
        let apiKey = (
            UserDefaults.standard.string(forKey: "LTA_ACCOUNT_KEY")
            ?? UserDefaults.standard.string(forKey: "LTA_API_KEY")
            ?? ProcessInfo.processInfo.environment["LTA_ACCOUNT_KEY"]
            ?? "19hQsIO6RjOhqlAVh4DRKw=="
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        estimator = .init(
            client: try! LTAClient(accountKey: apiKey),
            cacheDir: "lta_cache",
            cacheTTLHours: 24.0 * 30
        )

        loadPreseededData()
    }
    
    private func rebuildBusStopsById() {
        var dict: [String: BusStop] = [:]
        dict.reserveCapacity(allBusStops.count)
        for stop in allBusStops {
            dict[stop.id] = stop
        }
        self.busStopsById = dict

        spatialIndex = BusStopSpatialIndex(stops: allBusStops, indexCellSize: 0.01)
    }
    
    // MARK: - Fetch Station Platform Crowd Levels
    
    func fetchStationCrowdLevels(for station: Station) async -> [StationLineCrowd] {
        let results = try? await dataSource.getMRTLineCrowd(stopCodes: station.id)

        return results?.compactMap { (line, result) in
            guard let station = result.station, let crowdLevel = result.crowdLevel else { return nil }
            return StationLineCrowd(
                lineCode: line.stationCodePrefix,
                stationCode: station,
                crowdLevel: .init(rawValue: crowdLevel) ?? .unknown
            )
        } ?? []
    }
    
    // MARK: - Fetch Bus Route Data
    func fetchBusRoute(for serviceNo: String) async -> BusServiceRoute? {
        guard let results = try? await dataSource.getServiceRoutes(serviceNo: serviceNo) else { return nil }

        let stops = results.map { item -> BusRouteStop in
            let stop = self.busStopsById[item.busStopCode]
            let station = self.findNearbyStation(for: stop, code: item.busStopCode)
            return BusRouteStop(stopInfo: item, busStop: stop, nearbyStation: station)
        }

        let dir1Stops = stops.filter { $0.direction == 1 }.sorted { $0.stopSequence < $1.stopSequence }
        let dir2Stops = stops.filter { $0.direction == 2 }.sorted { $0.stopSequence < $1.stopSequence }

        return BusServiceRoute(
            serviceNo: serviceNo,
            operatorName: results.first!.operator,
            direction1Stops: dir1Stops,
            direction2Stops: dir2Stops
        )
    }

    // MARK: - Station Matching Logic
    
    func findNearbyStation(for busStop: BusStop?, code: String) -> Station? {
        guard let stop = busStop ?? busStopsById[code] else {
            return nil
        }
        
        let stopNameLower = stop.name.lowercased()
        let isStationOrTransitStop = stopNameLower.contains("stn") ||
                                     stopNameLower.contains("mrt") ||
                                     stopNameLower.contains("lrt") ||
                                     stopNameLower.contains("exit") ||
                                     stopNameLower.contains("station") ||
                                     stopNameLower.contains("int") ||
                                     stopNameLower.contains("interchange") ||
                                     stopNameLower.contains("ter") ||
                                     stopNameLower.contains("terminal")
        
        // 1. Direct Name Matching in bus stop description (using pre-sorted stations by length)
        if isStationOrTransitStop {
            for station in sortedStationsByLength {
                let stnNameLower = station.name.lowercased()
                if stopNameLower.contains(stnNameLower) {
                    return station
                }
            }
        }
        
        // 2. Spatial Distance Matching (Closest station within 280 meters)
        let stopLoc = CLLocation(latitude: stop.coordinate.latitude, longitude: stop.coordinate.longitude)
        var closestStation: Station? = nil
        var minDistance: CLLocationDistance = .infinity
        
        for station in allStations {
            let stnLoc = CLLocation(latitude: station.coordinate.latitude, longitude: station.coordinate.longitude)
            let dist = stopLoc.distance(from: stnLoc)
            if dist < minDistance {
                minDistance = dist
                closestStation = station
            }
        }
        
        if minDistance <= 280, let closest = closestStation {
            return closest
        }
        
        return nil
    }
    
    // MARK: - Fetch Live Bus Stops Dataset
    
    func fetchLiveBusStops() async {
        guard !isLoadingStops else { return }
        isLoadingStops = true
        defer { isLoadingStops = false }

        guard let allStops = dataSource.getAllStopIDs() else { return }
        var fetchedStops: [BusStop] = []

        for stopCode in allStops {
            guard let stop = try? await dataSource.getStopInfo(busStopCode: stopCode) else { continue }
            fetchedStops.append(stop)
        }
        if !fetchedStops.isEmpty {
            await MainActor.run {
                self.allBusStops = fetchedStops
            }
        }
    }
    
    // MARK: - Fetch Train Service Alerts
    
    func fetchTrainServiceAlerts() async {
        guard let alerts = try? await dataSource.getMRTAlerts() else { return }

        let status = alerts.status ?? 1
        let firstContent = alerts.message?.first?.content

        await MainActor.run {
            self.isTrainStatusNormal = (status == 1)
            self.trainServiceAlert = (firstContent?.isEmpty == false) ? firstContent : nil
        }
    }
    
    // MARK: - Local Station Data (Loaded from stations.json / Fallback)

    private func loadPreseededData() {
        func load<T: Codable>(_: T.Type, fileName: String, ext: String = "json") -> T? {
            if let url = Bundle.main.url(forResource: fileName, withExtension: ext) {
                do {
                    let data = try Data(contentsOf: url)
                    let decoded = try JSONDecoder().decode(T.self, from: data)
                    print("Successfully loaded from \(fileName).\(ext)")
                    return decoded
                } catch {
                    print("Error decoding \(fileName).\(ext) from bundle url: \(error)")
                }
            }
            return nil
        }

        struct MRTRoutesContents: Codable {
            var routes: [String: LTATrainRoutes]
        }

        self.allStations = load([Station].self, fileName: "stations") ?? []
        if let values = load(MRTRoutesContents.self, fileName: "mrt_routes")?.routes.values {
            self.allMRTRoutes = Array(values)
        }
        self.allBusStops = load([LTABusStopInfo].self, fileName: "bus_stops") ?? []

        // load the stations into cache
        dataSource.saveMRTStopsToCache(allStations)
        dataSource.saveBusStopsToCache(allBusStops)
        dataSource.saveMRTRoutesToCache(allMRTRoutes)
        Task {
            let startDate = Date.now
            do {
                try await dataSource.calculateAllServices()
                print("Calculated all services for bus stops in \(Date.now.timeIntervalSince(startDate))s")
            } catch {
                print("Error calculating all services from cache: \(error), took \(Date.now.timeIntervalSince(startDate))s")
            }
        }
    }
}

// MARK: - Spatial Index

final class BusStopSpatialIndex {
    private struct GridKey: Hashable {
        let x: Int
        let y: Int
    }

    // The index grid should be relatively fine.
    // This is independent from display precision.
    private let indexCellSize: Double

    private var buckets: [GridKey: [BusStop]] = [:]

    init(
        stops: [BusStop],
        indexCellSize: Double = 0.005
    ) {
        self.indexCellSize = indexCellSize

        buckets.reserveCapacity(stops.count)

        for stop in stops {
            let key = indexKey(for: stop.coordinate)
            buckets[key, default: []].append(stop)
        }
    }

    // MARK: - Basic Query

    /// Returns every bus stop inside the visible region.
    func stops(
        around center: CLLocationCoordinate2D,
        visibleDelta: Double
    ) -> [BusStop] {

        return stops(
            minLatitude: center.latitude - visibleDelta,
            maxLatitude: center.latitude + visibleDelta,
            minLongitude: center.longitude - visibleDelta,
            maxLongitude: center.longitude + visibleDelta
        )
    }

    // MARK: - Precision Query

    /// Returns a representative subset of bus stops.
    ///
    /// `precision` controls how close two returned stops are allowed
    /// to be in latitude/longitude space.
    ///
    /// Larger precision = fewer annotations.
    ///
    /// For example:
    ///
    /// precision = 0.001° ≈ 110m latitude
    /// precision = 0.002° ≈ 220m latitude
    /// precision = 0.005° ≈ 550m latitude
    ///
    func stops(
        around center: CLLocationCoordinate2D,
        visibleDelta: Double,
        precision: Double
    ) -> [BusStop] {

        guard precision > 0 else {
            return stops(
                around: center,
                visibleDelta: visibleDelta
            )
        }

        let minLatitude = center.latitude - visibleDelta
        let maxLatitude = center.latitude + visibleDelta
        let minLongitude = center.longitude - visibleDelta
        let maxLongitude = center.longitude + visibleDelta

        return stops(
            minLatitude: minLatitude,
            maxLatitude: maxLatitude,
            minLongitude: minLongitude,
            maxLongitude: maxLongitude,
            precision: precision
        )
    }

    // MARK: - Internal Queries

    private func stops(
        minLatitude: Double,
        maxLatitude: Double,
        minLongitude: Double,
        maxLongitude: Double
    ) -> [BusStop] {

        let minX = Int(floor(minLongitude / indexCellSize))
        let maxX = Int(floor(maxLongitude / indexCellSize))

        let minY = Int(floor(minLatitude / indexCellSize))
        let maxY = Int(floor(maxLatitude / indexCellSize))

        var result: [BusStop] = []

        for x in minX...maxX {
            for y in minY...maxY {

                let key = GridKey(x: x, y: y)

                guard let bucket = buckets[key] else {
                    continue
                }

                for stop in bucket {
                    let lat = stop.coordinate.latitude
                    let lon = stop.coordinate.longitude

                    if lat >= minLatitude &&
                        lat <= maxLatitude &&
                        lon >= minLongitude &&
                        lon <= maxLongitude {

                        result.append(stop)
                    }
                }
            }
        }

        return result
    }

    private func stops(
        minLatitude: Double,
        maxLatitude: Double,
        minLongitude: Double,
        maxLongitude: Double,
        precision: Double
    ) -> [BusStop] {
        var start = Date()

        // This is the important part.
        //
        // The precision grid is separate from the index grid.
        //
        // Multiple index cells can therefore map into the same
        // precision cell.

        let minX = Int(floor(minLongitude / indexCellSize))
        let maxX = Int(floor(maxLongitude / indexCellSize))

        let minY = Int(floor(minLatitude / indexCellSize))
        let maxY = Int(floor(maxLatitude / indexCellSize))

        var representatives: [GridKey: BusStop] = [:]

        for x in minX...maxX {
            for y in minY...maxY {

                let key = GridKey(x: x, y: y)

                guard let bucket = buckets[key] else {
                    continue
                }

                for stop in bucket {

                    let lat = stop.coordinate.latitude
                    let lon = stop.coordinate.longitude

                    guard lat >= minLatitude,
                          lat <= maxLatitude,
                          lon >= minLongitude,
                          lon <= maxLongitude
                            else {
                        continue
                    }

                    // Map the coordinate into a coarser
                    // precision grid.
                    let precisionX = Int(floor(lon / precision))
                    let precisionY = Int(floor(lat / precision))

                    let precisionKey = GridKey(
                        x: precisionX,
                        y: precisionY
                    )

                    // We already have a representative for this
                    // precision cell, so skip this stop.
                    if representatives[precisionKey] != nil {
                        continue
                    }

                    representatives[precisionKey] = stop
                }
            }
        }

        print("Found \(representatives.values.count) stops in \(Date.now.timeIntervalSince(start)) seconds")

        return Array(representatives.values)
    }

    // MARK: - Index

    private func indexKey(
        for coordinate: CLLocationCoordinate2D
    ) -> GridKey {

        GridKey(
            x: Int(floor(coordinate.longitude / indexCellSize)),
            y: Int(floor(coordinate.latitude / indexCellSize))
        )
    }
}
