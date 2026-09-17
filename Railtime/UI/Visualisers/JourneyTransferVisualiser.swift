//
//  JourneyTransferVisualiser.swift
//  Railtime
//
//  Created by Kai Quan Tay on 17/9/26.
//

import SwiftUI
import Journey
import BusEstimation
import LTAAPI

/// The visualiser responsible for drawing alternative transfers. This looks similar to the start node of a JourneyPathItemVisualiser, but only draws the other busses.
struct JourneyTransferVisualiser<Leg>: View where Leg: JourneyLeg, Leg.Context: JourneyStopBasedLegContext {
    typealias LegStopArrivalEstimates = StopArrivalEstimates<Leg.Context.ArrivalEstimate>

    /// The context for this leg
    var context: Leg.Context

    /// The current size of the viewport, which includes the stop line and tt graph, but
    /// excludes the time tickers
    var geometrySize: CGSize
    /// the current date/time
    var now: Date

    /// Number of points of spacing per minute, vertically
    var verticalScale: CGFloat
    /// Number of points of spacing per minute, horizontally
    var horizontalScale: CGFloat

    /// The horizontal offset to allow the first vehicle to be at firstBusHorizontalOffset.
    /// By first vehicle, this refers to the first vehicle *of the first leg*, therefore this is
    /// a parameter and not calculated by the view
    var vehicleHOffset: CGFloat

    /// The animation namespace
    var namespace: Namespace.ID

    init(
        context: Leg.Context,
        geometrySize: CGSize,
        now: Date,
        verticalScale: CGFloat,
        horizontalScale: CGFloat,
        vehicleHOffset: CGFloat,
        namespace: Namespace.ID
    ) {
        self.context = context
        self.geometrySize = geometrySize
        self.now = now
        self.verticalScale = verticalScale
        self.horizontalScale = horizontalScale
        self.vehicleHOffset = vehicleHOffset
        self.namespace = namespace
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // space for the stop line
            Spacer()
                .frame(width: Sizing.stopLineAndLabelsWidth, height: 1)
            if let stopEstimate = context.stopEstimations.first {
                ttGraph(stopEstimate: stopEstimate)
            } else {
                Spacer()
            }
        }
    }

    @ViewBuilder
    func ttGraph(stopEstimate: LegStopArrivalEstimates) -> some View {
        // tt graph
        ZStack(alignment: .topLeading) {
            // make sure there is enough space to actually see everything
            Rectangle()
                .fill(Color.clear)
                .frame(
                    width: (
                        // the location of the last vehicle, if any (treat as 0 if we have none)
                        ((stopEstimate.estimates.last?.eta.timeDelta(since: now).seconds ?? 0)
                         / 60 * horizontalScale) + vehicleHOffset
                        // plus enough space that the last vehicle can be moved to the very left
                        + geometrySize.width - Sizing.stopLineAndLabelsWidth - Sizing.firstBusHorizontalOffset,
                    ),
                    height: 1
                )

            // line for each vehicle
            ForEach(stopEstimate.estimates.enumerated(), id: \.offset) { (_, vehicleEstimate) in
                let etaFromNow = vehicleEstimate.eta.timeDelta(since: now)
                let horizontalOffset = ( // 1st is regular time offset, 2nd is to align
                    (etaFromNow.seconds / 60 * horizontalScale) +
                    vehicleHOffset
                )

                let fillColor: Color = Color.secondary

                // vehicle service label
                Text(vehicleEstimate.displayText)
                    .lineLimit(1)
                    .font(.caption)
                    .foregroundStyle(Color.white)
                    .padding(3)
                    .background {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(fillColor)
                    }
                    .matchedGeometryEffect(id: "\(vehicleEstimate.displayText)\(vehicleEstimate.id)", in: namespace)
                    .frame(
                        width: Sizing.firstBusHorizontalOffset * 2,
                        height: Sizing.firstStopVerticalOffset * 2
                    ) // horizontally and vertically center
                    .padding(.leading, horizontalOffset - Sizing.firstBusHorizontalOffset) // position
            }
        }
        .mask {
            Rectangle()
        }
    }
}
