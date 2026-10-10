import SwiftUI
import MapKit
import Combine

// MARK: - UIKitMapView (SwiftUI wrapper around MKMapView)
public struct UIKitMapView: UIViewRepresentable {
    // Mirror SwiftUI Map's camera binding so existing state can be reused
    @Binding private var position: MapCameraPosition

    // Configuration
    private let showsUserLocation: Bool
    private let showsCompass: Bool
    private let pointOfInterestFilter: MKPointOfInterestFilter?

    // Controller (imperative API for bulk/efficient updates)
    public let controller: Controller

    // Callbacks & providers
    private let onCameraChange: ((CameraChangeContext) -> Void)?
    private let annotationViewProvider: ((MKMapView, MKAnnotation) -> MKAnnotationView?)?
    private let overlayRendererProvider: ((MKMapView, MKOverlay) -> MKOverlayRenderer)?

    // MARK: Init
    public init(
        position: Binding<MapCameraPosition>,
        controller: Controller = Controller(),
        showsUserLocation: Bool = true,
        showsCompass: Bool = true,
        pointOfInterestFilter: MKPointOfInterestFilter? = .excludingAll,
        onCameraChange: ((CameraChangeContext) -> Void)? = nil,
        annotationViewProvider: ((MKMapView, MKAnnotation) -> MKAnnotationView?)? = nil,
        overlayRendererProvider: ((MKMapView, MKOverlay) -> MKOverlayRenderer)? = nil
    ) {
        self._position = position
        self.controller = controller
        self.showsUserLocation = showsUserLocation
        self.showsCompass = showsCompass
        self.pointOfInterestFilter = pointOfInterestFilter
        self.onCameraChange = onCameraChange
        self.annotationViewProvider = annotationViewProvider
        self.overlayRendererProvider = overlayRendererProvider
    }

    // MARK: UIViewRepresentable
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = showsUserLocation
        mapView.showsCompass = showsCompass
        mapView.pointOfInterestFilter = pointOfInterestFilter
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true

        // Attach controller to mapView
        controller.attach(to: mapView,
                          annotationViewProvider: annotationViewProvider,
                          overlayRendererProvider: overlayRendererProvider)

        // Apply initial camera position
        context.coordinator.apply(position: position, to: mapView, animated: false)

        return mapView
    }

    public func updateUIView(_ mapView: MKMapView, context: Context) {
        // Keep simple: apply current configuration and camera position.
        // Coordinator guards against feedback loops when setting camera programmatically.
        if mapView.showsUserLocation != showsUserLocation {
            mapView.showsUserLocation = showsUserLocation
        }
        if mapView.showsCompass != showsCompass {
            mapView.showsCompass = showsCompass
        }
        if mapView.pointOfInterestFilter != pointOfInterestFilter {
            mapView.pointOfInterestFilter = pointOfInterestFilter
        }

        context.coordinator.apply(position: position, to: mapView, animated: false)
    }
}

// MARK: - Coordinator
public extension UIKitMapView {
    final class Coordinator: NSObject, MKMapViewDelegate {
        private let parent: UIKitMapView
        private var isProgrammaticCameraChange = false

        init(_ parent: UIKitMapView) {
            self.parent = parent
            super.init()
        }

        // Apply a SwiftUI MapCameraPosition to MKMapView
        func apply(position: MapCameraPosition, to mapView: MKMapView, animated: Bool) {
            isProgrammaticCameraChange = true
            if let region = position.region { mapView.setRegion(region, animated: animated) }
            if let camera = position.camera {
                mapView.setCamera(
                    .init(
                        lookingAtCenter: camera.centerCoordinate,
                        fromDistance: camera.distance,
                        pitch: camera.pitch,
                        heading: camera.heading
                    ),
                    animated: animated
                )
            }
            // Clear the programmatic flag on the next runloop to avoid suppressing legitimate user changes
            DispatchQueue.main.async { [weak self] in self?.isProgrammaticCameraChange = false }
        }

        // MARK: MKMapViewDelegate
        public func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            // No-op; we report after changes for parity with SwiftUI's .onMapCameraChange(.continuous)
        }

        public func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Update binding and notify callback
            if !isProgrammaticCameraChange {
                // Prefer camera to preserve pitch/heading
                let currentCamera = mapView.camera
                parent.controller.currentCamera = currentCamera
                parent.controller.currentRegion = mapView.region

                // Update the bound position so external state stays in sync
                parent._position.wrappedValue = .camera(
                    .init(
                        centerCoordinate: currentCamera.centerCoordinate,
                        distance: currentCamera.centerCoordinateDistance,
                        heading: currentCamera.heading,
                        pitch: currentCamera.pitch
                    )
                )

                let context = CameraChangeContext(region: mapView.region, camera: currentCamera, animated: animated)
                parent.onCameraChange?(context)
            }
        }

        // Annotation view provider
        public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Use provider if available; otherwise, default to nil (system pin)
            if let provider = parent.controller.annotationViewProvider ?? parent.annotationViewProvider {
                return provider(mapView, annotation)
            }
            return nil
        }

        // Overlay renderer provider
        public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let provider = parent.controller.overlayRendererProvider ?? parent.overlayRendererProvider {
                return provider(mapView, overlay)
            }
            // Sensible default for polylines
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.lineWidth = 5
                renderer.lineJoin = .round
                renderer.lineCap = .round
                renderer.strokeColor = .systemBlue
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        public func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let annotation = view.annotation {
                parent.controller.onAnnotationSelected?(annotation)
            }
        }
    }
}

// MARK: - Controller (imperative API)
public extension UIKitMapView {
    final class Controller: NSObject, ObservableObject {
        fileprivate weak var mapView: MKMapView?

        // Exposed state mirrors for convenience
        public var currentRegion: MKCoordinateRegion?
        public var currentCamera: MKMapCamera?

        // Providers & callbacks (can be changed at runtime if needed)
        fileprivate var annotationViewProvider: ((MKMapView, MKAnnotation) -> MKAnnotationView?)?
        fileprivate var overlayRendererProvider: ((MKMapView, MKOverlay) -> MKOverlayRenderer)?
        public var onAnnotationSelected: ((MKAnnotation) -> Void)?

        // Attach to a map view (called by the representable)
        fileprivate func attach(
            to mapView: MKMapView,
            annotationViewProvider: ((MKMapView, MKAnnotation) -> MKAnnotationView?)?,
            overlayRendererProvider: ((MKMapView, MKOverlay) -> MKOverlayRenderer)?
        ) {
            self.mapView = mapView
            self.annotationViewProvider = annotationViewProvider
            self.overlayRendererProvider = overlayRendererProvider
        }

        // MARK: Camera controls
        public func set(position: MapCameraPosition, animated: Bool = true) {
            guard let mapView else { return }
            if let region = position.region { mapView.setRegion(region, animated: animated) }
            if let camera = position.camera {
                mapView.setCamera(
                    .init(
                        lookingAtCenter: camera.centerCoordinate,
                        fromDistance: camera.distance,
                        pitch: camera.pitch,
                        heading: camera.heading
                    ),
                    animated: animated
                )
            }
        }

        public func setRegion(_ region: MKCoordinateRegion, animated: Bool = true) {
            mapView?.setRegion(region, animated: animated)
        }

        public func setCamera(_ camera: MKMapCamera, animated: Bool = true) {
            mapView?.setCamera(camera, animated: animated)
        }

        // MARK: Annotation management
        public func setAnnotations(_ annotations: [MKAnnotation], animated: Bool = false) {
            guard let mapView else { return }
            let existing = Set(mapView.annotations.compactMap { $0 as? NSObject })
            let incoming = Set(annotations.compactMap { $0 as? NSObject })

            // Remove annotations that are no longer present (excluding user location)
            let toRemove = existing.subtracting(incoming).compactMap { $0 as? MKAnnotation }.filter { !($0 is MKUserLocation) }
            let toAdd = incoming.subtracting(existing).compactMap { $0 as? MKAnnotation }

            if !toRemove.isEmpty { mapView.removeAnnotations(toRemove) }
            if !toAdd.isEmpty { mapView.addAnnotations(toAdd) }
        }

        public func addAnnotations(_ annotations: [MKAnnotation]) {
            mapView?.addAnnotations(annotations)
        }

        public func removeAnnotations(_ annotations: [MKAnnotation]) {
            mapView?.removeAnnotations(annotations)
        }

        public func removeAllAnnotations(excludingUser: Bool = true) {
            guard let mapView else { return }
            let toRemove = mapView.annotations.filter { excludingUser ? !($0 is MKUserLocation) : true }
            mapView.removeAnnotations(toRemove)
        }

        // MARK: Overlay management (e.g., polylines)
        public func setOverlays(_ overlays: [MKOverlay], level: MKOverlayLevel = .aboveRoads) {
//            let existing: [String: any MKOverlay] = mapView.overlays.map { $0 })
//            let incoming = Set(overlays.map { $0 })
//
//            let toRemove = existing.subtracting(incoming).map { $0 }
//            let toAdd = incoming.subtracting(existing).map { $0 }
//
//            if !toRemove.isEmpty { mapView.removeOverlays(toRemove) }
//            if !toAdd.isEmpty { mapView.addOverlays(toAdd, level: level) }
            removeAllOverlays()
            addOverlays(overlays, level: level)
        }

        public func addOverlays(_ overlays: [MKOverlay], level: MKOverlayLevel = .aboveRoads) {
            mapView?.addOverlays(overlays, level: level)
        }

        public func removeOverlays(_ overlays: [MKOverlay]) {
            mapView?.removeOverlays(overlays)
        }

        public func removeAllOverlays() {
            mapView?.removeOverlays(mapView?.overlays ?? [])
        }

        // MARK: Misc configuration
        public func setShowsUserLocation(_ shows: Bool) { mapView?.showsUserLocation = shows }
        public func setShowsCompass(_ shows: Bool) { mapView?.showsCompass = shows }
        public func setPointOfInterestFilter(_ filter: MKPointOfInterestFilter?) { mapView?.pointOfInterestFilter = filter }
    }
}

// MARK: - CameraChangeContext (parity with SwiftUI's onMapCameraChange)
public struct CameraChangeContext {
    public let region: MKCoordinateRegion
    public let camera: MKMapCamera
    public let animated: Bool
}

// MARK: - Convenience helpers
private extension Set where Element: NSObject {
    func map<T>(_ transform: (Element) -> T) -> Set<T> where T: Hashable { Set<T>(self.compactMap(transform)) }
}

// MARK: - Usage Example (for reference)
/*
 In ContentView, you can use UIKitMapView like this:

 @State private var position: MapCameraPosition = .userLocation
 @StateObject private var mapController = UIKitMapView.Controller()

 var body: some View {
     UIKitMapView(
         position: $position,
         controller: mapController,
         showsUserLocation: true,
         showsCompass: true,
         pointOfInterestFilter: .excludingAll,
         onCameraChange: { context in
             // Update your manager with context.region/context.camera
         },
         annotationViewProvider: { map, annotation in
             // Return custom MKAnnotationView if desired; return nil to use default pin
             return nil
         },
         overlayRendererProvider: { map, overlay in
             if let polyline = overlay as? MKPolyline {
                 let r = MKPolylineRenderer(polyline: polyline)
                 r.strokeColor = .systemBlue
                 r.lineWidth = 5
                 r.lineJoin = .round
                 r.lineCap = .round
                 return r
             }
             return MKOverlayRenderer(overlay: overlay)
         }
     )
     .ignoresSafeArea()
     .onAppear {
         // Example: add many annotations efficiently
         var annotations: [MKPointAnnotation] = []
         for i in 0..<1000 {
             let a = MKPointAnnotation()
             a.title = "Pin \(i)"
             a.coordinate = CLLocationCoordinate2D(latitude: 1.3 + Double(i) * 0.0001, longitude: 103.8)
             annotations.append(a)
         }
         mapController.setAnnotations(annotations)

         // Example: add a polyline
         let coords = [
             CLLocationCoordinate2D(latitude: 1.300, longitude: 103.800),
             CLLocationCoordinate2D(latitude: 1.310, longitude: 103.820),
             CLLocationCoordinate2D(latitude: 1.320, longitude: 103.830)
         ]
         let polyline = MKPolyline(coordinates: coords, count: coords.count)
         mapController.setOverlays([polyline])
     }
 }
*/
