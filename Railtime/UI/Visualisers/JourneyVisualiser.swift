//
//  JourneyVisualiser.swift
//  Railtime
//
//  Created by Kai Quan Tay on 13/9/26.
//

/*
import SwiftUI
import Combine

import Journey
import BusEstimation
import LTAAPI

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
    /// The manager holding all of the data
    @ObservedObject var manager: JourneyManager

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
    @State var isCollapsed: [JourneyLegID: Bool] = [:]

    /// The animation namespace
    @Namespace var namespace

    init(
        manager: JourneyManager,
        now: Date
    ) {
        self.manager = manager
        self.now = now
    }

    @ViewBuilder
    var body: some View {
        let journey = manager.journey
        let context = manager.context

        let pageDescription: String = [
            context.context(forNode: journey.startNode, type: JourneyBusStopNode.self)?.description ?? "?",
            " to ",
            manager.endNodeContext(forPathItem: journey.path.last!, as: JourneyBusStopNode.self)?.description ?? "?",
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

                            ForEach(journey.path.enumerated(), id: \.offset) { (index, pathItem) in
                                vehicleSegment(
                                    forPathItem: pathItem,
                                    yOffsetLegMap: yOffsetLegMap,
                                    timeDeltaTranslation: timeDeltaTranslation,
                                    geometrySize: geometry.size,
                                    busHOffset: busHOffset
                                )

                                if index + 1 < journey.path.count,
                                   let leg = journey.legs[pathItem],
                                   let endNode = journey.nodes[leg.destinationId] {
                                    let chosenLegId = journey.path[index + 1]
                                    let otherLegIDs = endNode.nextLegIds.filter { $0 != chosenLegId }
                                    ForEach(otherLegIDs.enumerated(), id: \.offset) { (_, otherLegId) in
                                        vehicleTransfer(
                                            otherLegId: otherLegId,
                                            sameLevelAs: chosenLegId,
                                            yOffsetLegMap: yOffsetLegMap,
                                            timeDeltaTranslation: timeDeltaTranslation,
                                            geometrySize: geometry.size,
                                            busHOffset: busHOffset
                                        )
                                        .onTapGesture {
                                            manager.changePath(atIndex: index + 1, toPathItem: otherLegId)
                                        }
                                    }
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

    /// Calculates the vertical offset (down), along with the time delta translation (back in
    /// time), for each leg of the journey.
    func yOffsetForLegs() -> (
        yOffsetLegMap: [JourneyLegID: CGFloat],
        timeDeltaTranslation: [JourneyLegID: TimeDelta],
        totalHeight: CGFloat
    ) {
        var yOffsetSoFar: CGFloat = 0
        var timeDeltaSoFar: TimeDelta = .zero
        var yOffsetLegMap: [UUID: CGFloat] = [:]
        var timeDeltaTranslation: [UUID: TimeDelta] = [:]

        for pathItem in manager.journey.path {
            // the offset for this item is just the value so far
            yOffsetLegMap[pathItem] = yOffsetSoFar
            timeDeltaTranslation[pathItem] = timeDeltaSoFar

            // use parameter packs to allow easy iteration over different concrete types fo JourneyStopBasedLegContext
            func attempt<each Context: JourneyStopBasedLegContext>(
                context: any JourneyLegContext,
                contextTypes: repeat (each Context).Type
            ) -> Bool {
                func check<SomeContext: JourneyStopBasedLegContext>(
                    against type: SomeContext.Type
                ) -> Bool {
                    guard let context = context as? SomeContext else { return false }

                    guard !context.stopEstimations.isEmpty else { return false } // ensure that it actually has items

                    // use the time difference
                    let timeDifference = context.stopEstimations.last!.deltaTime - context.stopEstimations.first!.deltaTime
                    if isCollapsed[pathItem] == false { // if NOT collapsed, use delta-time
                        yOffsetSoFar += timeDifference.seconds / 60 * verticalScale
                    } else { // if collapsed, time delta remains the same but y offset is the collapsed vertical distance
                        yOffsetSoFar += Sizing.collapsedVerticalDistance
                    }
                    timeDeltaSoFar += timeDifference

                    return true
                }

                for contextType in repeat each contextTypes {
                    if check(against: contextType.self) { return true }
                }

                return false
            }

            // calculate height of this leg
            if let leg = manager.journey.legs[pathItem],
               let context = manager.context.edgeContext[leg.contextId] as? (any JourneyStopBasedLegContext) {
                // if we manage to find the height, go to the next one
                if attempt(context: context, contextTypes: JourneyBusLeg.Context.self, JourneyTrainLeg.Context.self) {
                    continue
                }
            }

            // unavailable data or was not able to find height, use collapsed height as fallback
            yOffsetSoFar += Sizing.collapsedVerticalDistance
            timeDeltaSoFar += .mins(Sizing.collapsedVerticalDistance / verticalScale)
        }

        return (yOffsetLegMap, timeDeltaTranslation, yOffsetSoFar)
    }

    /// Calculates the horizontal offset (to the right) to transform all time-dependent objects by
    /// such that the first bus, of the first stop, of the first leg, is located at `firstBusHorizontalOffset`
    func busHorizontalOffset() -> CGFloat {
        guard let firstLegId = manager.journey.path.first,
              let firstLeg = manager.journey.legs[firstLegId],
              let firstLegContext = manager.context.edgeContext[firstLeg.contextId]
        else { return 0 }

        // use parameter packs to allow easy iteration over different concrete types fo JourneyStopBasedLegContext
        func attempt<each Context: JourneyStopBasedLegContext>(
            contextTypes: repeat (each Context).Type
        ) -> CGFloat {
            func check<SomeContext: JourneyStopBasedLegContext>(
                against type: SomeContext.Type
            ) -> CGFloat? {
                guard let context = firstLegContext as? SomeContext else { return nil }

                guard let firstStop = context.stopEstimations.first,
                      let firstBus = firstStop.estimates.first
                else { return nil }

                // leftwards adjustment such that the bus is located at the very left of the graph
                let leftwardsTare = firstBus.eta.timeDelta(since: now).seconds / 60 * horizontalScale
                // then adjust rightwards to be at the correct offset
                return -leftwardsTare + Sizing.firstBusHorizontalOffset
            }

            for contextType in repeat each contextTypes {
                if let result = check(against: contextType.self) {
                    return result
                }
            }

            return 0
        }

        return attempt(contextTypes: JourneyBusLeg.Context.self, JourneyTrainLeg.Context.self)
    }

    /// Calculates where the time tickers should be located
    func timeTickerGroups(
        yOffsetLegMap: [UUID: CGFloat],
        timeDeltaTranslation: [UUID: TimeDelta],
        totalHeight: CGFloat
    ) -> [TickerGroup] {
        guard !manager.journey.path.isEmpty else { return [] }

        var currentTickerGroup: TickerGroup = .init(
            lowerbound: 0,
            upperbound: 0,
            step: 5,
            startingHeight: 0,
            endingHeight: -1, // will be set later
            timeOffset: .zero
        )
        var tickerGroups: [TickerGroup] = []

        for pathItem in manager.journey.path {
            // use parameter packs to allow easy iteration over different concrete types fo JourneyStopBasedLegContext
            func attempt<each Context: JourneyStopBasedLegContext>(
                leg: any JourneyLeg,
                context: any JourneyLegContext,
                contextTypes: repeat (each Context).Type
            ) {
                let timeOffset = timeDeltaTranslation[leg.id] ?? .zero
                let yOffset = yOffsetLegMap[leg.id] ?? 0

                func check<SomeContext: JourneyStopBasedLegContext>(
                    against type: SomeContext.Type
                ) -> Bool {
                    guard let context = context as? SomeContext else { return false }

                    guard let firstStop = context.stopEstimations.first, // TODO: fallback for empty estimations
                          let lastStop = context.stopEstimations.last,
                          !firstStop.estimates.isEmpty, !lastStop.estimates.isEmpty
                    else { return false }

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
                        return true
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

                    return true
                }

                for contextType in repeat each contextTypes {
                    if check(against: contextType.self) { return }
                }
                // try walking. Walks are always compact.
                if let walkContext = context as? JourneyWalkLeg.Context {
                    // add the current group, basically to mark the end of it
                    currentTickerGroup.endingHeight = yOffset
                    tickerGroups.append(currentTickerGroup)

                    // create a new ticker group, positioned at the bottom of this leg (ie. top + collapse vertical distance)
                    currentTickerGroup = .init(
                        lowerbound: 0,
                        upperbound: 0,
                        step: 5,
                        startingHeight: yOffset + Sizing.collapsedVerticalDistance,
                        endingHeight: 0,
                        timeOffset: timeOffset + walkContext.walkTime
                    )
                }
            }

            // we ignore this leg if it is not a bus leg, or has no data
            guard let leg = manager.journey.legs[pathItem],
                  let legContext = manager.context.edgeContext[leg.contextId]
            else { continue }

            attempt(leg: leg, context: legContext, contextTypes: JourneyBusLeg.Context.self, JourneyTrainLeg.Context.self)
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
*/
