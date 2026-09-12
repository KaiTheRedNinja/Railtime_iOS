//
//  SkewedBusJourneyView.swift
//  Railtime
//
//  Created by Kai Quan Tay on 11/9/26.
//

import SwiftUI
import Combine

// the width of the vertical line showing the stops
private let stopLineWidth: CGFloat = 5
// the diameter of the circle used to indicate a stop and a bus
private let stopIndicatorDiameter: CGFloat = 10

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

struct SkewedBusJourneyView: View {
    var estimates: [StopArrivalEstimates]
    var stopLookup: [String: LTABusStopInfo] = [:]

    // Number of points of spacing per minute, vertically
    var verticalScale: CGFloat = 40
    // Number of points of spacing per minute, horizontally. This value should never be larger than verticalScale
    var horizontalScale: CGFloat = 10

    // the current time
    @State var now: Date = .now
    @State var nowRefreshTimer = Timer.publish(every: 0.1, on: .main, in: .default).autoconnect()

    // the current scroll position from the scroll view
    @State var scrollPosition: CGPoint = .zero

    // the currently selected bus
    @State var busId: Int?

    // whether or not the view is collapsed
    @State var isCollapsed: Bool = false

    var body: some View {
        // first we need to determine how large (horizontally and vertically) we need to be.

        // the time difference between the first and last stop time delta (ie. distance)
        let stopTimeRange = estimates.last!.deltaTime - estimates.first!.deltaTime
        // the time difference between the first and last bus arrival estimate
        let arrivalTimeRange = estimates.last!.estimates.last!.eta.timeDelta(since: .now)

        let busHOffset = busHorizontalOffset()

        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // stop line and tt graph
                GeometryReader { geometry in
                    ScrollView([.horizontal, .vertical], showsIndicators: false) {
                        VStack {
                            HStack(alignment: .top, spacing: 0) {
                                stopLine(stopTimeRange: stopTimeRange)
                                ttGraph(
                                    geometrySize: geometry.size,
                                    stopTimeRange: stopTimeRange,
                                    arrivalTimeRange: arrivalTimeRange,
                                    busHOffset: busHOffset
                                )
                            }
                            .frame(minHeight: geometry.size.height)
                        }
                    }
                    .onScrollGeometryChange(for: CGPoint.self) { geo in
                        geo.contentOffset
                    } action: { oldValue, newValue in
                        scrollPosition = newValue
                        print("New scroll position: \(scrollPosition)")
                    }
                    .background(alignment: .bottomLeading) {

                        // lowerbound
                        let lowerbound = (min(.zero, estimates.first!.estimates.first!.eta.timeDelta(since: now)).seconds / 60 / 5).rounded(.awayFromZero)
                        let upperbound = ((
                            estimates.last!.estimates.last!.eta.timeDelta(since: now) +
                                .mins((geometry.size.width - stopLineAndLabelsWidth) / horizontalScale) // the scroll allowance
                        ).seconds / 60 / 5).rounded(.awayFromZero)

                        timeTickers(
                            lowerbound: Int(lowerbound),
                            upperbound: Int(upperbound),
                            step: 5,
                            geometrySize: geometry.size,
                            busHOffset: busHOffset
                        )
                    }
                }
                .overlay(alignment: .trailing) { HStack { Divider() } }
                .overlay(alignment: .top) { VStack { Divider() } }
                .padding(.trailing, timeTickerLabelsWidth) // space for horizontal time tickers
                .padding(.top, timeTickerLabelsHeight) // space for top time tickers
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Bus 154")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        now = now.addingTimeInterval(-30)
                    } label: {
                        Image(systemName: "minus")
                    }
                    Button {
                        now = estimates.first!.estimates.first!.eta
                    } label: {
                        Image(systemName: "equal")
                    }
                    Button {
                        now = now.addingTimeInterval(30)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }

    func stopLine(stopTimeRange: TimeDelta) -> some View {
        // stop line
        ZStack(alignment: .topLeading) {
            Capsule()
                .fill(Color.green)
                .frame(width: stopLineWidth, height: stopTimeRange.seconds / 60 * verticalScale + stopLineWidth)
                .padding(.top, -stopLineWidth/2 + firstStopVerticalOffset)
                .padding(.leading, -stopLineWidth/2 + stopsHorizontalOffset)

            ForEach(estimates, id: \.stopId) { estimate in
                HStack(alignment: .center, spacing: 5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: stopIndicatorDiameter, height: stopIndicatorDiameter)

                    Text(stopLookup[estimate.stopId]?.description ?? estimate.stopId)
                        .font(.caption)
                        .truncationMode(.middle)
                        .lineLimit(1)
                }
                .frame(height: firstStopVerticalOffset * 2)
                .padding(.leading, -stopIndicatorDiameter/2 + stopsHorizontalOffset)
                .padding(.top, (stopTimeRange + estimate.deltaTime).seconds / 60 * verticalScale)
            }
        }
        .background(alignment: .topLeading) {
            Color.white
                .frame(width: stopLineAndLabelsWidth)
                .ignoresSafeArea()
                .overlay(alignment: .trailing) { Divider() }
                .offset(y: scrollPosition.y)
        }
        .frame(width: stopLineAndLabelsWidth, alignment: .leading)
        .onTapGesture {
            isCollapsed.toggle()
        }
        .offset(x: scrollPosition.x)
        .zIndex(2)
    }

    @ViewBuilder
    func ttGraph(geometrySize: CGSize, stopTimeRange: TimeDelta, arrivalTimeRange: TimeDelta, busHOffset: CGFloat) -> some View {
        // tt graph
        ZStack(alignment: .topLeading) {
            ForEach(estimates, id: \.stopId) { stopEstimate in
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

                            Circle()
                                .fill(etaFromNow > .zero ? Color.blue : Color.gray)
                                .opacity(etaFromNow > .zero ? 1 : 0.5)
                                .frame(width: stopIndicatorDiameter, height: stopIndicatorDiameter)
                                .padding(.leading, -stopIndicatorDiameter/2)
                                .padding(.leading, horizontalOffset)
                        }
                    }

                    // make sure there is enough space to actually see everything
                    Rectangle()
                        .fill(Color.clear)
                        .frame(
                            width: (arrivalTimeRange - stopTimeRange).seconds / 60 * horizontalScale
                            + geometrySize.width - stopLineAndLabelsWidth,
                            height: 1
                        )
                }
                .frame(height: firstStopVerticalOffset * 2)
                .padding(
                    .top,
                    (stopTimeRange + stopEstimate.deltaTime).seconds / 60 * verticalScale
                )
            }

            // line for each bus
            ForEach((estimates.first?.estimates ?? []).enumerated(), id: \.offset) { (_, busEstimate) in
                let etaFromNow = busEstimate.eta.timeDelta(since: now)

                VStack(alignment: .leading, spacing: 0) {
                    if etaFromNow < .zero {
                        Rectangle()
                            .fill(Color.gray)
                            .frame(height: etaFromNow.seconds / 60 * verticalScale * -1)
                            .opacity(0.5)
                    }

                    Rectangle()
                        .fill(Color.blue)
                        .frame(minHeight: 0)
                }
                .frame(width: 1, height: stopTimeRange.seconds / 60 * verticalScale)
                .padding(
                    .leading,
                    ( // 1st is regular time offset, 2nd is to align
                        (etaFromNow.seconds / 60 * horizontalScale) +
                        busHOffset
                    )
                )
                .padding(.top, firstStopVerticalOffset)
            }
        }
    }

    func timeTickers(lowerbound: Int, upperbound: Int, step: Int, geometrySize: CGSize, busHOffset: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            ForEach(lowerbound..<(upperbound + 1), id: \.self) { tickerIndex in
                TimeTicker(
                    verticalScale: verticalScale,
                    horizontalScale: horizontalScale,
                    ttGraphSize: .init(
                        width: geometrySize.width - stopLineAndLabelsWidth,
                        height: geometrySize.height
                    ),
                    scrollPosition: .init(
                        x: scrollPosition.x - busHOffset - (firstStopVerticalOffset * horizontalScale / verticalScale),
                        y: scrollPosition.y
                    ),
                    minutes: tickerIndex * step
                )
                .padding(.leading, stopLineAndLabelsWidth)
                .padding(.trailing, -timeTickerLabelsWidth) // reverse later padding
                .padding(.top, -timeTickerLabelsHeight) // reverse later padding
            }
        }
    }

    // calculates the horizontal offset (to the right) to transform all time-dependent objects by
    // such that the first bus is located at firstBusHorizontalOffset
    func busHorizontalOffset() -> CGFloat {
        guard let firstBus = estimates.first?.estimates.first else { return .zero }

        // leftwards adjustment such that the bus is located at the very left of the graph
        let leftwardsTare = firstBus.eta.timeDelta(since: now).seconds / 60 * horizontalScale
        // then adjust rightwards to be at the correct offset
        return -leftwardsTare + firstBusHorizontalOffset
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
