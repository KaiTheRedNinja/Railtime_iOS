//
//  TransitMapManager+Update.swift
//  Railtime
//
//  Created by Kai Quan Tay on 11/10/26.
//

import SwiftUI
import MapKit
import LTAAPI
import Combine

extension TransitMapManager {
    func updateCamera(camera: MKMapCamera) {
        let newCenter = camera.centerCoordinate
        let newDistance = camera.centerCoordinateDistance

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
            //            updateProperties()

            // Debounce map updates by 1.5 seconds after panning stops
            //            guard cameraDebounceTask == nil else { return }
            //
            //            self.cameraDebounceTask = Task {
            //                try? await Task.sleep(nanoseconds: 0_200_000_000) // 5Hz
            //                if !Task.isCancelled {
            //                    await MainActor.run {
            self.effectiveCenter = newCenter
            self.cameraDebounceTask = nil
            updateProperties()
            //                    }
            //                }
            //            }
        }
    }

    func updateLocation() {
        guard let userLoc = locationManager.userLocation, !hasCenteredOnUser else { return }
        // If user location is in Singapore, center map on user location
        guard userLoc.latitude > 1.1 && userLoc.latitude < 1.5 && userLoc.longitude > 103.5 && userLoc.longitude < 104.1 else { return }

        hasCenteredOnUser = true
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            position = .camera(MapCamera(centerCoordinate: userLoc, distance: 1800))
            mapController.setCamera(.init(lookingAtCenter: userLoc, fromDistance: 1800, pitch: 0, heading: 0))
        }

        updateProperties()
    }

    func selectAndNavigateTo(item: TransitPathItem, atRoot: Bool = false) {
        if atRoot { navigationPath = [] }

        navigationPath.append(item)

        if let coordinate = item.coordinate {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                position = .camera(MapCamera(centerCoordinate: coordinate, distance: 1200))
                mapController.setCamera(.init(lookingAtCenter: coordinate, fromDistance: 1200, pitch: 0, heading: 0))
                sheetSelection = .large
            }
        }
    }

    internal func zoomPercentage(_ distance: Double) -> Int {
        let minDist = 200.0   // 100% zoomed in
        let maxDist = 50000.0 // 0% zoomed out
        let clamped = max(minDist, min(maxDist, distance))
        let logMin = log(minDist)
        let logMax = log(maxDist)
        let fraction = 1.0 - ((log(clamped) - logMin) / (logMax - logMin))
        let percentage = Int((fraction * 100.0).rounded())
        return max(0, min(100, percentage))
    }

    internal func updateProperties() {
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
        if showMRTStations {
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
        } else {
            sortedBusStops = []
        }
    }

    func updateAnnotations() {
        var newAnnotations: [AnyHashable: any MKAnnotation] = [:]
        for station in ltaService.allStations {
            let key = AnyHashable(station)
            if let existing = annotationObjects[key] {
                newAnnotations[key] = existing
            } else {
                newAnnotations[key] = TransitAnnotation(station)
            }

            if showExitIndicators {
                for exit in station.exits {
                    let key = AnyHashable(exit)
                    if let existing = annotationObjects[key] {
                        newAnnotations[key] = existing
                    } else {
                        newAnnotations[key] = TransitAnnotation(exit)
                    }
                }
            }
        }
        if showMRTStations {
            for stop in sortedBusStops {
                let key = AnyHashable(stop)
                if let existing = annotationObjects[key] {
                    newAnnotations[key] = existing
                } else {
                    newAnnotations[key] = TransitAnnotation(stop)
                }
            }
        }

        self.annotationObjects = newAnnotations
        mapController.setAnnotations(newAnnotations.values)

        var newOverlays: [AnyHashable: any MKOverlay] = [:]
        for routes in ltaService.allMRTRoutes {
            for uniqueRoute in routes.uniqueRoutes {
                let key = AnyHashable(uniqueRoute)

                if let existing = overlayObjects[key] {
                    newOverlays[key] = existing
                } else {
                    let points = uniqueRoute.compactMap { ltaService.allStationsById[$0]?.coordinate}
                    let overlay = TrainLineOverlay(coordinates: points, count: points.count)
                    overlay.code = routes.code
                    overlay.color = UIColor(rgb: routes.color, fallback: .gray)
                    newOverlays[key] = overlay
                }
            }
        }

        self.overlayObjects = newOverlays
        mapController.setOverlays(newOverlays.values)
    }
}
