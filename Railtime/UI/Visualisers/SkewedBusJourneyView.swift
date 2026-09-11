//
//  SkewedBusJourneyView.swift
//  Railtime
//
//  Created by Kai Quan Tay on 11/9/26.
//

import SwiftUI
import Combine

private let stopLineWidth: CGFloat = 5
private let stopIndicatorDiameter: CGFloat = 10
private let busIndicatorDiameter: CGFloat = 20

private let stopLineAndLabelsWidth: CGFloat = 100
private let timeTickerLabelsHeight: CGFloat = 20
private let timeTickerLabelsWidth: CGFloat = 30

private let firstStopVerticalOffset: CGFloat = 20
private let stopsHorizontalOffset: CGFloat = 15

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

    // whether or not the view is collapsed
    @State var isCollapsed: Bool = false

    var body: some View {
        // first we need to determine how large (horizontally and vertically) we need to be.

        // the time difference between the first and last stop time delta (ie. distance)
        let stopTimeRange = estimates.last!.deltaTime - estimates.first!.deltaTime
        // the time difference between the first and last bus arrival estimate
        let arrivalTimeRange = estimates.last!.estimates.last!.eta.timeDelta(since: .now)

        // we have tickers in 5 minute intervals for arrivals
        let tickerCount = Int((arrivalTimeRange.seconds / 60 / 5).rounded(.awayFromZero))

        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // stop line and tt graph
                GeometryReader { geometry in
                    ScrollView([.horizontal, .vertical]) {
                        VStack {
                            HStack(alignment: .top, spacing: 0) {
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
                                .offset(x: scrollPosition.x)
                                .zIndex(2)

                                // tt graph
                                ZStack(alignment: .topLeading) {
                                    ForEach(estimates, id: \.stopId) { stopEstimate in
                                        ZStack(alignment: .leading) {
                                            // horizontal line for the stop
                                            Rectangle()
                                                .fill(Color.gray)
                                                .frame(
                                                    width: max(100, geometry.size.width - stopLineAndLabelsWidth),
                                                    height: 1
                                                )
                                                .offset(x: scrollPosition.x)

                                            // bus indicators
                                            ForEach(stopEstimate.estimates.enumerated(), id: \.offset) { (_, busEstimate) in
                                                let etaFromNow = busEstimate.eta.timeDelta(since: now)

                                                let horizontalOffset = ( // 1st is regular time offset, 2nd is to actually skew the time
                                                    (etaFromNow.seconds / 60 * horizontalScale) -
                                                    ((stopTimeRange + stopEstimate.deltaTime).seconds / 60 * horizontalScale)
                                                )

                                                if horizontalOffset >= 0 {
                                                    Circle()
                                                        .fill(Color.blue)
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
                                                            + geometry.size.width - stopLineAndLabelsWidth,
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

                                        Rectangle()
                                            .fill(Color.blue)
                                            .frame(width: 1, height: stopTimeRange.seconds / 60 * verticalScale)
                                            .padding(
                                                .leading,
                                                ( // 1st is regular time offset, 2nd is to actually skew the time
                                                    (etaFromNow.seconds / 60 * horizontalScale)
                                                )
                                            )
                                            .padding(.top, firstStopVerticalOffset)
                                    }
                                }
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
                    .background {
                        ForEach(0..<(tickerCount + 1), id: \.self) { tickerIndex in
                            TimeTicker(
                                verticalScale: verticalScale,
                                horizontalScale: horizontalScale,
                                ttGraphSize: .init(
                                    width: geometry.size.width - stopLineAndLabelsWidth,
                                    height: geometry.size.height
                                ),
                                scrollPosition: scrollPosition,
                                minutes: tickerIndex * 5
                            )
                            .padding(.leading, stopLineAndLabelsWidth)
                            .padding(.trailing, -timeTickerLabelsWidth) // reverse later padding
                            .padding(.top, -timeTickerLabelsHeight) // reverse later padding
                        }
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
        let xOffset = min(ttGraphSize.width, CGFloat(minutes) * horizontalScale)
        let yOffset = max(0, (CGFloat(minutes) - (ttGraphSize.width/horizontalScale)) * verticalScale)

        ZStack(alignment: .bottomLeading) {
            Path { path in
                path.move(to: .init(x: 0, y: CGFloat(minutes) * verticalScale))
                path.addLine(to: .init(x: xOffset, y: yOffset))
            }
            .stroke(Color.gray, style: .init(lineWidth: 1, lineCap: .round, lineJoin: .round, miterLimit: 0, dash: [5, 5], dashPhase: 0))
            .frame(width: ttGraphSize.width, height: ttGraphSize.height)
            .clipShape(Rectangle())

            Path { path in
                path.move(to: .init(x: xOffset, y: yOffset + timeTickerLabelsHeight))

                if yOffset > 0 { // if there is a y-offset, draw a horizontal line
                    path.addLine(to: .init(x: ttGraphSize.width + timeTickerLabelsWidth/2, y: yOffset + timeTickerLabelsHeight))
                } else { // else, draw a vertical line
                    path.addLine(to: .init(x: xOffset, y: timeTickerLabelsHeight/2))
                }
            }
            .stroke(Color.gray, lineWidth: 1)
            .frame(
                width: ttGraphSize.width + timeTickerLabelsWidth,
                height: ttGraphSize.height + timeTickerLabelsHeight
            )
            .clipShape(Rectangle())
        }
        .overlay(alignment: .topLeading) {
            ZStack(alignment: .bottomLeading) {
                let label = if minutes == 0 { "now" } else { "\(minutes)m" }

                Text(label)
                    .font(.caption)
                    .offset(x: xOffset, y: yOffset)
            }
            .padding(3)
            .frame(height: timeTickerLabelsHeight)
        }
    }
}
