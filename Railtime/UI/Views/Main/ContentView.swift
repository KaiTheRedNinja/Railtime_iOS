import SwiftUI
import MapKit
import LTAAPI

// MARK: - Main Content View (Interactive Map with Custom Pins)

struct ContentView: View {
    var ltaService: LTAService
    var locationManager: LocationManager
    
    @State private var navigationPath = NavigationPath()
    @State private var sheetSelection: PresentationDetent = .fraction(0.25)
    @State private var selectedTransitItem: TransitItem? = nil
    
    // Smooth camera state with debounced map center tracking to prevent 120Hz view re-evaluation
    @State private var position: MapCameraPosition = .automatic
    @State private var immediateMapCenter: CLLocationCoordinate2D? = nil
    @State private var debouncedMapCenter: CLLocationCoordinate2D? = nil
    @State private var cameraDebounceTask: Task<Void, Never>? = nil
    @State private var hasCenteredOnUser: Bool = false
    
    @State private var currentCameraDistance: Double = 1800
    @State private var lastCameraDistance: Double = 1800
    @State private var isZooming: Bool = false
    @State private var hasInitialCameraSettled: Bool = false
    @State private var zoomHideTask: Task<Void, Never>? = nil
    
    // User Settings AppStorage
    @AppStorage("mrtZoomThreshold") private var mrtZoomThreshold: Int = 1
    @AppStorage("busStopsZoomThreshold") private var busStopsZoomThreshold: Int = 40
    @AppStorage("exitsZoomThreshold") private var exitsZoomThreshold: Int = 60
    @AppStorage("colorSchemeMode") private var colorSchemeMode: String = "system"
    
    private var preferredColorScheme: ColorScheme? {
        switch colorSchemeMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    // Effective center: user location or map camera center fallback
    private var effectiveCenter: CLLocationCoordinate2D {
        debouncedMapCenter ?? locationManager.userLocation ?? CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198)
    }
    
    private var currentZoomPercent: Int {
        zoomPercentage(currentCameraDistance)
    }
    
    // Threshold 1: MRT / LRT stations shown at zoom >= mrtZoomThreshold%
    private var showMRTStations: Bool {
        currentZoomPercent >= mrtZoomThreshold
    }
    
    // Threshold 2: Bus stops shown at zoom >= busStopsZoomThreshold%
    private var showBusStops: Bool {
        currentZoomPercent >= busStopsZoomThreshold
    }
    
    // Threshold 3: Station exit indicators shown at zoom >= exitsZoomThreshold%
    private var showExitIndicators: Bool {
        currentZoomPercent >= exitsZoomThreshold
    }
    
    // Dynamic scale for map station caplets based on zoom percentage (0.50x to 1.15x)
    private var stationCapletScale: CGFloat {
        let pct = Double(currentZoomPercent) / 100.0
        let scale = 0.50 + (pct * 0.65)
        return CGFloat(scale)
    }
    
    // Dynamic scale for station exit icons and bus stop badges based on zoom percentage (0.45x to 1.15x)
    private var detailIconScale: CGFloat {
        let pct = Double(currentZoomPercent) / 100.0
        let scale = 0.45 + (pct * 0.70)
        return CGFloat(scale)
    }
    
    // Bounding box filter for nearby bus stops (~1.5km) to prevent frame drops when panning
    private var sortedBusStops: [BusStop] {
        let center = effectiveCenter
        let nearby = ltaService.allBusStops.filter {
            abs($0.coordinate.latitude - center.latitude) < 0.015 &&
            abs($0.coordinate.longitude - center.longitude) < 0.015
        }
        return nearby.sorted {
            ($0.distance(from: center) ?? Double.infinity) < ($1.distance(from: center) ?? Double.infinity)
        }
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Map(position: $position, selection: $selectedTransitItem) {
                UserAnnotation()
                
                // Render MRT / LRT Stations on map (Zoom >= mrtZoomThreshold%)
                if showMRTStations {
                    ForEach(ltaService.allStations) { station in
                        Annotation(station.name, coordinate: station.coordinate) {
                            StationCodeCapletView(station: station)
                                .scaleEffect(stationCapletScale)
                                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.85), value: stationCapletScale)
                                .onTapGesture {
                                    selectAndNavigateTo(item: .station(station))
                                }
                        }
                        .tag(TransitItem.station(station))
                        
                        // Render Station Exit custom icons on map (Zoom >= exitsZoomThreshold%)
                        if showExitIndicators {
                            ForEach(Array(station.exits.enumerated()), id: \.element.code) { index, exit in
                                let exitCoord = exit.coordinate(for: station, index: index, total: station.exits.count)
                                Annotation("", coordinate: exitCoord) {
                                    StationExitIconView(exitCode: exit.code, size: 24)
                                        .scaleEffect(detailIconScale)
                                        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.85), value: detailIconScale)
                                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                        .onTapGesture {
                                            selectAndNavigateTo(item: .station(station))
                                        }
                                }
                                .tag("\(station.id)_exit_\(exit.code)")
                            }
                        }
                    }
                }
                
                // Render Bus Stops on Map (Zoom >= busStopsZoomThreshold%)
                if showBusStops {
                    ForEach(sortedBusStops.prefix(30)) { stop in
                        Annotation(stop.name, coordinate: stop.coordinate) {
                            Image(stop.iconName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .padding(5)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                                .scaleEffect(detailIconScale)
                                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.85), value: detailIconScale)
                                .contentShape(Circle())
                                .onTapGesture {
                                    selectAndNavigateTo(item: .busStop(stop))
                                }
                        }
                        .tag(TransitItem.busStop(stop))
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .onMapCameraChange { context in
                let newCenter = context.camera.centerCoordinate
                let newDistance = context.camera.distance
                
                Task { @MainActor in
                    self.immediateMapCenter = newCenter
                    
                    if self.hasInitialCameraSettled {
                        if abs(newDistance - self.lastCameraDistance) > 1.0 {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                self.isZooming = true
                            }
                            self.zoomHideTask?.cancel()
                            self.zoomHideTask = Task {
                                try? await Task.sleep(nanoseconds: 1_200_000_000)
                                if !Task.isCancelled {
                                    await MainActor.run {
                                        withAnimation(.easeInOut(duration: 0.35)) {
                                            self.isZooming = false
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        self.hasInitialCameraSettled = true
                    }
                    
                    self.lastCameraDistance = newDistance
                    self.currentCameraDistance = newDistance
                    
                    // Debounce map updates by 1.5 seconds after panning stops
                    self.cameraDebounceTask?.cancel()
                    self.cameraDebounceTask = Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        if !Task.isCancelled {
                            await MainActor.run {
                                self.debouncedMapCenter = newCenter
                            }
                        }
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            
            // MARK: - Subtle Floating Zoom Level Indicator Badge (%) - Top Left (Active Zooming Only)
            if isZooming {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    
                    Text("\(currentZoomPercent)%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
                .padding(.top, 54)
                .padding(.leading, 16)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .sheet(isPresented: .constant(true)) {
            HomeView(
                ltaService: ltaService,
                locationManager: locationManager,
                effectiveCenter: effectiveCenter,
                navigationPath: $navigationPath,
                onTapDistance: { coord, item in
                    selectAndNavigateTo(item: item)
                }
            )
            .presentationBackgroundInteraction(.enabled)
            .presentationDetents([.fraction(0.25), .fraction(0.5), .large], selection: $sheetSelection)
            .interactiveDismissDisabled()
            .presentationCornerRadius(24)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await ltaService.fetchTrainServiceAlerts()
            await ltaService.fetchLiveBusStops()
        }
        .onChange(of: selectedTransitItem) { _, newItem in
            if let item = newItem {
                selectAndNavigateTo(item: item)
                selectedTransitItem = nil
            }
        }
        // Center map on user location automatically when location updates at startup
        .onChange(of: locationManager.userLocation?.latitude) { _, _ in
            if let userLoc = locationManager.userLocation, !hasCenteredOnUser {
                // If user location is in Singapore, center map on user location
                if userLoc.latitude > 1.1 && userLoc.latitude < 1.5 && userLoc.longitude > 103.5 && userLoc.longitude < 104.1 {
                    hasCenteredOnUser = true
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                        position = .camera(MapCamera(centerCoordinate: userLoc, distance: 1800))
                    }
                }
            }
        }
    }
    
    private func zoomPercentage(_ distance: Double) -> Int {
        let minDist = 200.0   // 100% zoomed in
        let maxDist = 50000.0 // 0% zoomed out
        let clamped = max(minDist, min(maxDist, distance))
        let logMin = log(minDist)
        let logMax = log(maxDist)
        let fraction = 1.0 - ((log(clamped) - logMin) / (logMax - logMin))
        let percentage = Int((fraction * 100.0).rounded())
        return max(0, min(100, percentage))
    }
    
    private func selectAndNavigateTo(item: TransitItem) {
        switch item {
        case .station(let station):
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                position = .camera(MapCamera(centerCoordinate: station.coordinate, distance: 1200))
                sheetSelection = .large
            }
            navigationPath.append(station)
            
        case .busStop(let stop):
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                position = .camera(MapCamera(centerCoordinate: stop.coordinate, distance: 1000))
                sheetSelection = .large
            }
            navigationPath.append(stop)
        }
    }
}
