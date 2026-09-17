//
//  JourneyWalkVisualiser.swift
//  Railtime
//
//  Created by Kai Quan Tay on 17/9/26.
//

import SwiftUI
import Journey
import LTAAPI

/// The visualiser responsible for drawing the stop line and vertical view
struct JourneyWalkVisualiser: View {
    /// The context for this leg
    var context: JourneyWalkLeg.Context

    /// The current size of the viewport, which includes the stop line and tt graph, but
    /// excludes the time tickers
    var geometrySize: CGSize
    /// The current scroll position from the scroll view. We can operate on the assumption that this segment is
    /// located at (0, 0) - the caller will adjust `scrollPosition` as required.
    var scrollPosition: CGPoint
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
        context: JourneyWalkLeg.Context,
        geometrySize: CGSize,
        scrollPosition: CGPoint,
        now: Date,
        verticalScale: CGFloat,
        horizontalScale: CGFloat,
        vehicleHOffset: CGFloat,
        namespace: Namespace.ID
    ) {
        self.context = context
        self.geometrySize = geometrySize
        self.scrollPosition = scrollPosition
        self.now = now
        self.verticalScale = verticalScale
        self.horizontalScale = horizontalScale
        self.vehicleHOffset = vehicleHOffset
        self.namespace = namespace
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            stopLine()
            ttGraph()
        }
    }

    func stopLine() -> some View {
        ZStack(alignment: .topLeading) {
            let fillColor = Color.gray

            // stop line
            Capsule()
                .fill(fillColor)
                .frame(
                    width: Sizing.stopLineWidth,
                    height: Sizing.collapsedVerticalDistance + Sizing.stopLineWidth
                )
                .padding(.top, -Sizing.stopLineWidth/2 + Sizing.firstStopVerticalOffset)
                .padding(.leading, -Sizing.stopLineWidth/2 + Sizing.stopsHorizontalOffset)

            // stop indicators are not nescessary

            ZStack(alignment: .leading) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(String(format: "%.1f", context.estimatedDistance) + " km")
                        .font(.caption)
                        .padding(5)
                        .background {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.gray, lineWidth: 1)
                        }

                    Text("\(Int((context.walkTime.seconds / 60).rounded(.awayFromZero))) mins")
                        .font(.caption)
                        .padding(.horizontal, 5)
                }
                .padding(.leading, Sizing.stopsHorizontalOffset + Sizing.stopIndicatorDiameter/2 + 5)

                VStack(spacing: Sizing.stopLineWidth/2) {
                    ForEach(0..<3) { _ in
                        Circle()
                            .fill(Color.white)
                            .frame(width: Sizing.stopLineWidth/2, height: Sizing.stopLineWidth/2)
                    }
                }
                .padding(.leading, Sizing.stopsHorizontalOffset - Sizing.stopLineWidth/4)
            }
            .frame(height: Sizing.collapsedVerticalDistance)
            .padding(.top, Sizing.firstStopVerticalOffset)
        }
        .frame(width: Sizing.stopLineAndLabelsWidth, alignment: .leading)
        .background {
            Color.white.opacity(0.001) // for the hitbox
        }
        .offset(x: scrollPosition.x)
        .zIndex(2)
    }

    @ViewBuilder
    func ttGraph() -> some View {
        // tt graph
        ZStack(alignment: .topLeading) {
            // make sure there is enough space to actually see everything
            Rectangle()
                .fill(Color.clear)
                .frame(
                    width: max(0, geometrySize.width - Sizing.stopLineAndLabelsWidth - Sizing.firstBusHorizontalOffset),
                    height: 1
                )

            // vertical line, this one doesn't move because walking is independent
            let fillColor: Color = Color.gray
            VStack(alignment: .leading, spacing: 0) {
                Rectangle()
                    .fill(fillColor)
                    .frame(minHeight: 0)
            }
            .frame(
                width: 1,
                height: Sizing.collapsedVerticalDistance
            )
            .padding(.leading, vehicleHOffset)
            .padding(.top, Sizing.firstStopVerticalOffset)

            // walking label
            Image(systemName: "figure.walk")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.white)
                .padding(3)
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(fillColor)
                }
                .frame(
                    width: Sizing.firstBusHorizontalOffset * 2,
                    height: Sizing.collapsedVerticalDistance
                )
                .padding(.leading, vehicleHOffset - Sizing.firstBusHorizontalOffset + scrollPosition.x) // position
        }
        .mask {
            Rectangle()
                .offset(x: scrollPosition.x)
        }
    }
}
