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
}
