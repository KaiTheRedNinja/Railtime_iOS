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
    var mapController: UIKitMapView.Controller

    @Published var navigationPath: [TransitPathItem] = []
    @Published var sheetSelection: PresentationDetent = .fraction(0.25)
    @Published var selectedTransitItem: TransitPathItem? = nil

    // Smooth camera state with debounced map center tracking to prevent 120Hz view re-evaluation
    @Published var position: MapCameraPosition = .automatic

    // User Settings AppStorage
    // TODO: figure out an elegant solution that doesn't disable observability
    @ObservationIgnored @AppStorage("mrtZoomThreshold") internal var mrtZoomThreshold: Int = 1
    @ObservationIgnored @AppStorage("busStopsZoomThreshold") internal var busStopsZoomThreshold: Int = 40
    @ObservationIgnored @AppStorage("exitsZoomThreshold") internal var exitsZoomThreshold: Int = 60
    @ObservationIgnored @AppStorage("colorSchemeMode") internal var colorSchemeMode: String = "system"

    internal var cameraDebounceTask: Task<Void, Never>? = nil
    internal var zoomHideTask: Task<Void, Never>? = nil
    internal var annotationObjects: [AnyHashable: any MKAnnotation] = [:]
    internal var overlayObjects: [AnyHashable: any MKOverlay] = [:]

    init(
        ltaService: LTAService,
        locationManager: LocationManager
    ) {
        self.ltaService = ltaService
        self.locationManager = locationManager
        self.mapController = .init()

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
    @Published var effectiveCenter: CLLocationCoordinate2D!
    /// Whether the map has centered on the user's position
    @Published var hasCenteredOnUser: Bool = false
    /// The current distance of the camera above the gground
    @Published var currentCameraDistance: Double = 1800
    /// If the camera's initial position has settled
    @Published var hasInitialCameraSettled: Bool = false
    /// The current zoom percentage
    @Published var currentZoomPercent: Int = 0
    /// Whether the ui is currently zooming
    @Published var isZooming: Bool = false

    // MARK: Map details
    // Threshold 1: MRT / LRT stations shown at zoom >= mrtZoomThreshold%
    @Published var showMRTStations: Bool = false
    // Threshold 2: Bus stops shown at zoom >= busStopsZoomThreshold%
    @Published var showBusStops: Bool = false
    // Threshold 3: Station exit indicators shown at zoom >= exitsZoomThreshold%
    @Published var showExitIndicators: Bool = false
    // Dynamic scale for map station caplets based on zoom percentage (0.50x to 1.15x)
    @Published var stationCapletScale: CGFloat = 1.0
    // Dynamic scale for station exit icons and bus stop badges based on zoom percentage (0.45x to 1.15x)
    @Published var detailIconScale: CGFloat = 1.0
    // Bounding box filter for nearby bus stops (~1.5km) to prevent frame drops when panning
    @Published var sortedBusStops: [BusStop] = []

    func startup() async {
        async let a: () = ltaService.fetchTrainServiceAlerts()
        async let b: () = ltaService.fetchLiveBusStops()

        _ = await (a, b)
        updateProperties()
    }
}
