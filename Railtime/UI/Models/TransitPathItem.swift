//
//  TransitPathItem.swift
//  Railtime
//
//  Created by Kai Quan Tay on 10/10/26.
//

import Foundation
import LTAAPI
import MapKit

enum TransitPathItem: Hashable {
    case busStop(LTABusStopInfo)
    case trainStop(LTATrainStopInfo)
    case busService(BusServiceDetail)

    var coordinate: CLLocationCoordinate2D? {
        switch self {
        case .busStop(let lTABusStopInfo): lTABusStopInfo.coordinate
        case .trainStop(let lTATrainStopInfo): lTATrainStopInfo.coordinate
        case .busService: nil
        }
    }
}

struct BusServiceDetail: Hashable {
    let serviceNo: String
    let originStopCode: String?
}
