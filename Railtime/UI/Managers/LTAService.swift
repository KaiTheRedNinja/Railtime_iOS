import Foundation
import CoreLocation
import Observation
import LTAAPI
import BusEstimation

// MARK: - LTA Service

@Observable
class LTAService {
    var apiKey: String {
        let accountKey = UserDefaults.standard.string(forKey: "LTA_ACCOUNT_KEY") ?? ""
        if !accountKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return accountKey
        }
        let key = UserDefaults.standard.string(forKey: "LTA_API_KEY") ?? ""
        if !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return key
        }
        if let envKey = ProcessInfo.processInfo.environment["LTA_ACCOUNT_KEY"], !envKey.isEmpty {
            return envKey
        }
        return "19hQsIO6RjOhqlAVh4DRKw=="
    }
    
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
        loadPreseededStations()
        loadPreseededBusStops()
        loadPreseededBusRoutes()
        loadPreseededMRTRoutes()

        // load the stations into cache
        let estimator = BusArrivalEstimator(client: try! LTAClient(accountKey: apiKey))
        estimator.data.saveMRTStopsToCache(allStations.map {
            .init(
                id: $0.id,
                description: $0.name,
                latitude: $0.coordinate.latitude,
                longitude: $0.coordinate.longitude,
                lines: $0.lines,
                exits: $0.exits.map {
                    .init(code: $0.code, description: $0.description)
                }
            )
        })
        estimator.data.saveBusStopsToCache(
            allBusStops.map {
                .init(
                    busStopCode: $0.id,
                    roadName: $0.roadName,
                    description: $0.name,
                    latitude: $0.coordinate.latitude,
                    longitude: $0.coordinate.longitude
                )
        })
        estimator.data.saveMRTRoutesToCache(allMRTRoutes)
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
        let codes = station.id.split(separator: "/").map { String($0).trimmingCharacters(in: .whitespaces) }
        var lineCrowds: [StationLineCrowd] = []
        
        for stnCode in codes {
            let trainLineParam: String? = {
                if stnCode.hasPrefix("NS") { return "NSL" }
                if stnCode.hasPrefix("EW") { return "EWL" }
                if stnCode.hasPrefix("NE") { return "NEL" }
                if stnCode.hasPrefix("CC") || stnCode.hasPrefix("CE") { return "CCL" }
                if stnCode.hasPrefix("DT") { return "DTL" }
                if stnCode.hasPrefix("TE") { return "TEL" }
                if stnCode.hasPrefix("BP") { return "BPL" }
                if stnCode.hasPrefix("SE") || stnCode.hasPrefix("SW") { return "SLRT" }
                if stnCode.hasPrefix("PE") || stnCode.hasPrefix("PW") { return "PLRT" }
                return nil
            }()
            
            guard let lineParam = trainLineParam,
                  let url = URL(string: "https://datamall2.mytransport.sg/ltaodataservice/PCDRealTime?TrainLine=\(lineParam)") else {
                continue
            }
            
            var request = URLRequest(url: url)
            request.setValue(apiKey, forHTTPHeaderField: "AccountKey")
            request.setValue("application/json", forHTTPHeaderField: "accept")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { continue }
                
                let decoded = try JSONDecoder().decode(LTAPCDRealTimeResponse.self, from: data)
                if let items = decoded.value,
                   let match = items.first(where: { $0.station == stnCode }),
                   let rawLevel = match.crowdLevel {
                    let level = StationCrowdLevel(rawValue: rawLevel) ?? .unknown
                    let prefix = String(stnCode.prefix(2))
                    lineCrowds.append(StationLineCrowd(lineCode: prefix, stationCode: stnCode, crowdLevel: level))
                }
            } catch {
                print("Error fetching crowd level for \(stnCode): \(error)")
            }
        }
        
        return lineCrowds
    }
    
    // MARK: - Fetch Live Bus Arrivals
    
    func fetchBusArrivals(for stopId: String) async -> [BusArrival] {
        guard let url = URL(string: "https://datamall2.mytransport.sg/ltaodataservice/v3/BusArrival?BusStopCode=\(stopId)") else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "AccountKey")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return []
            }
            
            let decoded = try JSONDecoder().decode(LTABusArrivalResponse.self, from: data)
            guard let services = decoded.services else { return [] }
            
            return services.map { service in
                let nextBusInfo = service.nextBus.flatMap {
                    BusTimingInfo(rawArrival: $0.estimatedArrival, loadStr: $0.load, typeStr: $0.type, featureStr: $0.feature, destinationCode: $0.destinationCode)
                }
                let nextBus2Info = service.nextBus2.flatMap {
                    BusTimingInfo(rawArrival: $0.estimatedArrival, loadStr: $0.load, typeStr: $0.type, featureStr: $0.feature, destinationCode: $0.destinationCode)
                }
                let nextBus3Info = service.nextBus3.flatMap {
                    BusTimingInfo(rawArrival: $0.estimatedArrival, loadStr: $0.load, typeStr: $0.type, featureStr: $0.feature, destinationCode: $0.destinationCode)
                }
                
                let destCode = service.nextBus?.destinationCode ?? service.nextBus2?.destinationCode ?? service.nextBus3?.destinationCode
                let destName = destCode.flatMap { code in
                    self.busStopsById[code]?.name
                }
                
                return BusArrival(
                    serviceNo: service.serviceNo,
                    operatorName: service.busOperator,
                    nextBus: nextBusInfo,
                    subsequentBus: nextBus2Info,
                    thirdBus: nextBus3Info,
                    destinationCode: destCode,
                    destinationName: destName
                )
            }
        } catch {
            print("Error fetching bus arrivals for \(stopId): \(error)")
            return []
        }
    }
    
    // MARK: - Fetch Bus Route Data
    
    func fetchBusRoute(for serviceNo: String) async -> BusServiceRoute? {
        let key = serviceNo.trimmingCharacters(in: .whitespaces).uppercased()
        
        // 1. Instant lookup from preseeded bus routes dataset (602 bus services)
        if let preseeded = preseededBusRoutes[key] ?? preseededBusRoutes[serviceNo] {
            return buildRouteFromPreseeded(preseeded)
        }
        
        // 2. Try live LTA DataMall API lookup if not in preseeded dataset
        if let liveRoute = await fetchLiveBusRoute(for: serviceNo) {
            return liveRoute
        }
        
        // 3. Fallback generator
        return generateFallbackBusRoute(for: serviceNo)
    }
    
    private func buildRouteFromPreseeded(_ preseeded: PreseededBusService) -> BusServiceRoute {
        let dir1Items = preseeded.stops.filter { $0.direction == 1 }.sorted { $0.stopSequence < $1.stopSequence }
        let dir2Items = preseeded.stops.filter { $0.direction == 2 }.sorted { $0.stopSequence < $1.stopSequence }
        
        let dir1Stops = dir1Items.map { item -> BusRouteStop in
            let stop = self.busStopsById[item.busStopCode]
            let station = self.findNearbyStation(for: stop, code: item.busStopCode)
            return BusRouteStop(
                serviceNo: preseeded.serviceNo,
                busStopCode: item.busStopCode,
                stopSequence: item.stopSequence,
                direction: 1,
                distance: item.distance,
                busStop: stop,
                nearbyStation: station,
                wdFirstBus: item.wdFirstBus,
                wdLastBus: item.wdLastBus,
                satFirstBus: item.satFirstBus,
                satLastBus: item.satLastBus,
                sunFirstBus: item.sunFirstBus,
                sunLastBus: item.sunLastBus
            )
        }
        
        let dir2Stops = dir2Items.map { item -> BusRouteStop in
            let stop = self.busStopsById[item.busStopCode]
            let station = self.findNearbyStation(for: stop, code: item.busStopCode)
            return BusRouteStop(
                serviceNo: preseeded.serviceNo,
                busStopCode: item.busStopCode,
                stopSequence: item.stopSequence,
                direction: 2,
                distance: item.distance,
                busStop: stop,
                nearbyStation: station,
                wdFirstBus: item.wdFirstBus,
                wdLastBus: item.wdLastBus,
                satFirstBus: item.satFirstBus,
                satLastBus: item.satLastBus,
                sunFirstBus: item.sunFirstBus,
                sunLastBus: item.sunLastBus
            )
        }
        
        return BusServiceRoute(
            serviceNo: preseeded.serviceNo,
            operatorName: preseeded.operatorName,
            direction1Stops: dir1Stops,
            direction2Stops: dir2Stops
        )
    }
    
    private func fetchLiveBusRoute(for serviceNo: String) async -> BusServiceRoute? {
        var routeItems: [LTABusRouteItem] = []
        var skip = 0
        var found = false
        
        while skip < 35000 {
            guard let url = URL(string: "https://datamall2.mytransport.sg/ltaodataservice/BusRoutes?$skip=\(skip)") else { break }
            var request = URLRequest(url: url)
            request.setValue(apiKey, forHTTPHeaderField: "AccountKey")
            request.setValue("application/json", forHTTPHeaderField: "accept")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { break }
                let decoded = try JSONDecoder().decode(LTABusRoutesResponse.self, from: data)
                if decoded.value.isEmpty { break }
                
                let matches = decoded.value.filter { $0.serviceNo.lowercased() == serviceNo.lowercased() }
                if !matches.isEmpty {
                    routeItems.append(contentsOf: matches)
                    found = true
                } else if found {
                    break
                }
                skip += 500
            } catch {
                print("Error fetching bus route page at skip \(skip): \(error)")
                break
            }
        }
        
        guard !routeItems.isEmpty else { return nil }
        
        let operatorName = routeItems.first?.busOperator ?? "SMRT / SBST"
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
                wdFirstBus: item.wdFirstBus,
                wdLastBus: item.wdLastBus,
                satFirstBus: item.satFirstBus,
                satLastBus: item.satLastBus,
                sunFirstBus: item.sunFirstBus,
                sunLastBus: item.sunLastBus
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
                wdFirstBus: item.wdFirstBus,
                wdLastBus: item.wdLastBus,
                satFirstBus: item.satFirstBus,
                satLastBus: item.satLastBus,
                sunFirstBus: item.sunFirstBus,
                sunLastBus: item.sunLastBus
            )
        }
        
        return BusServiceRoute(
            serviceNo: serviceNo,
            operatorName: operatorName,
            direction1Stops: dir1Stops,
            direction2Stops: dir2Stops
        )
    }
    
    private func generateFallbackBusRoute(for serviceNo: String) -> BusServiceRoute {
        let sampleStops = Array(allBusStops.prefix(10))
        let dir1 = sampleStops.enumerated().map { idx, stop in
            BusRouteStop(
                serviceNo: serviceNo,
                busStopCode: stop.id,
                stopSequence: idx + 1,
                direction: 1,
                distance: Double(idx) * 1.2,
                busStop: stop,
                nearbyStation: findNearbyStation(for: stop, code: stop.id)
            )
        }
        let dir2 = sampleStops.reversed().enumerated().map { idx, stop in
            BusRouteStop(
                serviceNo: serviceNo,
                busStopCode: stop.id,
                stopSequence: idx + 1,
                direction: 2,
                distance: Double(idx) * 1.2,
                busStop: stop,
                nearbyStation: findNearbyStation(for: stop, code: stop.id)
            )
        }
        
        return BusServiceRoute(
            serviceNo: serviceNo,
            operatorName: "SBST / SMRT",
            direction1Stops: dir1,
            direction2Stops: dir2
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
        
        var fetchedStops: [BusStop] = []
        var skip = 0
        var hasMore = true
        
        while hasMore && skip < 6000 {
            guard let url = URL(string: "https://datamall2.mytransport.sg/ltaodataservice/BusStops?$skip=\(skip)") else { break }
            var request = URLRequest(url: url)
            request.setValue(apiKey, forHTTPHeaderField: "AccountKey")
            request.setValue("application/json", forHTTPHeaderField: "accept")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { break }
                
                let decoded = try JSONDecoder().decode(LTABusStopsResponse.self, from: data)
                if decoded.value.isEmpty {
                    hasMore = false
                } else {
                    let pageStops = decoded.value.map { item in
                        BusStop(
                            id: item.busStopCode,
                            name: item.description,
                            roadName: item.roadName,
                            coordinate: CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude)
                        )
                    }
                    fetchedStops.append(contentsOf: pageStops)
                    skip += 500
                }
            } catch {
                print("Error fetching live bus stops page at skip \(skip): \(error)")
                break
            }
        }
        
        if !fetchedStops.isEmpty {
            await MainActor.run {
                self.allBusStops = fetchedStops
            }
        }
    }
    
    // MARK: - Fetch Train Service Alerts
    
    func fetchTrainServiceAlerts() async {
        guard let url = URL(string: "https://datamall2.mytransport.sg/ltaodataservice/TrainServiceAlerts") else { return }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "AccountKey")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            
            let decoded = try JSONDecoder().decode(LTATrainAlertsResponse.self, from: data)
            if let val = decoded.value {
                let status = val.status ?? 1
                let firstContent = val.message?.first?.content
                
                await MainActor.run {
                    self.isTrainStatusNormal = (status == 1)
                    self.trainServiceAlert = (firstContent?.isEmpty == false) ? firstContent : nil
                }
            }
        } catch {
            print("Error fetching train alerts: \(error)")
        }
    }
    
    // MARK: - Preseeded Bus Service Routes (602 Singapore Bus Services)
    
    private func loadPreseededBusRoutes() {
        if let url = Bundle.main.url(forResource: "bus_routes", withExtension: "json") ??
                     Bundle.main.url(forResource: "Bus_routes", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode([String: PreseededBusService].self, from: data)
                self.preseededBusRoutes = decoded
                print("Successfully loaded \(decoded.count) bus service routes from bus_routes.json in main bundle.")
                return
            } catch {
                print("Error decoding bus_routes.json from bundle url: \(error)")
            }
        }
        
        if let path = Bundle.main.path(forResource: "bus_routes", ofType: "json"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let decoded = try? JSONDecoder().decode([String: PreseededBusService].self, from: data) {
            self.preseededBusRoutes = decoded
            print("Successfully loaded \(decoded.count) bus service routes from bundle path.")
            return
        }
        
        print("Warning: bus_routes.json not found in main bundle!")
    }
    
    // MARK: - Local Station Data (Loaded from stations.json / Fallback)
    
    private func loadPreseededStations() {
        if let url = Bundle.main.url(forResource: "stations", withExtension: "json") ??
                     Bundle.main.url(forResource: "Stations", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode([Station].self, from: data)
                self.allStations = decoded
                print("Successfully loaded \(decoded.count) MRT/LRT stations from main bundle url.")
                return
            } catch {
                print("Error decoding stations.json from bundle url: \(error)")
            }
        }
        
        if let path = Bundle.main.path(forResource: "stations", ofType: "json"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let decoded = try? JSONDecoder().decode([Station].self, from: data) {
            self.allStations = decoded
            print("Successfully loaded \(decoded.count) MRT/LRT stations from bundle path.")
            return
        }
        
        print("Using fallback preseeded MRT stations")
        loadFallbackStations()
    }

    private func loadPreseededMRTRoutes() {
        struct MRTRoutesContents: Codable {
            var routes: [String: LTATrainRoutes]
        }

        if let url = Bundle.main.url(forResource: "mrt_routes", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode(MRTRoutesContents.self, from: data)
                self.allMRTRoutes = Array(decoded.routes.values)
                print("Successfully loaded \(decoded.routes.values.count) MRT/LRT routes from main bundle url.")
                return
            } catch {
                print("Error decoding stations.json from bundle url: \(error)")
            }
        }
    }

    private func loadFallbackStations() {
        self.allStations = [
            Station(
                id: "NS22/TE14",
                name: "Orchard",
                coordinate: CLLocationCoordinate2D(latitude: 1.3040, longitude: 103.8318),
                lines: ["NS", "TE"],
                exits: [
                    StationExit(code: "Exit A", description: "ION Orchard, Tang Plaza"),
                    StationExit(code: "Exit B", description: "Wheelock Place, Wisma Atria")
                ],
                chineseName: "乌节",
                tamilName: "ஆர்ச்சர்ட்"
            ),
            Station(
                id: "NS25/EW13",
                name: "City Hall",
                coordinate: CLLocationCoordinate2D(latitude: 1.2931, longitude: 103.8521),
                lines: ["NS", "EW"],
                exits: [
                    StationExit(code: "Exit A", description: "Raffles City Shopping Centre"),
                    StationExit(code: "Exit B", description: "St Andrew's Cathedral, National Gallery Singapore")
                ],
                chineseName: "政府大厦",
                tamilName: "সিটি হল"
            ),
            Station(
                id: "NS26/EW14",
                name: "Raffles Place",
                coordinate: CLLocationCoordinate2D(latitude: 1.2839, longitude: 103.8515),
                lines: ["NS", "EW"],
                exits: [
                    StationExit(code: "Exit A", description: "One Raffles Place, Republic Plaza"),
                    StationExit(code: "Exit B", description: "OCBC Centre, Boat Quay")
                ],
                chineseName: "莱佛士坊",
                tamilName: "ராஃபிள்ஸ் பிளேஸ்"
            ),
            Station(
                id: "EW12/DT14",
                name: "Bugis",
                coordinate: CLLocationCoordinate2D(latitude: 1.3006, longitude: 103.8558),
                lines: ["EW", "DT"],
                exits: [
                    StationExit(code: "Exit A", description: "Bugis Street, Bugis Junction"),
                    StationExit(code: "Exit B", description: "Raffles Hospital, Kampong Glam")
                ],
                chineseName: "武吉士",
                tamilName: "புஜிஸ்"
            ),
            Station(
                id: "NS1/EW24",
                name: "Jurong East",
                coordinate: CLLocationCoordinate2D(latitude: 1.3338, longitude: 103.7420),
                lines: ["NS", "EW"],
                exits: [
                    StationExit(code: "Exit A", description: "JEM, Westgate, Jurong East Bus Interchange"),
                    StationExit(code: "Exit B", description: "IMM, Big Box")
                ],
                chineseName: "裕廊东",
                tamilName: "ஜூரோங் ஈஸ்ட்"
            ),
            Station(
                id: "EW2/DT32",
                name: "Tampines",
                coordinate: CLLocationCoordinate2D(latitude: 1.3538, longitude: 103.9448),
                lines: ["EW", "DT"],
                exits: [
                    StationExit(code: "Exit A", description: "Tampines Mall, Century Square"),
                    StationExit(code: "Exit B", description: "Tampines 1, Tampines Bus Interchange")
                ],
                chineseName: "淡滨尼",
                tamilName: "தம்பினிஸ்"
            ),
            Station(
                id: "NS9/TE2",
                name: "Woodlands",
                coordinate: CLLocationCoordinate2D(latitude: 1.4372, longitude: 103.7862),
                lines: ["NS", "TE"],
                exits: [
                    StationExit(code: "Exit 1", description: "Causeway Point, Woodlands Bus Interchange"),
                    StationExit(code: "Exit 2", description: "Woodlands Civic Centre")
                ],
                chineseName: "兀兰",
                tamilName: "வூட்லண்ட்ஸ்"
            )
        ]
    }
    
    private func loadPreseededBusStops() {
        if let url = Bundle.main.url(forResource: "bus_stops", withExtension: "json") ??
                     Bundle.main.url(forResource: "Bus_stops", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode([LTABusStopItem].self, from: data)
                self.allBusStops = decoded.map { item in
                    BusStop(
                        id: item.busStopCode,
                        name: item.description,
                        roadName: item.roadName,
                        coordinate: CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude)
                    )
                }
                print("Successfully loaded \(decoded.count) bus stops from bus_stops.json.")
                return
            } catch {
                print("Error decoding bus_stops.json: \(error)")
            }
        }
        
        if let path = Bundle.main.path(forResource: "bus_stops", ofType: "json"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let decoded = try? JSONDecoder().decode([LTABusStopItem].self, from: data) {
            self.allBusStops = decoded.map { item in
                BusStop(
                    id: item.busStopCode,
                    name: item.description,
                    roadName: item.roadName,
                    coordinate: CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude)
                )
            }
            print("Successfully loaded \(decoded.count) bus stops from bundle path.")
            return
        }
        
        print("Using fallback preseeded bus stops")
        loadFallbackBusStops()
    }
    
    private func loadFallbackBusStops() {
        self.allBusStops = [
            BusStop(id: "09048", name: "Orchard Stn/Tang Plaza", roadName: "Orchard Rd", coordinate: CLLocationCoordinate2D(latitude: 1.3043, longitude: 103.8322)),
            BusStop(id: "09023", name: "Opp Orchard Stn/ION", roadName: "Orchard Rd", coordinate: CLLocationCoordinate2D(latitude: 1.3038, longitude: 103.8315)),
            BusStop(id: "08057", name: "Dhoby Ghaut Stn", roadName: "Orchard Rd", coordinate: CLLocationCoordinate2D(latitude: 1.2991, longitude: 103.8458)),
            BusStop(id: "04111", name: "City Hall Stn Exit B", roadName: "North Bridge Rd", coordinate: CLLocationCoordinate2D(latitude: 1.2928, longitude: 103.8525)),
            BusStop(id: "01012", name: "Raffles Place Stn Exit F", roadName: "Robinson Rd", coordinate: CLLocationCoordinate2D(latitude: 1.2835, longitude: 103.8510))
        ]
    }
}
