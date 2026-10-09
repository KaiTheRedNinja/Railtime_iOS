import SwiftUI
import CoreLocation
import LTAAPI
import Combine

// MARK: - Home View

struct HomeView: View {
    var ltaService: LTAService
    var locationManager: LocationManager
    var effectiveCenter: CLLocationCoordinate2D
    @Binding var navigationPath: NavigationPath
    var onTapDistance: ((CLLocationCoordinate2D, TransitItem) -> Void)?
    
    @State private var searchText = ""
    @State private var showJourneyPlanner = false
    @State private var showSettings = false
    @State private var now: Date = .now

    // Update the duration shown on screen every second
    var etaRefreshTimer = Timer.publish(every: 1, on: .main, in: .default).autoconnect()

    @AppStorage("mrtStationRangeMeters") private var mrtRangeMeters: Int = 1000
    
    private var mrtRangeLabel: String {
        if mrtRangeMeters < 1000 {
            return "\(mrtRangeMeters)m"
        } else {
            return "\(mrtRangeMeters / 1000) km"
        }
    }
    
    // Filtered stations strictly within user-configured range of effective center (or all matching search query)
    private var filteredStationsWithinRange: [Station] {
        let center = effectiveCenter
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let maxDeg = Double(mrtRangeMeters) / 100000.0 + 0.005
            let nearby = ltaService.allStations.filter {
                abs($0.coordinate.latitude - center.latitude) < maxDeg &&
                abs($0.coordinate.longitude - center.longitude) < maxDeg
            }
            return nearby.filter {
                ($0.distance(from: center) ?? Double.infinity) <= Double(mrtRangeMeters)
            }.sorted {
                ($0.distance(from: center) ?? Double.infinity) < ($1.distance(from: center) ?? Double.infinity)
            }
        } else {
            return ltaService.allStations.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.id.localizedCaseInsensitiveContains(searchText) ||
                $0.lines.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }.sorted {
                ($0.distance(from: center) ?? Double.infinity) < ($1.distance(from: center) ?? Double.infinity)
            }
        }
    }
    
    // Filtered bus stops adaptively relative to map center (strictly limited to 6 stops)
    private var filteredBusStops: [BusStop] {
        let center = effectiveCenter
        let cleanSearch = searchText.trimmingCharacters(in: .whitespaces)
        
        if cleanSearch.isEmpty {
            // Fast bounding box pre-filter (~2km) avoids sorting all 5,208 stops on every frame
            let nearby = ltaService.allBusStops.filter {
                abs($0.coordinate.latitude - center.latitude) < 0.020 &&
                abs($0.coordinate.longitude - center.longitude) < 0.020
            }
            let sorted = nearby.sorted {
                ($0.distance(from: center) ?? Double.infinity) < ($1.distance(from: center) ?? Double.infinity)
            }
            return Array(sorted.prefix(6))
        } else {
            let matches = ltaService.allBusStops.filter {
                $0.name.localizedCaseInsensitiveContains(cleanSearch) ||
                $0.id.localizedCaseInsensitiveContains(cleanSearch) ||
                ($0.roadName ?? "").localizedCaseInsensitiveContains(cleanSearch)
            }
            let sorted = matches.sorted {
                ($0.distance(from: center) ?? Double.infinity) < ($1.distance(from: center) ?? Double.infinity)
            }
            return Array(sorted.prefix(6))
        }
    }
    
    // Dynamic filtered bus services searching across all 602 Singapore bus services
    private var filteredBusServices: [String] {
        let clean = searchText.trimmingCharacters(in: .whitespaces).uppercased()
        guard !clean.isEmpty else { return [] }
        
        let allKeys = ltaService.dataSource.getAllBusServices() ?? []
        let matches = allKeys.filter { $0.localizedCaseInsensitiveContains(clean) }
        
        return Array(matches.sorted { a, b in
            if a == clean { return true }
            if b == clean { return false }
            return a.localizedStandardCompare(b) == .orderedAscending
        }.prefix(10))
    }
    
    private var trainAlertSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: ltaService.isTrainStatusNormal ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(ltaService.isTrainStatusNormal ? .green : .orange)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(ltaService.isTrainStatusNormal ? "MRT Network: Normal Service" : "MRT Service Alert")
                        .font(.headline)
                    
                    if let alertText = ltaService.trainServiceAlert {
                        Text(alertText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    } else {
                        Text("Live status from LTA DataMall")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                topBar

                List {
//                    // MARK: - Plan Journey Prominent Banner
//                    Section {
//                        Button {
//                            showJourneyPlanner = true
//                        } label: {
//                            HStack(spacing: 12) {
//                                Image(systemName: "figure.transit")
//                                    .font(.title3)
//                                    .foregroundStyle(.blue)
//                                VStack(alignment: .leading, spacing: 2) {
//                                    Text("Plan Journey")
//                                        .font(.headline)
//                                        .foregroundStyle(.primary)
//                                    Text("Custom trip planner & live bus timing estimator")
//                                        .font(.caption)
//                                        .foregroundStyle(.secondary)
//                                }
//                                Spacer()
//                                Image(systemName: "chevron.right")
//                                    .font(.caption)
//                                    .foregroundStyle(.secondary)
//                            }
//                            .padding(.vertical, 2)
//                        }
//                    }

                    // IF DISRUPTED -> Show alert banner
                    if !ltaService.isTrainStatusNormal {
                        trainAlertSection
                    }
                    
                    // Bus Services Search Results
                    if !filteredBusServices.isEmpty {
                        Section("Bus Services") {
                            ForEach(filteredBusServices, id: \.self) { serviceNo in
                                NavigationLink(value: BusServiceDetail(serviceNo: serviceNo, originStopCode: nil)) {
                                    HStack(spacing: 12) {
                                        Text(serviceNo)
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.blue)
                                            .clipShape(Capsule())
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Bus Service \(serviceNo)")
                                                .font(.headline)
                                            Text("Tap to view route & all bus stops")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                    
                    nearbyMRTStops

                    nearbyBusStops
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .sheet(isPresented: $showJourneyPlanner) {
                JourneyBuilderView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .navigationDestination(for: Station.self) { station in
                StationView(
                    station: station,
                    ltaService: ltaService,
                    locationManager: locationManager,
                    effectiveCenter: effectiveCenter,
                    onTapDistance: onTapDistance
                )
            }
            .navigationDestination(for: BusStop.self) { stop in
                BusStopView(
                    busStop: stop,
                    ltaService: ltaService,
                    locationManager: locationManager,
                    effectiveCenter: effectiveCenter,
                    onTapDistance: onTapDistance
                )
            }
            .navigationDestination(for: BusServiceDetail.self) { detail in
                BusServiceView(
                    serviceNo: detail.serviceNo,
                    originStopCode: detail.originStopCode,
                    ltaService: ltaService
                )
            }
        }
        .onReceive(etaRefreshTimer) { _ in
            self.now = .now
        }
    }

    var topBar: some View {
        // MARK: - Search Bar & Top Actions
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("Search stations, stops, or bus numbers", text: $searchText)
                    .font(.body)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // MARK: - Plan Journey Button
            Button {
                showJourneyPlanner = true
            } label: {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("Plan Journey")

            // MARK: - Settings Button
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    var nearbyMRTStops: some View {
        // Nearby MRT & LRT Stations (User-configured range)
        Section {
            if filteredStationsWithinRange.isEmpty {
                HStack {
                    Image(systemName: "tram")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.secondary)
                        .frame(width: 40, height: 40)

                    VStack(alignment: .leading) {
                        Text("No Stations Found")
                            .font(.headline)
                            .bold()
                        Text("No MRT/LRT stations within \(mrtRangeLabel).")
                    }
                }
            } else {
                ForEach(filteredStationsWithinRange) { station in
                    NavigationLink(value: station) {
                        HStack(spacing: 10) {
                            StationCodeCapletView(station: station)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(station.name)
                                    .font(.headline)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }

                            Spacer(minLength: 4)

                            if let distanceStr = station.formattedDistance(from: effectiveCenter) {
                                Button {
                                    onTapDistance?(station.coordinate, .station(station))
                                } label: {
                                    HStack(spacing: 3) {
                                        Image(systemName: "location.fill")
                                            .font(.caption2)
                                        Text(distanceStr)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.12))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text("MRT & LRT Stations")
                Spacer()
                Text("within \(mrtRangeLabel)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var nearbyBusStops: some View {
        // Nearby Bus Stops (Adaptive to map center, strictly limited to 6 stops)
        Section {
            if filteredBusStops.isEmpty {
                HStack {
                    Image(systemName: "bus")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.secondary)
                        .frame(width: 40, height: 40)

                    VStack(alignment: .leading) {
                        Text("No Bus Stops Found")
                            .font(.headline)
                            .bold()
                        Text("Try adjusting your search criteria")
                    }
                }
            } else {
                ForEach(filteredBusStops) { stop in
                    NavigationLink(value: stop) {
                        BusStopHomeRow(
                            stop: stop,
                            ltaService: ltaService,
                            effectiveCenter: effectiveCenter,
                            onTapDistance: {
                                onTapDistance?(stop.coordinate, .busStop(stop))
                            },
                            now: now
                        )
                    }
                }
            }
        } header: {
            HStack {
                Text("Nearby Bus Stops")
                Spacer()
                Text("\(filteredBusStops.count) stops")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
