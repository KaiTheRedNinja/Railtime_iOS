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

@Observable
class TransitMapManager {
    @ObservationIgnored
    var ltaService: LTAService
    @ObservationIgnored
    var locationManager: LocationManager

    var navigationPath: [TransitPathItem] = []
    var sheetSelection: PresentationDetent = .fraction(0.25)
    var selectedTransitItem: TransitPathItem? = nil

    // Smooth camera state with debounced map center tracking to prevent 120Hz view re-evaluation
    var position: MapCameraPosition = .automatic
    var immediateMapCenter: CLLocationCoordinate2D? = nil
    var debouncedMapCenter: CLLocationCoordinate2D? = nil
    var cameraDebounceTask: Task<Void, Never>? = nil
    var hasCenteredOnUser: Bool = false

    var currentCameraDistance: Double = 1800
    var isZooming: Bool = false
    var hasInitialCameraSettled: Bool = false
    var zoomHideTask: Task<Void, Never>? = nil

    // User Settings AppStorage
    // TODO: figure out an elegant solution that doesn't disable observability
    @ObservationIgnored @AppStorage("mrtZoomThreshold") private var mrtZoomThreshold: Int = 1
    @ObservationIgnored @AppStorage("busStopsZoomThreshold") private var busStopsZoomThreshold: Int = 40
    @ObservationIgnored @AppStorage("exitsZoomThreshold") private var exitsZoomThreshold: Int = 60
    @ObservationIgnored @AppStorage("colorSchemeMode") private var colorSchemeMode: String = "system"

    init(
        ltaService: LTAService,
        locationManager: LocationManager
    ) {
        self.ltaService = ltaService
        self.locationManager = locationManager
    }

    var preferredColorScheme: ColorScheme? {
        switch colorSchemeMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    // Effective center: user location or map camera center fallback
    var effectiveCenter: CLLocationCoordinate2D {
        debouncedMapCenter ?? locationManager.userLocation ?? CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198)
    }

    var currentZoomPercent: Int {
        zoomPercentage(currentCameraDistance)
    }

    // Threshold 1: MRT / LRT stations shown at zoom >= mrtZoomThreshold%
    var showMRTStations: Bool { currentZoomPercent >= mrtZoomThreshold }

    // Threshold 2: Bus stops shown at zoom >= busStopsZoomThreshold%
    var showBusStops: Bool { currentZoomPercent >= busStopsZoomThreshold }

    // Threshold 3: Station exit indicators shown at zoom >= exitsZoomThreshold%
    var showExitIndicators: Bool { currentZoomPercent >= exitsZoomThreshold }

    // Dynamic scale for map station caplets based on zoom percentage (0.50x to 1.15x)
    var stationCapletScale: CGFloat {
        let pct = Double(currentZoomPercent) / 100.0
        let scale = 0.50 + (pct * 0.65)
        return CGFloat(scale)
    }

    // Dynamic scale for station exit icons and bus stop badges based on zoom percentage (0.45x to 1.15x)
    var detailIconScale: CGFloat {
        let pct = Double(currentZoomPercent) / 100.0
        let scale = 0.45 + (pct * 0.70)
        return CGFloat(scale)
    }

    // Bounding box filter for nearby bus stops (~1.5km) to prevent frame drops when panning
    var sortedBusStops: [BusStop] {
        // 33437m = 0.083 deg

        let center = effectiveCenter
        let visibleDelta = currentCameraDistance * 0.083 / 33437
        // the precision is rounded to the nearest order of magnitude
        // tho its in terms of e instead of 10
        let precision = exp(log(visibleDelta / 10).rounded(.towardZero))
        let nearby = ltaService.spatialIndex.stops(
            around: center,
            visibleDelta: visibleDelta,
            precision: showBusStops ? 0 : precision
        )
        return nearby
            .map { (dist: $0.distance(from: center) ?? Double.infinity, item: $0) }
            .sorted { $0.dist < $1.dist }
            .map { $0.item }
    }

    func startup() async {
        async let a: () = ltaService.fetchTrainServiceAlerts()
        async let b: () = ltaService.fetchLiveBusStops()

        _ = await (a, b)
    }

    func updateCamera(context: MapCameraUpdateContext) {
        let newCenter = context.camera.centerCoordinate
        let newDistance = context.camera.distance

        Task { @MainActor in
            self.immediateMapCenter = newCenter

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

            // Debounce map updates by 1.5 seconds after panning stops
            guard cameraDebounceTask == nil else { return }

            self.cameraDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 0_200_000_000) // 5Hz
                if !Task.isCancelled {
                    await MainActor.run {
                        self.debouncedMapCenter = newCenter
                        self.cameraDebounceTask = nil
                    }
                }
            }
        }
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

    }
}
