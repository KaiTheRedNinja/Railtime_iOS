//
//  BusJourneyView.swift
//  Railtime
//
//  Created by Kai Quan Tay on 10/9/26.
//

import SwiftUI

struct BusJourneyView: View {
    var estimates: [StopArrivalEstimates]
    var stopLookup: [String: LTABusStopInfo] = [:]

    // Number of points of spacing per minute, vertically
    var verticalScale: CGFloat = 10
    // Number of points of spacing per minute, horizontally. This value should never be larger than verticalScale
    var horizontalScale: CGFloat = 10

    var body: some View {
        
    }
}
