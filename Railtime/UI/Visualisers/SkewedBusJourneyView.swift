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
                HStack(alignment: .top, spacing: 0) {
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
                    }
                    .overlay(alignment: .trailing) { HStack { Divider() } }
                    .overlay(alignment: .top) { VStack { Divider() } }
                    .padding(.trailing, timeTickerLabelsWidth) // space for horizontal time tickers
                }
                .padding(.top, timeTickerLabelsHeight) // space for top time tickers
            }
            .background {
                Color.white // time tickers
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Bus 154")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
