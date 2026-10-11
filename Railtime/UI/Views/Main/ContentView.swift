import SwiftUI
import MapKit
import LTAAPI
import Combine

// MARK: - Main Content View (Interactive Map with Custom Pins)

struct ContentView: View {
    @ObservedObject var manager: TransitMapManager

    var updateTimer = Timer.publish(every: 1/4, on: .main, in: .default).autoconnect()

    var body: some View {
        ZStack(alignment: .topLeading) {
            UIKitMapView(
                controller: manager.mapController,
                showsUserLocation: true,
                showsCompass: true,
                pointOfInterestFilter: .excludingAll,
                continuousCameraUpdate: true
            ) { context in
                manager.updateCamera(camera: context.camera)
            } annotationViewProvider: { mapView, annotation in
                guard let annotation = annotation as? TransitAnnotation else { return nil }
                mapView.register(HostingAnnotationView.self, forAnnotationViewWithReuseIdentifier: "HOSTING_ANNOTATION_VIEW_MRT")
                mapView.register(HostingAnnotationView.self, forAnnotationViewWithReuseIdentifier: "HOSTING_ANNOTATION_VIEW_BUS")
                mapView.register(HostingAnnotationView.self, forAnnotationViewWithReuseIdentifier: "HOSTING_ANNOTATION_VIEW_EXIT")

                var view: HostingAnnotationView?

                if let station = annotation.underlying as? LTATrainStopInfo {
                    view = mapView.dequeueReusableAnnotationView(
                        withIdentifier: "HOSTING_ANNOTATION_VIEW_MRT",
                        for: annotation
                    ) as? HostingAnnotationView

                    view!.configure(annotation: annotation) {
                        TrainAnnotation(manager: manager, station: station)
                    }
                } else if let stop = annotation.underlying as? LTABusStopInfo {
                    view = mapView.dequeueReusableAnnotationView(
                        withIdentifier: "HOSTING_ANNOTATION_VIEW_BUS",
                        for: annotation
                    ) as? HostingAnnotationView

                    view!.configure(annotation: annotation) {
                        BusAnnotation(manager: manager, stop: stop)
                    }
                } else if let exit = annotation.underlying as? LTATrainStopInfo.Exit {
                    view = mapView.dequeueReusableAnnotationView(
                        withIdentifier: "HOSTING_ANNOTATION_VIEW_EXIT",
                        for: annotation
                    ) as? HostingAnnotationView

                    view!.configure(annotation: annotation) {
                        ExitAnnotation(manager: manager, exit: exit)
                    }
                }

                return view
            } overlayRendererProvider: { mapView, overlay in
                print("Requested overlay for \(overlay)")
                if let polyline = overlay as? TrainLineOverlay {
                    let renderer = MKPolylineRenderer(polyline: polyline)
                    renderer.strokeColor = polyline.color
                    renderer.lineWidth = 5
                    renderer.lineCap = .round
                    renderer.lineJoin = .round
                    return renderer
                } else if let polyline = overlay as? BusLineOverlay {
                    let renderer = MKPolylineRenderer(polyline: polyline)
                    renderer.strokeColor = if polyline.hasPassed {
                        UIColor.gray.withAlphaComponent(0.5)
                    } else {
                        UIColor.green
                    }
                    renderer.lineWidth = 5
                    renderer.lineCap = .round
                    renderer.lineJoin = .round
                    return renderer
                } else {
                    return MKOverlayRenderer(overlay: overlay)
                }
            }
            .ignoresSafeArea(.all, edges: .all)

            // MARK: - Subtle Floating Zoom Level Indicator Badge (%) - Top Left (Active Zooming Only)
            if manager.isZooming {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    
                    Text("\(manager.currentZoomPercent)%")
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
        .preferredColorScheme(manager.preferredColorScheme)
        .sheet(isPresented: .constant(true)) {
            HomeView( // TODO: make HomeView also use TransitMapManager
                ltaService: manager.ltaService,
                locationManager: manager.locationManager,
                effectiveCenter: manager.effectiveCenter,
                navigationPath: $manager.navigationPath,
                onTapDistance: { coord, item in
                    manager.selectAndNavigateTo(item: item)
                }
            )
            .presentationBackgroundInteraction(.enabled)
            .presentationDetents([.fraction(0.25), .fraction(0.5), .large], selection: $manager.sheetSelection)
            .interactiveDismissDisabled()
            .presentationCornerRadius(24)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await manager.startup()
        }
        .onChange(of: manager.selectedTransitItem) { _, newItem in
            if let item = newItem {
                manager.selectAndNavigateTo(item: item, atRoot: true)
                manager.selectedTransitItem = nil
            }
        }
        // Center map on user location automatically when location updates at startup
        .onChange(of: manager.locationManager.userLocation?.latitude) { _, _ in
            manager.updateLocation()
        }
        .onChange(of: manager.navigationPath) { _, newValue in
            Task {
                do {
                    try await manager.updateForCurrentSelection()
                } catch {
                    print("ERROR UPDATING SELECTION: \(error)")
                }
            }
        }
        .onReceive(updateTimer) { _ in
            manager.updateAnnotations()
        }
    }
}
