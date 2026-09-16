//
//  JourneyBusSegmentVisualiser.swift
//  Railtime
//
//  Created by Kai Quan Tay on 13/9/26.
//

import SwiftUI
import Journey
import BusEstimation
import LTAAPI

/// The visualiser responsible for drawing the stop line and vertical view
struct JourneyBusSegmentVisualiser: View {
    /// The context for this bus leg
    var busContext: JourneyBusLeg.Context
    /// The lookup dictionary for stops
    var stopLookup: [String: any JourneyNodeContext] = [:]

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

    /// The horizontal offset to allow the first bus to be at firstBusHorizontalOffset.
    /// By first bus, this refers to the first bus *of the first leg*, therefore this is
    /// a parameter and not calculated by the view
    var busHOffset: CGFloat

    /// Whether or not the view is collapsed, binding to an external source
    @Binding var isCollapsedExt: Bool

    /// Whether or not we render this segment as "effectively collapsed", either because it is collapsed
    /// or because no data is available.
    var treatAsCollapsed: Bool {
        isCollapsedExt || busContext.stopEstimations.isEmpty
    }

    /// The currently selected bus
    @State var selectedBusId: Int?

    /// The animation namespace
    var namespace: Namespace.ID

    init(
        busContext: JourneyBusLeg.Context,
        stopLookup: [String : any JourneyNodeContext],
        geometrySize: CGSize,
        scrollPosition: CGPoint,
        now: Date,
        verticalScale: CGFloat,
        horizontalScale: CGFloat,
        busHOffset: CGFloat,
        isCollapsedExt: Binding<Bool>,
        selectedBusId: Int? = nil,
        namespace: Namespace.ID
    ) {
        self.busContext = busContext
        self.stopLookup = stopLookup
        self.geometrySize = geometrySize
        self.scrollPosition = scrollPosition
        self.now = now
        self.verticalScale = verticalScale
        self.horizontalScale = horizontalScale
        self.busHOffset = busHOffset
        self._isCollapsedExt = isCollapsedExt
        self.selectedBusId = selectedBusId
        self.namespace = namespace
    }

    var body: some View {
        // first we need to determine how large (horizontally and vertically) we need to be.

        // the time difference between the first and last stop time delta (ie. distance)
        // we default to the collapsed height if no data is provided
        let stopTimeRange = if let lastEst = busContext.stopEstimations.last,
                               let firstEst = busContext.stopEstimations.first {
            lastEst.deltaTime - firstEst.deltaTime
        } else {
            TimeDelta.mins(Sizing.collapsedVerticalDistance / verticalScale)
        }

        let estimates = if busContext.stopEstimations.isEmpty {
            [
                busContext.stopEstimations.first ?? BusStopArrivalEstimates(
                    stopId: busContext.startCode,
                    deltaTime: TimeDelta.mins(-Sizing.collapsedVerticalDistance / verticalScale),
                    deltaError: .zero,
                    estimates: []
                ),
                busContext.stopEstimations.last ?? BusStopArrivalEstimates(
                    stopId: busContext.endCode,
                    deltaTime: .zero,
                    deltaError: .zero,
                    estimates: []
                )
            ]
        } else {
            busContext.stopEstimations
        }

        HStack(alignment: .top, spacing: 0) {
            stopLine(stopTimeRange: stopTimeRange, estimates: estimates)
            ttGraph(stopTimeRange: stopTimeRange, estimates: estimates)
        }
    }

    func stopLine(stopTimeRange: TimeDelta, estimates: [BusStopArrivalEstimates]) -> some View {
        ZStack(alignment: .topLeading) {
            // stop line
            Capsule()
                .fill(Color.green)
                .frame(
                    width: Sizing.stopLineWidth,
                    height: treatAsCollapsed
                    ? (Sizing.collapsedVerticalDistance + Sizing.stopLineWidth)
                    : (stopTimeRange.seconds / 60 * verticalScale + Sizing.stopLineWidth)
                )
                .padding(.top, -Sizing.stopLineWidth/2 + Sizing.firstStopVerticalOffset)
                .padding(.leading, -Sizing.stopLineWidth/2 + Sizing.stopsHorizontalOffset)

            // stop indicators
            ForEach(
                treatAsCollapsed ? [estimates.first!, estimates.last!] : busContext.stopEstimations,
                id: \.stopId
            ) { stopEstimate in
                let isStartOrEnd = stopEstimate.stopId == busContext.startCode || stopEstimate.stopId == busContext.endCode
                let indicatorDiameter = if isStartOrEnd {
                    Sizing.busIndicatorDiameter
                } else {
                    Sizing.stopIndicatorDiameter
                }

                HStack(alignment: .center, spacing: 5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: indicatorDiameter, height: indicatorDiameter)
                        .overlay {
                            if isStartOrEnd {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: Sizing.stopIndicatorDiameter, height: Sizing.stopIndicatorDiameter)
                            }
                        }

                    Text(
                        (stopLookup[stopEstimate.stopId] as? JourneyBusStopNode.Context)?
                            .description ?? stopEstimate.stopId
                    )
                    .font(.caption)
                    .truncationMode(.middle)
                    .lineLimit(1)
                }
                .frame(height: Sizing.firstStopVerticalOffset * 2)
                .padding(.leading, -indicatorDiameter/2 + Sizing.stopsHorizontalOffset)
                .padding(
                    .top,
                    treatAsCollapsed
                        ? (stopEstimate.stopId == estimates.first!.stopId ? 0 : Sizing.collapsedVerticalDistance)
                        : ((stopTimeRange + stopEstimate.deltaTime).seconds / 60 * verticalScale)
                )
            }

            // bus location indicator
            if !treatAsCollapsed {
                ForEach(estimates.first!.estimates.enumerated(), id: \.offset) { (_, busEstimate) in
                    let etaFromNow = busEstimate.eta.timeDelta(since: now)

                    let isSelected = selectedBusId != nil && selectedBusId == busEstimate.id.index
                    let fillColor: Color = isSelected ? Color.accentColor : Color.gray

                    // only show it if it would show up on the stopline
                    if etaFromNow < .zero && etaFromNow > stopTimeRange.scale(by: -1) {
                        HStack(alignment: .center, spacing: 5) {
                            Image(systemName: "bus")
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(fillColor)
                                .padding(2)
                                .background {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(Color.white)
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(Color.gray, lineWidth: 1)
                                    }
                                }
                                .frame(width: Sizing.busIndicatorDiameter, height: Sizing.busIndicatorDiameter)

                            Rectangle()
                                .fill(fillColor)
                                .frame(height: 1)
                        }
                        .frame(height: Sizing.firstStopVerticalOffset * 2)
                        .padding(.leading, -Sizing.busIndicatorDiameter/2 + Sizing.stopsHorizontalOffset)
                        .padding(.top, -etaFromNow.seconds / 60 * verticalScale)
                    }
                }
            }

            // collapse indicator, ONLY FOR ACTUAL COLLAPSES!
            if isCollapsedExt, !busContext.stopEstimations.isEmpty {
                ZStack(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(estimates.count-1) stops")
                            .font(.caption)
                            .padding(5)
                            .background {
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.gray, lineWidth: 1)
                            }

                        Text("\(Int((stopTimeRange.seconds / 60).rounded(.awayFromZero))) mins")
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
        }
        .frame(width: Sizing.stopLineAndLabelsWidth, alignment: .leading)
        .background {
            Color.white.opacity(0.001) // for the hitbox
        }
        .onTapGesture {
            withAnimation {
                if !busContext.stopEstimations.isEmpty {
                    isCollapsedExt.toggle()
                }
            }
        }
        .offset(x: scrollPosition.x)
        .zIndex(2)
    }

    @ViewBuilder
    func ttGraph(stopTimeRange: TimeDelta, estimates: [BusStopArrivalEstimates]) -> some View {
        // tt graph
        ZStack(alignment: .topLeading) {
            // make sure there is enough space to actually see everything
            Rectangle()
                .fill(Color.clear)
                .frame(
                    width: (
                        // the location of the last bus, if any (treat as 0 if we have none)
                        ((estimates.first?.estimates.last?.eta.timeDelta(since: now).seconds ?? 0)
                            / 60 * horizontalScale) + busHOffset
                        // plus enough space that the last bus can be moved to the very left
                        + geometrySize.width - Sizing.stopLineAndLabelsWidth - Sizing.firstBusHorizontalOffset,
                    ),
                    height: 1
                )

            ForEach(
                treatAsCollapsed ? [estimates.first!, estimates.last!] : estimates,
                id: \.stopId
            ) { stopEstimate in
                ZStack(alignment: .leading) {
                    // horizontal line for the stop
                    Rectangle()
                        .fill(Color.gray)
                        .frame(
                            width: max(100, geometrySize.width - Sizing.stopLineAndLabelsWidth),
                            height: 1
                        )
                        .offset(x: scrollPosition.x)

                    // bus indicators
                    ForEach(stopEstimate.estimates.enumerated(), id: \.offset) { (_, busEstimate) in
                        let etaFromNow = busEstimate.eta.timeDelta(since: now)

                        let isSelected = selectedBusId != nil && selectedBusId == busEstimate.id.index
                        let fillColor: Color = isSelected ? Color.accentColor : Color.gray

                        let horizontalOffset = ( // 1st is regular time offset, 2nd is to actually skew the time, 3rd to align
                            (etaFromNow.seconds / 60 * horizontalScale) -
                            ((stopTimeRange + stopEstimate.deltaTime).seconds / 60 * horizontalScale) +
                            busHOffset
                        )

                        if horizontalOffset >= 0, isSelected {
                            Text(TimeOfDay(date: busEstimate.eta).hhmm)
                                .font(.caption)
                                .foregroundStyle(etaFromNow > .zero ? Color.primary : Color.gray)
                                .opacity(etaFromNow > .zero ? 1 : 0.5)
                                .padding(3)
                                .background {
                                    if etaFromNow > .zero {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.white)
                                            .blur(radius: 3)
                                    }
                                }
                                .padding(1)
                                .frame(height: Sizing.firstStopVerticalOffset * 2, alignment: .bottomLeading)
                                .offset(y: -Sizing.firstStopVerticalOffset)
                                .padding(.leading, horizontalOffset)

                            let indicatorShape = switch busEstimate.source {
                            case .live: "circle.fill"
                            case .projected: "circle.circle.fill"
                            case .extrapolated: "circle"
                            }

                            Image(systemName: indicatorShape)
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(etaFromNow > .zero ? fillColor : Color.gray)
                                .opacity(etaFromNow > .zero ? 1 : 0.5)
                                .opacity(isSelected ? 1 : 0.5)
                                .frame(width: Sizing.stopIndicatorDiameter, height: Sizing.stopIndicatorDiameter)
                                .padding(.leading, -Sizing.stopIndicatorDiameter/2)
                                .padding(.leading, horizontalOffset)
                        }
                    }
                }
                .frame(height: Sizing.firstStopVerticalOffset * 2)
                .padding(
                    .top,
                    treatAsCollapsed
                        ? (stopEstimate.stopId == estimates.first!.stopId ? 0 : Sizing.collapsedVerticalDistance)
                        : ((stopTimeRange + stopEstimate.deltaTime).seconds / 60 * verticalScale)
                )
            }

            // line for each bus
            ForEach((estimates.first?.estimates ?? []).enumerated(), id: \.offset) { (_, busEstimate) in
                let etaFromNow = busEstimate.eta.timeDelta(since: now)
                let horizontalOffset = ( // 1st is regular time offset, 2nd is to align
                    (etaFromNow.seconds / 60 * horizontalScale) +
                    busHOffset
                )

                let isSelected = selectedBusId != nil && selectedBusId == busEstimate.id.index
                let fillColor: Color = isSelected ? Color.accentColor : Color.gray

                VStack(alignment: .leading, spacing: 0) {
                    if etaFromNow < .zero && !treatAsCollapsed {
                        Rectangle()
                            .fill(Color.gray) // TODO: consider if we want to do a sort of incremental fade for collapsed??
                            .frame(height: etaFromNow.seconds / 60 * verticalScale * -1)
                            .opacity(0.5)
                    }

                    Rectangle()
                        .fill(fillColor)
                        .frame(minHeight: 0)
                }
                .opacity(isSelected ? 1 : 0.5)
                .frame(
                    width: 1,
                    height: treatAsCollapsed ? Sizing.collapsedVerticalDistance : stopTimeRange.seconds / 60 * verticalScale
                )
                .padding(.leading, horizontalOffset)
                .padding(.top, Sizing.firstStopVerticalOffset)

                if !treatAsCollapsed, horizontalOffset > 0,
                   etaFromNow < .zero && etaFromNow > stopTimeRange.scale(by: -1) {
                    // only show the stop line connector if it would show up on the stopline
                    Rectangle()
                        .fill(fillColor)
                        .frame(width: horizontalOffset, height: 1)
                        .padding(.top, Sizing.firstStopVerticalOffset - etaFromNow.seconds / 60 * verticalScale)
                }

                // bus service label
                Text(busEstimate.busServiceNo)
                    .lineLimit(1)
                    .font(.caption)
                    .foregroundStyle(Color.white)
                    .padding(3)
                    .background {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(fillColor)
                    }
                    .opacity(isSelected ? 1 : 0.5)
                    .matchedGeometryEffect(id: "\(busEstimate.busServiceNo)\(busEstimate.id.description)", in: namespace)
                    .frame(
                        width: Sizing.firstBusHorizontalOffset * 2,
                        height: treatAsCollapsed ? nil : Sizing.firstStopVerticalOffset * 2
                    ) // horizontally (and vertically center, if not collapsed)
                    .onTapGesture {
                        if isSelected {
                            selectedBusId = nil
                        } else {
                            selectedBusId = busEstimate.id.index
                        }
                    }
                    .padding(.leading, horizontalOffset - Sizing.firstBusHorizontalOffset) // position
                    .padding(
                        .top,
                        treatAsCollapsed
                            ? (Sizing.firstStopVerticalOffset + Sizing.stopIndicatorDiameter)
                            : min(
                                stopTimeRange.seconds / 60 * verticalScale,
                                max(0,
                                    scrollPosition.y
                                )
                            )
                    ) // move with scroll, but only on the line
            }
        }
        .mask {
            Rectangle()
                .offset(x: scrollPosition.x)
        }
    }
}
