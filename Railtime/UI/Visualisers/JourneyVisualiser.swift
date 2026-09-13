//
//  JourneyVisualiser.swift
//  Railtime
//
//  Created by Kai Quan Tay on 13/9/26.
//

import SwiftUI
import Combine

// the width of the vertical line showing the stops
private let stopLineWidth: CGFloat = 5
// the diameter of the circle used to indicate a stop in the stop line, or a bus in the tt graph
private let stopIndicatorDiameter: CGFloat = 10
// the diameter of the image used to indicate a bus on the stop line
private let busIndicatorDiameter: CGFloat = 16

// the width of the stop line + labels area
private let stopLineAndLabelsWidth: CGFloat = 100
// the height of the top section of the time ticker labels
private let timeTickerLabelsHeight: CGFloat = 20
// the width of the trailing section of the time ticker labels
private let timeTickerLabelsWidth: CGFloat = 30

// the vertical offset from the top of the screen to the center of the first stop
private let firstStopVerticalOffset: CGFloat = 20
// the horizontal offset from the left of the screen to the center of the stop line
private let stopsHorizontalOffset: CGFloat = 15
// the horizontal offset from the left of left of the tt graph to the center of the first bus
private let firstBusHorizontalOffset: CGFloat = 30

// the collapsed distance between the center of the first and last stops
private let collapsedVerticalDistance: CGFloat = 80

struct JourneyVisualiser: View {
    /// The journey that this view is for
    var journey: Journey
    /// The context for the journey
    var context: JourneyContext

    /// Number of points of spacing per minute, vertically
    var verticalScale: CGFloat = 40
    /// Number of points of spacing per minute, horizontally. This value should never be larger than verticalScale
    var horizontalScale: CGFloat = 10

    /// the current time
    @State var now: Date
    @State var nowRefreshTimer = Timer.publish(every: 0.1, on: .main, in: .default).autoconnect()

    /// the current scroll position from the scroll view
    @State var scrollPosition: CGPoint = .zero

    /// whether or not each segment is collapsed
    @State var isCollapsed: [UUID: Bool] = [:]

    /// The animation namespace
    @Namespace var namespace

    init(
        journey: Journey,
        context: JourneyContext,
        now: Date
    ) {
        self.journey = journey
        self.context = context
        self.now = now
    }

    @ViewBuilder
    var body: some View {
        let pageDescription: String = [
            (context.nodeContext[journey.startNode.id] as? JourneyBusStopNode.Context)?.description ?? "?",
            " to ",
            (context.nodeContext[journey.endNode.id] as? JourneyBusStopNode.Context)?.description ?? "?",
        ].joined(separator: "")

        let (yOffsetLegMap, timeDeltaTranslation, totalHeight) = yOffsetForLegs()

        let busHOffset = busHorizontalOffset()

        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // stop line and tt graph
                GeometryReader { geometry in
                    ScrollView([.horizontal, .vertical], showsIndicators: false) {
                        ZStack(alignment: .topLeading) {
                            // make sure there is enough space to actually see everything
                            Rectangle()
                                .fill(Color.clear)
                                .frame(
                                    width: 1,
                                    height: totalHeight + geometry.size.height
                                )

                            ForEach(journey.legsErased, id: \.id) { leg in
                                if let busLeg = leg.value as? JourneyBusLeg,
                                   let busContext = context.edgeContext[busLeg.id] as? JourneyBusLeg.Context {
                                    let yOffset = yOffsetLegMap[busLeg.id] ?? 0
                                    let xOffset = (timeDeltaTranslation[busLeg.id] ?? .zero).seconds / 60 * horizontalScale

                                    JourneyBusSegmentVisualiser(
                                        busContext: busContext,
                                        stopLookup: context.intermediateNodeContext,
                                        geometrySize: geometry.size,
                                        scrollPosition: .init(
                                            x: scrollPosition.x,
                                            y: scrollPosition.y - yOffset
                                        ),
                                        now: now,
                                        verticalScale: verticalScale,
                                        horizontalScale: horizontalScale,
                                        busHOffset: busHOffset - xOffset,
                                        isCollapsedExt: .init(get: {
                                            isCollapsed[busLeg.id] ?? true
                                        }, set: { newCollapsedState in
                                            isCollapsed[busLeg.id] = newCollapsedState
                                        }),
                                        namespace: namespace
                                    )
                                    .padding(.top, yOffset)
                                }
                            }
                        }
                        .frame(minHeight: geometry.size.height, alignment: .top)
                    }
                    .onScrollGeometryChange(for: CGPoint.self) { geo in
                        geo.contentOffset
                    } action: { oldValue, newValue in
                        scrollPosition = newValue
                    }
                    .background(alignment: .topLeading) {
                        Color.white
                            .frame(width: stopLineAndLabelsWidth)
                            .ignoresSafeArea(.all, edges: [.bottom, .leading])
                            .overlay(alignment: .trailing) { HStack { Divider() } }
                            .offset(y: scrollPosition.y)
                    }
//                    .background(alignment: .bottomLeading) {
//
//                        // lowerbound
//                        let lowerbound = (min(.zero, estimates.first!.estimates.first!.eta.timeDelta(since: now)).seconds / 60 / 5).rounded(.awayFromZero)
//                        let upperbound = ((
//                            estimates.last!.estimates.last!.eta.timeDelta(since: now) +
//                                .mins((geometry.size.width - stopLineAndLabelsWidth) / horizontalScale) // the scroll allowance
//                        ).seconds / 60 / 5).rounded(.awayFromZero)
//
//                        timeTickers(
//                            lowerbound: Int(lowerbound),
//                            upperbound: Int(upperbound),
//                            step: 5,
//                            geometrySize: geometry.size,
//                            busHOffset: busHOffset,
//                            stopTimeRange: stopTimeRange
//                        )
//                    }
                }
                .overlay(alignment: .trailing) { HStack { Divider() } }
                .overlay(alignment: .top) { VStack { Divider() } }
                .padding(.trailing, timeTickerLabelsWidth) // space for horizontal time tickers
                .padding(.top, timeTickerLabelsHeight) // space for top time tickers
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(pageDescription)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        now = now.addingTimeInterval(-30)
                    } label: {
                        Image(systemName: "minus")
                    }
                    Button {
                        now = now.addingTimeInterval(30)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onReceive(nowRefreshTimer) { _ in
            now = now.addingTimeInterval(0.1)
        }
    }

    /// Calculates the vertical offset (down), along with the time delta translation (back in
    /// time), for each leg of the journey
    func yOffsetForLegs() -> (
        yOffsetLegMap: [UUID: CGFloat],
        timeDeltaTranslation: [UUID: TimeDelta],
        totalHeight: CGFloat
    ) {
        var yOffsetSoFar: CGFloat = 0
        var timeDeltaSoFar: TimeDelta = .zero
        var yOffsetLegMap: [UUID: CGFloat] = [:]
        var timeDeltaTranslation: [UUID: TimeDelta] = [:]

        for leg in journey.legs {
            // the offset for this item is just the value so far
            yOffsetLegMap[leg.id] = yOffsetSoFar
            timeDeltaTranslation[leg.id] = timeDeltaSoFar

            // calculate height of this leg
            if let context = context.edgeContext[leg.id] as? JourneyBusLeg.Context, // get context
               !context.stopEstimations.isEmpty { // ensure that it actually has items

                // use the time difference
                let timeDifference = context.stopEstimations.last!.deltaTime - context.stopEstimations.first!.deltaTime
                if isCollapsed[leg.id] == false { // if NOT collapsed, use delta-time
                    yOffsetSoFar += timeDifference.seconds / 60 * verticalScale
                } else { // if collapsed, time delta remains the same but y offset is the collapsed vertical distance
                    yOffsetSoFar += collapsedVerticalDistance
                }
                timeDeltaSoFar += timeDifference
                continue
            }

            // unavailable data, use collapsed height
            yOffsetSoFar += collapsedVerticalDistance
            timeDeltaSoFar += .mins(collapsedVerticalDistance / verticalScale)
        }

        return (yOffsetLegMap, timeDeltaTranslation, yOffsetSoFar)
    }

    /// Calculates the horizontal offset (to the right) to transform all time-dependent objects by
    /// such that the first bus, of the first stop, of the first leg, is located at `firstBusHorizontalOffset`
    func busHorizontalOffset() -> CGFloat {
        guard let firstLegId = journey.legs.first?.id,
              let firstLegContext = context.edgeContext[firstLegId] as? JourneyBusLeg.Context,
              let firstStop = firstLegContext.stopEstimations.first,
              let firstBus = firstStop.estimates.first
        else { return 0 }

        // leftwards adjustment such that the bus is located at the very left of the graph
        let leftwardsTare = firstBus.eta.timeDelta(since: now).seconds / 60 * horizontalScale
        // then adjust rightwards to be at the correct offset
        return -leftwardsTare + firstBusHorizontalOffset
    }
}

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
            TimeDelta.mins(collapsedVerticalDistance / verticalScale)
        }

        let estimates = if busContext.stopEstimations.isEmpty {
            [
                busContext.stopEstimations.first ?? StopArrivalEstimates(
                    stopId: busContext.startCode,
                    deltaTime: TimeDelta.mins(-collapsedVerticalDistance / verticalScale),
                    deltaError: .zero,
                    estimates: []
                ),
                busContext.stopEstimations.last ?? StopArrivalEstimates(
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

    func stopLine(stopTimeRange: TimeDelta, estimates: [StopArrivalEstimates]) -> some View {
        ZStack(alignment: .topLeading) {
            // stop line
            Capsule()
                .fill(Color.green)
                .frame(
                    width: stopLineWidth,
                    height: treatAsCollapsed
                    ? (collapsedVerticalDistance + stopLineWidth)
                    : (stopTimeRange.seconds / 60 * verticalScale + stopLineWidth)
                )
                .padding(.top, -stopLineWidth/2 + firstStopVerticalOffset)
                .padding(.leading, -stopLineWidth/2 + stopsHorizontalOffset)

            // stop indicators
            ForEach(
                treatAsCollapsed ? [estimates.first!, estimates.last!] : busContext.stopEstimations,
                id: \.stopId
            ) { stopEstimate in
                HStack(alignment: .center, spacing: 5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: stopIndicatorDiameter, height: stopIndicatorDiameter)

                    Text(
                        (stopLookup[stopEstimate.stopId] as? JourneyBusStopNode.Context)?
                            .description ?? stopEstimate.stopId
                    )
                    .font(.caption)
                    .truncationMode(.middle)
                    .lineLimit(1)
                }
                .frame(height: firstStopVerticalOffset * 2)
                .padding(.leading, -stopIndicatorDiameter/2 + stopsHorizontalOffset)
                .padding(
                    .top,
                    treatAsCollapsed
                        ? (stopEstimate.stopId == estimates.first!.stopId ? 0 : collapsedVerticalDistance)
                        : ((stopTimeRange + stopEstimate.deltaTime).seconds / 60 * verticalScale)
                )
            }

            // bus location indicator
            if !treatAsCollapsed {
                ForEach(estimates.first!.estimates.enumerated(), id: \.offset) { (_, busEstimate) in
                    let etaFromNow = busEstimate.eta.timeDelta(since: now)
                    HStack(alignment: .center, spacing: 5) {
                        Image(systemName: "bus")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Color.blue)
                            .padding(2)
                            .background {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(Color.white)
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.gray, lineWidth: 1)
                                }
                            }
                            .frame(width: busIndicatorDiameter, height: busIndicatorDiameter)

                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(height: 1)
                    }
                    .frame(height: firstStopVerticalOffset * 2)
                    .padding(.leading, -busIndicatorDiameter/2 + stopsHorizontalOffset)
                    .padding(.top, -etaFromNow.seconds / 60 * verticalScale)
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
                    .padding(.leading, stopsHorizontalOffset + stopIndicatorDiameter/2 + 5)

                    VStack(spacing: stopLineWidth/2) {
                        ForEach(0..<3) { _ in
                            Circle()
                                .fill(Color.white)
                                .frame(width: stopLineWidth/2, height: stopLineWidth/2)
                        }
                    }
                    .padding(.leading, stopsHorizontalOffset - stopLineWidth/4)
                }
                .frame(height: collapsedVerticalDistance)
                .padding(.top, firstStopVerticalOffset)
            }
        }
        .frame(width: stopLineAndLabelsWidth, alignment: .leading)
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
    func ttGraph(stopTimeRange: TimeDelta, estimates: [StopArrivalEstimates]) -> some View {
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
                        + geometrySize.width - stopLineAndLabelsWidth - firstBusHorizontalOffset,
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
                            width: max(100, geometrySize.width - stopLineAndLabelsWidth),
                            height: 1
                        )
                        .offset(x: scrollPosition.x)

                    // bus indicators
                    ForEach(stopEstimate.estimates.enumerated(), id: \.offset) { (_, busEstimate) in
                        let etaFromNow = busEstimate.eta.timeDelta(since: now)

                        let horizontalOffset = ( // 1st is regular time offset, 2nd is to actually skew the time, 3rd to align
                            (etaFromNow.seconds / 60 * horizontalScale) -
                            ((stopTimeRange + stopEstimate.deltaTime).seconds / 60 * horizontalScale) +
                            busHOffset
                        )

                        if horizontalOffset >= 0 {
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
                                .frame(height: firstStopVerticalOffset * 2, alignment: .bottomLeading)
                                .offset(y: -firstStopVerticalOffset)
                                .padding(.leading, horizontalOffset)

                            let indicatorShape = switch busEstimate.source {
                            case .live: "circle.fill"
                            case .projected: "circle.circle.fill"
                            case .extrapolated: "circle"
                            }

                            Image(systemName: indicatorShape)
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(etaFromNow > .zero ? Color.blue : Color.gray)
                                .opacity(etaFromNow > .zero ? 1 : 0.5)
                                .frame(width: stopIndicatorDiameter, height: stopIndicatorDiameter)
                                .padding(.leading, -stopIndicatorDiameter/2)
                                .padding(.leading, horizontalOffset)
                        }
                    }
                }
                .frame(height: firstStopVerticalOffset * 2)
                .padding(
                    .top,
                    treatAsCollapsed
                        ? (stopEstimate.stopId == estimates.first!.stopId ? 0 : collapsedVerticalDistance)
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

                VStack(alignment: .leading, spacing: 0) {
                    if etaFromNow < .zero && !treatAsCollapsed {
                        Rectangle()
                            .fill(Color.gray) // TODO: consider if we want to do a sort of incremental fade for collapsed??
                            .frame(height: etaFromNow.seconds / 60 * verticalScale * -1)
                            .opacity(0.5)
                    }

                    Rectangle()
                        .fill(Color.blue)
                        .frame(minHeight: 0)
                }
                .frame(
                    width: 1,
                    height: treatAsCollapsed ? collapsedVerticalDistance : stopTimeRange.seconds / 60 * verticalScale
                )
                .padding(.leading, horizontalOffset)
                .padding(.top, firstStopVerticalOffset)

                if !treatAsCollapsed, horizontalOffset > 0 {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: horizontalOffset, height: 1)
                        .padding(.top, firstStopVerticalOffset - etaFromNow.seconds / 60 * verticalScale)
                }

                // bus service label
                Text(busEstimate.busServiceNo)
                    .lineLimit(1)
                    .font(.caption)
                    .foregroundStyle(Color.white)
                    .padding(3)
                    .background {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.accentColor)
                    }
                    .matchedGeometryEffect(id: "\(busEstimate.busServiceNo)\(busEstimate.busId.description)", in: namespace)
                    .frame(
                        width: firstBusHorizontalOffset * 2,
                        height: treatAsCollapsed ? nil : firstStopVerticalOffset * 2
                    ) // horizontally (and vertically center, if not collapsed)
                    .padding(.leading, horizontalOffset - firstBusHorizontalOffset) // position
                    .padding(
                        .top,
                        treatAsCollapsed
                            ? (firstStopVerticalOffset + stopIndicatorDiameter)
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

// NOTE: currently assumes that "now" is located at (0, 0)
private struct TimeTicker: View {
    var verticalScale: CGFloat
    var horizontalScale: CGFloat

    var ttGraphSize: CGSize
    var scrollPosition: CGPoint

    var minutes: Int

    var body: some View {
        let xOffset = min(ttGraphSize.width, CGFloat(minutes) * horizontalScale - scrollPosition.x - scrollPosition.y * horizontalScale / verticalScale)
        let yOffset = max(0, (CGFloat(minutes) - (ttGraphSize.width + scrollPosition.x)/horizontalScale) * verticalScale - scrollPosition.y)

        let isNow = minutes == 0

        ZStack(alignment: .bottomLeading) {
            let strokeColor = isNow ? Color.green : Color.gray

            Path { path in
                path.move(to: .init(x: 0, y: CGFloat(minutes) * verticalScale - scrollPosition.y - scrollPosition.x * verticalScale / horizontalScale))
                path.addLine(to: .init(x: xOffset, y: yOffset))
            }
            .stroke(
                strokeColor,
                style: isNow
                ? .init(lineWidth: 2, lineCap: .round, lineJoin: .round, miterLimit: 0)
                : .init(lineWidth: 1, lineCap: .round, lineJoin: .round, miterLimit: 0, dash: [5, 5], dashPhase: 0)
            )
            .frame(width: ttGraphSize.width, height: ttGraphSize.height)
            .mask {
                Rectangle().ignoresSafeArea()
            }

            Path { path in
                path.move(to: .init(x: xOffset, y: yOffset + timeTickerLabelsHeight))

                if yOffset > 0 { // if there is a y-offset, draw a horizontal line
                    path.addLine(to: .init(x: ttGraphSize.width + timeTickerLabelsWidth/2, y: yOffset + timeTickerLabelsHeight))
                } else { // else, draw a vertical line
                    path.addLine(to: .init(x: xOffset, y: timeTickerLabelsHeight/2))
                }
            }
            .stroke(strokeColor, lineWidth: 1)
            .frame(
                width: ttGraphSize.width + timeTickerLabelsWidth,
                height: ttGraphSize.height + timeTickerLabelsHeight
            )
            //            .clipShape(Rectangle())
        }
        .overlay(alignment: .topLeading) {
            ZStack(alignment: .bottomLeading) {
                Text(isNow ? "now" : "\(minutes)m")
                    .font(.caption)
                    .offset(x: xOffset, y: yOffset)
            }
            .padding(3)
            .frame(height: timeTickerLabelsHeight)
        }
        .opacity(isNow ? 1 : 0.5)
    }
}
