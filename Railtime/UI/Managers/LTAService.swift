import Foundation
import CoreLocation
import Observation
import LTAAPI
import BusEstimation

// MARK: - LTA Service

@Observable
class LTAService {
    var dataSource: LTADataSource
    
    var allBusStops: [BusStop] = [] {
        didSet {
            rebuildBusStopsById()
        }
    }
    var allStations: [Station] = [] {
        didSet {
            sortedStationsByLength = allStations.sorted { $0.name.count > $1.name.count }
        }
    }
    var allMRTRoutes: [LTATrainRoutes] = []

    private(set) var busStopsById: [String: BusStop] = [:]
    private(set) var sortedStationsByLength: [Station] = []
    
    var preseededBusRoutes: [String: PreseededBusService] = [:]
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
        dataSource = .init(
            client: try! LTAClient(accountKey: apiKey),
            diskCache: DiskCache(root: "lta_cache", ttl: 24.0 * 30 * 3600), // 30 days
            memoryCache: MemoryCache(ttl: 5) // 5 second cache
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
    
    // MARK: - Fetch Live Bus Arrivals
    
    func fetchBusArrivals(for stopId: String) async -> [BusArrival] {
        guard let results = try? await dataSource.getBusArrival(busStopCode: stopId) else { return [] }
        let services = results.services

        return services.map { service in
            let nextBusInfo = service.nextBus.flatMap {
                BusTimingInfo(
                    rawArrival: $0.estimatedArrival,
                    loadStr: $0.load?.rawValue,
                    typeStr: $0.type?.rawValue,
                    featureStr: $0.feature,
                    destinationCode: $0.destinationCode
                )
            }
            let nextBus2Info = service.nextBus2.flatMap {
                BusTimingInfo(
                    rawArrival: $0.estimatedArrival,
                    loadStr: $0.load?.rawValue,
                    typeStr: $0.type?.rawValue,
                    featureStr: $0.feature,
                    destinationCode: $0.destinationCode
                )
            }
            let nextBus3Info = service.nextBus3.flatMap {
                BusTimingInfo(
                    rawArrival: $0.estimatedArrival,
                    loadStr: $0.load?.rawValue,
                    typeStr: $0.type?.rawValue,
                    featureStr: $0.feature,
                    destinationCode: $0.destinationCode
                )
            }

            let destCode = service.nextBus?.destinationCode ?? service.nextBus2?.destinationCode ?? service.nextBus3?.destinationCode
            let destName = destCode.flatMap { code in
                self.busStopsById[code]?.name
            }

            return BusArrival(
                serviceNo: service.serviceNo,
                operatorName: service.operator,
                nextBus: nextBusInfo,
                subsequentBus: nextBus2Info,
                thirdBus: nextBus3Info,
                destinationCode: destCode,
                destinationName: destName
            )
        }
    }
    
    // MARK: - Fetch Bus Route Data
    func fetchBusRoute(for serviceNo: String) async -> BusServiceRoute? {
        guard let results = try? await dataSource.getServiceRoutes(serviceNo: serviceNo) else { return nil }

        let dir1Items = results.filter { $0.direction == 1 }.sorted { $0.stopSequence < $1.stopSequence }
        let dir2Items = results.filter { $0.direction == 2 }.sorted { $0.stopSequence < $1.stopSequence }

        let dir1Stops = dir1Items.map { item -> BusRouteStop in
            let stop = self.busStopsById[item.busStopCode]
            let station = self.findNearbyStation(for: stop, code: item.busStopCode)
            return BusRouteStop(
                serviceNo: serviceNo,
                busStopCode: item.busStopCode,
                stopSequence: item.stopSequence,
                direction: 1,
                distance: item.distance,
                busStop: stop,
                nearbyStation: station,
                wdFirstBus: item.wdFirstBus?.hhmmOriginal,
                wdLastBus: item.wdLastBus?.hhmmOriginal,
                satFirstBus: item.satFirstBus?.hhmmOriginal,
                satLastBus: item.satLastBus?.hhmmOriginal,
                sunFirstBus: item.sunFirstBus?.hhmmOriginal,
                sunLastBus: item.sunLastBus?.hhmmOriginal
            )
        }

        let dir2Stops = dir2Items.map { item -> BusRouteStop in
            let stop = self.busStopsById[item.busStopCode]
            let station = self.findNearbyStation(for: stop, code: item.busStopCode)
            return BusRouteStop(
                serviceNo: serviceNo,
                busStopCode: item.busStopCode,
                stopSequence: item.stopSequence,
                direction: 2,
                distance: item.distance,
                busStop: stop,
                nearbyStation: station,
                wdFirstBus: item.wdFirstBus?.hhmmOriginal,
                wdLastBus: item.wdLastBus?.hhmmOriginal,
                satFirstBus: item.satFirstBus?.hhmmOriginal,
                satLastBus: item.satLastBus?.hhmmOriginal,
                sunFirstBus: item.sunFirstBus?.hhmmOriginal,
                sunLastBus: item.sunLastBus?.hhmmOriginal
            )
        }

        return BusServiceRoute(
            serviceNo: serviceNo,
            operatorName: results.first!.operator,
            direction1Stops: dir1Stops,
            direction2Stops: dir2Stops
        )
    }
    
    private func fetchLiveBusRoute(for serviceNo: String) async -> BusServiceRoute? {
        guard let routeItems = try? await dataSource.getServiceRoutes(serviceNo: serviceNo) else { return nil }

        let operatorName = routeItems.first?.operator ?? "SMRT / SBST"
        let dir1Items = routeItems.filter { $0.direction == 1 }.sorted { $0.stopSequence < $1.stopSequence }
        let dir2Items = routeItems.filter { $0.direction == 2 }.sorted { $0.stopSequence < $1.stopSequence }

        let dir1Stops = dir1Items.map { item -> BusRouteStop in
            let stop = self.busStopsById[item.busStopCode]
            let station = self.findNearbyStation(for: stop, code: item.busStopCode)
            return BusRouteStop(
                serviceNo: serviceNo,
                busStopCode: item.busStopCode,
                stopSequence: item.stopSequence,
                direction: 1,
                distance: item.distance,
                busStop: stop,
                nearbyStation: station,
                wdFirstBus: item.wdFirstBus?.hhmmOriginal,
                wdLastBus: item.wdLastBus?.hhmmOriginal,
                satFirstBus: item.satFirstBus?.hhmmOriginal,
                satLastBus: item.satLastBus?.hhmmOriginal,
                sunFirstBus: item.sunFirstBus?.hhmmOriginal,
                sunLastBus: item.sunLastBus?.hhmmOriginal
            )
        }
        
        let dir2Stops = dir2Items.map { item -> BusRouteStop in
            let stop = self.busStopsById[item.busStopCode]
            let station = self.findNearbyStation(for: stop, code: item.busStopCode)
            return BusRouteStop(
                serviceNo: serviceNo,
                busStopCode: item.busStopCode,
                stopSequence: item.stopSequence,
                direction: 2,
                distance: item.distance,
                busStop: stop,
                nearbyStation: station,
                wdFirstBus: item.wdFirstBus?.hhmmOriginal,
                wdLastBus: item.wdLastBus?.hhmmOriginal,
                satFirstBus: item.satFirstBus?.hhmmOriginal,
                satLastBus: item.satLastBus?.hhmmOriginal,
                sunFirstBus: item.sunFirstBus?.hhmmOriginal,
                sunLastBus: item.sunLastBus?.hhmmOriginal
            )
        }
        
        return BusServiceRoute(
            serviceNo: serviceNo,
            operatorName: operatorName,
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
        self.preseededBusRoutes = load([String: PreseededBusService].self, fileName: "bus_routes") ?? [:]
        self.allBusStops = load([LTABusStopInfo].self, fileName: "bus_stops") ?? []

        // load the stations into cache
        dataSource.saveMRTStopsToCache(allStations)
        dataSource.saveBusStopsToCache(allBusStops)
        dataSource.saveMRTRoutesToCache(allMRTRoutes)
        dataSource.saveBulkRoutesToCache(preseededBusRoutes.mapValues({ $0.stops }))
    }
}
