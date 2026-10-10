import SwiftUI
import MapKit
import LTAAPI
import Combine

// MARK: - Main Content View (Interactive Map with Custom Pins)

struct ContentView: View {
    @State var manager: TransitMapManager

    var body: some View {
        ZStack(alignment: .topLeading) {
            Map(position: $manager.position, selection: $manager.selectedTransitItem) {
                // Render MRT / LRT Stations on map (Zoom >= mrtZoomThreshold%)
                mrtAnnotations

                busAnnotations

                UserAnnotation()
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .onMapCameraChange(frequency: .continuous) { context in
                manager.updateCamera(context: context)
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            
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
            if let userLoc = manager.locationManager.userLocation, !manager.hasCenteredOnUser {
                // If user location is in Singapore, center map on user location
                if userLoc.latitude > 1.1 && userLoc.latitude < 1.5 && userLoc.longitude > 103.5 && userLoc.longitude < 104.1 {
                    manager.hasCenteredOnUser = true
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                        manager.position = .camera(MapCamera(centerCoordinate: userLoc, distance: 1800))
                    }
                }
            }
        }
        .onChange(of: manager.navigationPath) { _, newValue in
            // TODO: update the current UI
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

            Annotation(station.name, coordinate: station.coordinate) {
                if manager.showMRTStations {
                    StationCodeCapletView(station: station)
                        .scaleEffect(manager.stationCapletScale)
                        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.85), value: manager.stationCapletScale)
                        .onTapGesture {
                            manager.selectAndNavigateTo(item: .trainStop(station), atRoot: true)
                        }
                } else {
                    StationCodeMiniCapletView(station: station)
                        .scaleEffect(manager.stationCapletScale)
                        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.85), value: manager.stationCapletScale)
                        .onTapGesture {
                            manager.selectAndNavigateTo(item: .trainStop(station), atRoot: true)
                        }
                }
            }
            .tag(TransitPathItem.trainStop(station))
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
