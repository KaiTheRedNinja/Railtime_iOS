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
