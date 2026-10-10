//
//  TransitMapManager.swift
//  Railtime
//
//  Created by Kai Quan Tay on 10/10/26.
//

import SwiftUI
import MapKit
import LTAAPI
import Combine

class TransitMapManager: ObservableObject {
    var ltaService: LTAService
    var locationManager: LocationManager

    @Published var navigationPath: [TransitPathItem] = []
    @Published var sheetSelection: PresentationDetent = .fraction(0.25)
    @Published var selectedTransitItem: TransitPathItem? = nil

    // Smooth camera state with debounced map center tracking to prevent 120Hz view re-evaluation
    @Published var position: MapCameraPosition = .automatic

    // User Settings AppStorage
    // TODO: figure out an elegant solution that doesn't disable observability
    @ObservationIgnored @AppStorage("mrtZoomThreshold") private var mrtZoomThreshold: Int = 1
    @ObservationIgnored @AppStorage("busStopsZoomThreshold") private var busStopsZoomThreshold: Int = 40
    @ObservationIgnored @AppStorage("exitsZoomThreshold") private var exitsZoomThreshold: Int = 60
    @ObservationIgnored @AppStorage("colorSchemeMode") private var colorSchemeMode: String = "system"

    private var cameraDebounceTask: Task<Void, Never>? = nil
    private var zoomHideTask: Task<Void, Never>? = nil

    init(
        ltaService: LTAService,
        locationManager: LocationManager
    ) {
        self.ltaService = ltaService
        self.locationManager = locationManager

        updateProperties()
    }

    var preferredColorScheme: ColorScheme? {
        switch colorSchemeMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    // MARK: Camera position
    /// Effective center: user location or map camera center fallback
    @Published private(set) var effectiveCenter: CLLocationCoordinate2D!
    /// Whether the map has centered on the user's position
    @Published private(set) var hasCenteredOnUser: Bool = false
    /// The current distance of the camera above the gground
    @Published private(set) var currentCameraDistance: Double = 1800
    /// If the camera's initial position has settled
    @Published private(set) var hasInitialCameraSettled: Bool = false
    /// The current zoom percentage
    @Published private(set) var currentZoomPercent: Int = 0
    /// Whether the ui is currently zooming
    @Published private(set) var isZooming: Bool = false

    // MARK: Map details
    // Threshold 1: MRT / LRT stations shown at zoom >= mrtZoomThreshold%
    @Published private(set) var showMRTStations: Bool = false
    // Threshold 2: Bus stops shown at zoom >= busStopsZoomThreshold%
    @Published private(set) var showBusStops: Bool = false
    // Threshold 3: Station exit indicators shown at zoom >= exitsZoomThreshold%
    @Published private(set) var showExitIndicators: Bool = false
    // Dynamic scale for map station caplets based on zoom percentage (0.50x to 1.15x)
    @Published private(set) var stationCapletScale: CGFloat = 1.0
    // Dynamic scale for station exit icons and bus stop badges based on zoom percentage (0.45x to 1.15x)
    @Published private(set) var detailIconScale: CGFloat = 1.0
    // Bounding box filter for nearby bus stops (~1.5km) to prevent frame drops when panning
    @Published private(set) var sortedBusStops: [BusStop] = []

    func startup() async {
        async let a: () = ltaService.fetchTrainServiceAlerts()
        async let b: () = ltaService.fetchLiveBusStops()

        _ = await (a, b)
        updateProperties()
    }

    func updateCamera(context: MapCameraUpdateContext) {
        let newCenter = context.camera.centerCoordinate
        let newDistance = context.camera.distance

        Task { @MainActor in
            if self.hasInitialCameraSettled {
                if abs(newDistance - self.currentCameraDistance) > 1.0 {
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
            self.currentCameraDistance = newDistance
            updateProperties()

            // Debounce map updates by 1.5 seconds after panning stops
            guard cameraDebounceTask == nil else { return }

            self.cameraDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 0_200_000_000) // 5Hz
                if !Task.isCancelled {
                    await MainActor.run {
                        self.effectiveCenter = newCenter
                        self.cameraDebounceTask = nil
                        updateProperties()
                    }
                }
            }
        }
    }

    func updateLocation() {
        guard let userLoc = locationManager.userLocation, !hasCenteredOnUser else { return }
        // If user location is in Singapore, center map on user location
        guard userLoc.latitude > 1.1 && userLoc.latitude < 1.5 && userLoc.longitude > 103.5 && userLoc.longitude < 104.1 else { return }

        hasCenteredOnUser = true
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            position = .camera(MapCamera(centerCoordinate: userLoc, distance: 1800))
        }

        updateProperties()
    }

    func selectAndNavigateTo(item: TransitPathItem, atRoot: Bool = false) {
        if atRoot { navigationPath = [] }

        navigationPath.append(item)

        if let coordinate = item.coordinate {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                position = .camera(MapCamera(centerCoordinate: coordinate, distance: 1200))
                sheetSelection = .large
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

    private func updateProperties() {
        // Effective center: user location or map camera center fallback
        effectiveCenter = if let effectiveCenter {
            effectiveCenter
        } else {
            locationManager.userLocation ?? CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198)
        }

        currentZoomPercent = zoomPercentage(currentCameraDistance)

        // Threshold 1: MRT / LRT stations shown at zoom >= mrtZoomThreshold%
        showMRTStations = currentZoomPercent >= mrtZoomThreshold

        // Threshold 2: Bus stops shown at zoom >= busStopsZoomThreshold%
        showBusStops = currentZoomPercent >= busStopsZoomThreshold

        // Threshold 3: Station exit indicators shown at zoom >= exitsZoomThreshold%
        showExitIndicators = currentZoomPercent >= exitsZoomThreshold

        // Dynamic scale for map station caplets based on zoom percentage (0.50x to 1.15x)
        let pct = Double(currentZoomPercent) / 100.0
        stationCapletScale = CGFloat(0.50 + (pct * 0.65))

        // Dynamic scale for station exit icons and bus stop badges based on zoom percentage (0.45x to 1.15x)
        detailIconScale = CGFloat(0.45 + (pct * 0.70))

        // Bounding box filter for nearby bus stops (~1.5km) to prevent frame drops when panning

        // 33437m = 0.083 deg
        let center = effectiveCenter
        let visibleDelta = currentCameraDistance * 0.083 / 33437
        // the precision is rounded to the nearest order of magnitude
        // tho its in terms of e instead of 10
        let precision = exp(log(visibleDelta / 10).rounded(.towardZero))
        let nearby = ltaService.spatialIndex.stops(
            around: center!,
            visibleDelta: visibleDelta,
            precision: showBusStops ? 0 : precision
        )
        sortedBusStops = nearby
            .map { (dist: $0.distance(from: center) ?? Double.infinity, item: $0) }
            .sorted { $0.dist < $1.dist }
            .map { $0.item }
    }
}
