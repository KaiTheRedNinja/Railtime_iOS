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
                mapView.register(HostingAnnotationView.self, forAnnotationViewWithReuseIdentifier: "HOSTING_ANNOTATION_VIEW")

                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: "HOSTING_ANNOTATION_VIEW",
                    for: annotation
                ) as! HostingAnnotationView

                if let station = annotation.underlying as? LTATrainStopInfo {
                    view.configure(annotation: annotation) {
                        TrainAnnotation(manager: manager, station: station)
                    }
                } else if let stop = annotation.underlying as? LTABusStopInfo {
                    view.configure(annotation: annotation) {
                        BusAnnotation(manager: manager, stop: stop)
                    }
                } else if let exit = annotation.underlying as? LTATrainStopInfo.Exit {
                    view.configure(annotation: annotation) {
                        ExitAnnotation(manager: manager, exit: exit)
                    }
                }

                return view
            } overlayRendererProvider: { mapView, overlay in
                print("Requested overlay for \(overlay)")
                return MKOverlayRenderer(overlay: overlay)
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
            // TODO: update the current UI
        }
        .overlay(alignment: .topLeading) {
            let text: String = [manager.showMRTStations, manager.showBusStops, manager.showExitIndicators]
                .map { $0 ? "Y" : "N"}
                .joined(separator: " ")

            Text(text)
                .background {
                    Color.blue
                }
        }
        .onReceive(updateTimer) { _ in
            manager.updateAnnotations()
        }
    }

    @MapContentBuilder
    var mrtAnnotations: some MapContent {
        // Note that even though mrt routes have IDs, some show up multiple times (LRTs for example)
        ForEach(manager.ltaService.allMRTRoutes.enumerated(), id: \.offset) { (_, routes) in
            ForEach(routes.uniqueRoutes.enumerated(), id: \.offset) { (_, route) in
                MapPolyline(
                    coordinates: route.compactMap { manager.ltaService.allStationsById[$0]?.coordinate},
                    contourStyle: .geodesic
                )
                .stroke(Color(rgb: routes.color, fallback: .gray), style: .init(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
        }

        ForEach(manager.ltaService.allStations) { station in
            // Render Station Exit custom icons on map (Zoom >= exitsZoomThreshold%)
            if manager.showExitIndicators {
                ForEach(Array(station.exits.enumerated()), id: \.element.code) { index, exit in
                    let exitCoord = exit.coordinate(for: station, index: index, total: station.exits.count)
                    Annotation("", coordinate: exitCoord) {
                        StationExitIconView(exitCode: exit.code, size: 24)
                            .scaleEffect(manager.detailIconScale)
                            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.85), value: manager.detailIconScale)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .onTapGesture {
                                manager.selectAndNavigateTo(item: .trainStop(station), atRoot: true)
                            }
                    }
                    .tag("\(station.id)_exit_\(exit.code)")
                }
            }

            if manager.showMRTStations {
                Annotation(station.name, coordinate: station.coordinate) {
                    StationCodeCapletView(station: station)
                        .scaleEffect(manager.stationCapletScale)
                        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.85), value: manager.stationCapletScale)
                        .onTapGesture {
                            manager.selectAndNavigateTo(item: .trainStop(station), atRoot: true)
                        }
                }
                .tag(TransitPathItem.trainStop(station))
            } else {
                Annotation(station.name, coordinate: station.coordinate) {
                    StationCodeMiniCapletView(station: station)
                        .scaleEffect(manager.stationCapletScale)
                        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.85), value: manager.stationCapletScale)
                        .onTapGesture {
                            manager.selectAndNavigateTo(item: .trainStop(station), atRoot: true)
                        }
                }
                .tag(TransitPathItem.trainStop(station))
            }
        }
    }

    @MapContentBuilder
    var busAnnotations: some MapContent {
        // Render Bus Stops on Map (Zoom >= busStopsZoomThreshold%)
        if manager.showBusStops {
            ForEach(manager.sortedBusStops) { stop in
                Annotation(stop.name, coordinate: stop.coordinate) {
                    Image(stop.iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .padding(5)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                        .scaleEffect(manager.detailIconScale)
                        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.85), value: manager.detailIconScale)
                        .contentShape(Circle())
                        .onTapGesture {
                            manager.selectAndNavigateTo(item: .busStop(stop), atRoot: true)
                        }
                }
                .tag(TransitPathItem.busStop(stop))
            }
        } else if manager.showMRTStations {
            ForEach(manager.sortedBusStops) { stop in
                Annotation(stop.name, coordinate: stop.coordinate) {
                    Circle()
                        .foregroundStyle(.blue)
                        .frame(width: 10, height: 10)
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                        .scaleEffect(manager.detailIconScale)
                        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.85), value: manager.detailIconScale)
                        .onTapGesture {
                            manager.selectAndNavigateTo(item: .busStop(stop), atRoot: true)
                        }
                }
                .tag(TransitPathItem.busStop(stop))
                .annotationTitles(.hidden)
            }
        }
    }
}

extension Color {
    init(rgb hexString: String, fallback: Color = .clear) {
        let hex = hexString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard hex.count == 6,
              let value = UInt64(hex, radix: 16) else {
            self = fallback
            return
        }

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0

        self = Color(red: red, green: green, blue: blue)
    }
}

struct TrainAnnotation: View {
    @ObservedObject var manager: TransitMapManager
    let station: LTATrainStopInfo

    var body: some View {
        Group {
            if manager.showMRTStations {
                StationCodeCapletView(station: station)
            } else {
                StationCodeMiniCapletView(station: station)
            }
        }
        .scaleEffect(manager.stationCapletScale)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.85), value: manager.stationCapletScale)
        .onTapGesture {
            manager.selectAndNavigateTo(item: .trainStop(station), atRoot: true)
        }
    }
}

struct BusAnnotation: View {
    @ObservedObject var manager: TransitMapManager
    let stop: LTABusStopInfo

    var body: some View {
        Group {
            if manager.showBusStops {
                Image(stop.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .padding(5)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                    .contentShape(Circle())
            } else if manager.showMRTStations {
                Circle()
                    .foregroundStyle(.blue)
                    .frame(width: 10, height: 10)
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
            }
        }
        .scaleEffect(manager.detailIconScale)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.85), value: manager.detailIconScale)
        .onTapGesture {
            manager.selectAndNavigateTo(item: .busStop(stop), atRoot: true)
        }
    }
}

struct ExitAnnotation: View {
    @ObservedObject var manager: TransitMapManager
    let exit: LTATrainStopInfo.Exit

    var body: some View {
        StationExitIconView(exitCode: exit.code, size: 24)
            .scaleEffect(manager.detailIconScale)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.85), value: manager.detailIconScale)
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            .onTapGesture {
                // TODO: make this work
//                manager.selectAndNavigateTo(item: .trainStop(station), atRoot: true)
            }
    }
}
