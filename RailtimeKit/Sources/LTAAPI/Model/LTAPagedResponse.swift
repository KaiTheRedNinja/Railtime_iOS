//
//  LTAPagedResponse.swift
//  Railtime
//
//  Created by Kai Quan Tay on 5/9/26.
//

import Foundation

/// Generic wrapper for LTA DataMall's paginated `{"value": [...]}` envelope,
/// used by BusRoutes, BusServices, and BusStops.
public struct LTAPagedResponse<Value: Decodable>: Decodable {
    /// The page of records returned by the API.
    public let value: [Value]
}
