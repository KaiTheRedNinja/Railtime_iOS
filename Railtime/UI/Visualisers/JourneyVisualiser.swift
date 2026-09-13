//
//  JourneyVisualiser.swift
//  Railtime
//
//  Created by Kai Quan Tay on 13/9/26.
//

import SwiftUI
import Combine

/// A namespace containing sizing information for the journey visualiser
enum Sizing {
    /// The width of the vertical line showing the stops
    static let stopLineWidth: CGFloat = 5
    /// The diameter of the circle used to indicate a stop in the stop line, or a bus in the tt graph
    static let stopIndicatorDiameter: CGFloat = 10
    /// The diameter of the image used to indicate a bus on the stop line
    static let busIndicatorDiameter: CGFloat = 16

    /// The width of the stop line + labels area
    static let stopLineAndLabelsWidth: CGFloat = 100
    /// The height of the top section of the time ticker labels
    static let timeTickerLabelsHeight: CGFloat = 20
    /// The width of the trailing section of the time ticker labels
    static let timeTickerLabelsWidth: CGFloat = 30

    /// The vertical offset from the top of the screen to the center of the first stop
    static let firstStopVerticalOffset: CGFloat = 20
    /// The horizontal offset from the left of the screen to the center of the stop line
    static let stopsHorizontalOffset: CGFloat = 15
    /// The horizontal offset from the left of left of the tt graph to the center of the first bus
    static let firstBusHorizontalOffset: CGFloat = 30

    /// The collapsed distance between the center of the first and last stops
    static let collapsedVerticalDistance: CGFloat = 80
}

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
                            .frame(width: Sizing.stopLineAndLabelsWidth)
                            .ignoresSafeArea(.all, edges: [.bottom, .leading])
                            .overlay(alignment: .trailing) { HStack { Divider() } }
                    }
                    .background(alignment: .bottomLeading) {
                        let tickerGroups = timeTickerGroups(
                            yOffsetLegMap: yOffsetLegMap,
                            timeDeltaTranslation: timeDeltaTranslation,
                            totalHeight: totalHeight
                        )

                        timeTickers(
                            groups: tickerGroups,
                            busHOffset: busHOffset,
                            geometrySize: geometry.size
                        )
                    }
                }
                .overlay(alignment: .trailing) { HStack { Divider() } }
                .overlay(alignment: .top) { VStack { Divider() } }
                .padding(.trailing, Sizing.timeTickerLabelsWidth) // space for horizontal time tickers
                .padding(.top, Sizing.timeTickerLabelsHeight) // space for top time tickers
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

    func timeTickers(
        groups: [TickerGroup],
        busHOffset: CGFloat,
        geometrySize: CGSize
    ) -> some View {
        ZStack(alignment: .bottomLeading) {
            ForEach(groups.enumerated(), id: \.offset) { (_, group) in
                ForEach(group.lowerbound..<(group.upperbound + 1), id: \.self) { tickerIndex in
                    TimeTicker(
                        verticalScale: verticalScale,
                        horizontalScale: horizontalScale,
                        ttGraphSize: .init(
                            width: geometrySize.width - Sizing.stopLineAndLabelsWidth,
                            height: max(0, geometrySize.height - max(0, group.startingHeight - scrollPosition.y))
                        ),
                        scrollPosition: .init(
                            x: scrollPosition.x - busHOffset + (group.timeOffset.seconds / 60 * horizontalScale),
                            y: max(0, scrollPosition.y - group.startingHeight) - Sizing.firstStopVerticalOffset
                        ),
                        minutes: tickerIndex * group.step
                    )
                    .frame(
                        width: max(0, geometrySize.width - Sizing.stopLineAndLabelsWidth + Sizing.timeTickerLabelsWidth),
                        height: max(0, geometrySize.height + Sizing.timeTickerLabelsHeight),
                        alignment: .bottomLeading
                    )
                }
                .padding(.leading, Sizing.stopLineAndLabelsWidth)
                .mask(alignment: .top) {
                    Rectangle()
                        .frame(height: max(0, Sizing.timeTickerLabelsHeight + Sizing.firstStopVerticalOffset + group.endingHeight - scrollPosition.y))
                }
            }
        }
        .padding(.trailing, -Sizing.timeTickerLabelsWidth) // reverse later padding
        .padding(.top, -Sizing.timeTickerLabelsHeight) // reverse later padding
    }

    /// Calculates the vertical offset (down), along with the time delta translation (back in
    /// time), for each leg of the journey.
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
                    yOffsetSoFar += Sizing.collapsedVerticalDistance
                }
                timeDeltaSoFar += timeDifference
                continue
            }

            // unavailable data, use collapsed height
            yOffsetSoFar += Sizing.collapsedVerticalDistance
            timeDeltaSoFar += .mins(Sizing.collapsedVerticalDistance / verticalScale)
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
        return -leftwardsTare + Sizing.firstBusHorizontalOffset
    }

    /// Calculates where the time tickers should be located
    func timeTickerGroups(
        yOffsetLegMap: [UUID: CGFloat],
        timeDeltaTranslation: [UUID: TimeDelta],
        totalHeight: CGFloat
    ) -> [TickerGroup] {
        guard !journey.legs.isEmpty else { return [] }

        var currentTickerGroup: TickerGroup = .init(
            lowerbound: 0,
            upperbound: 0,
            step: 5,
            startingHeight: 0,
            endingHeight: -1, // will be set later
            timeOffset: .zero
        )
        var tickerGroups: [TickerGroup] = []

        for leg in journey.legs {
            // we ignore this leg if it is not a bus leg, or has no data
            guard let leg = leg as? JourneyBusLeg,
                  let legContext = context.edgeContext[leg.id] as? JourneyBusLeg.Context,
                  let firstStop = legContext.stopEstimations.first, // TODO: fallback for empty estimations
                  let lastStop = legContext.stopEstimations.last,
                  !firstStop.estimates.isEmpty, !lastStop.estimates.isEmpty
            else { continue }

            let timeOffset = timeDeltaTranslation[leg.id] ?? .zero
            let yOffset = yOffsetLegMap[leg.id] ?? 0

            // update the lowerbound and upperbound of the current ticker group to ensure that it can contain the
            // FIRST stops of this leg
            let firstStopLowerbound = ( // we add time delta because there is no need to add "now" to everything
                (firstStop.estimates.first!.eta.timeDelta(since: now) + timeOffset).seconds / 60 / 5
            ).rounded(.awayFromZero)
            let firstStopUpperbound = (
                (firstStop.estimates.last!.eta.timeDelta(since: now)).seconds / 60 / 5
                // TODO: add scroll allowance
            ).rounded(.awayFromZero)
            let lastStopLowerbound = (
                (lastStop.estimates.first!.eta.timeDelta(since: now) + timeOffset).seconds / 60 / 5
            ).rounded(.awayFromZero)
            let lastStopUpperbound = (
                (lastStop.estimates.last!.eta.timeDelta(since: now)).seconds / 60 / 5
                // TODO: add scroll allowance
            ).rounded(.awayFromZero)

            currentTickerGroup.lowerbound = min(currentTickerGroup.lowerbound, Int(firstStopLowerbound))
            currentTickerGroup.upperbound = max(currentTickerGroup.upperbound, Int(firstStopLowerbound), Int(firstStopUpperbound))

            // we cut off the ticker group if this is collapsed
            if isCollapsed[leg.id] == false {
                // increase upperbound to include the *LAST* bus.
                currentTickerGroup.upperbound = max(currentTickerGroup.upperbound, Int(lastStopLowerbound))
                // and then just go to the next leg
                continue
            }

            // add the current group, basically to mark the end of it
            currentTickerGroup.endingHeight = yOffset
            tickerGroups.append(currentTickerGroup)

            // create a new ticker group, positioned at the bottom of this leg (ie. top + collapse vertical distance)
            let stopTimeRange = lastStop.deltaTime - firstStop.deltaTime
            currentTickerGroup = .init(
                lowerbound: Int(lastStopLowerbound),
                upperbound: Int(lastStopUpperbound),
                step: 5,
                startingHeight: yOffset + Sizing.collapsedVerticalDistance,
                endingHeight: 0,
                timeOffset: timeOffset + stopTimeRange
            )
        }

        // add the incomplete ticker group
        currentTickerGroup.endingHeight = totalHeight
        tickerGroups.append(currentTickerGroup)
        return tickerGroups
    }
}

/// Specifications about tickers in a group
struct TickerGroup {
    /// The lowerbound for tickers in this group. This means that the earliest time ticker will be `lowerbound * step` minutes
    var lowerbound: Int
    /// The upperbound for tickers in this group. This means that the latest time ticker will be `upperbound * step` minutes
    var upperbound: Int
    /// The number of minutes per step
    var step: Int

    /// The height that this group starts with. This means that this ticker group will start `startingHeight` px from the top.
    var startingHeight: CGFloat
    /// The height that this group ends at. This means that this ticker group will be cut off `endingHeight` px from the top.
    var endingHeight: CGFloat

    /// The time offset. This means that this ticker group will start `timeOffset` seconds in the future.
    var timeOffset: TimeDelta
}
