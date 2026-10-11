//
//  TransitAnnotation.swift
//  Railtime
//
//  Created by Kai Quan Tay on 11/10/26.
//

import MapKit
import LTAAPI

protocol MKAnnotationStructProtocol: Hashable {
    var coordinate: CLLocationCoordinate2D { get }
    var title: String? { get }
    var subtitle: String? { get }
}
extension LTABusStopInfo: MKAnnotationStructProtocol {
    var title: String? { self.name }
    var subtitle: String? { nil }
}
extension LTATrainStopInfo: MKAnnotationStructProtocol {
    var title: String? { self.name }
    var subtitle: String? { nil }
}
extension LTATrainStopInfo.Exit: MKAnnotationStructProtocol {
    var title: String? { self.code }
    var subtitle: String? { nil }
}

class TransitAnnotation: NSObject, MKAnnotation {
    var underlying: any MKAnnotationStructProtocol

    init(_ underlying: any MKAnnotationStructProtocol) {
        self.underlying = underlying
    }

    var coordinate: CLLocationCoordinate2D { underlying.coordinate }
    var title: String? { underlying.title }
    var subtitle: String? { underlying.subtitle }
}

final class TrainLineOverlay: MKPolyline {
    var code: String!
    var color: UIColor!
}

struct BusRouteDisplay {
    /// The service number of this bus
    var serviceNo: String
    /// The direction of this bus (1 or 2)
    var direction: Int
    /// The stops that the bus has already travelled. This includes the current stop as the last element so that everything connects.
    var prevStops: [LTABusRouteRow]
    /// The information about the stops that the bus has already travelled
    var prevStopsInfo: [LTABusStopInfo]
    /// The stops that this bus is yet to travel
    var nextStops: [LTABusRouteRow]
    /// The information about the stops that the bus has yet to travel to
    var nextStopsInfo: [LTABusStopInfo]
}

final class BusLineOverlay: MKPolyline {
    var serviceNo: String!
    var hasPassed: Bool!
}
