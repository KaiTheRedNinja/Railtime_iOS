//
//  BusSegmentView.swift
//  Railtime
//
//  Created by Kai Quan Tay on 10/9/26.
//

import SwiftUI
import Combine

private let stopLineWidth: CGFloat = 5
private let stopIndicatorDiameter: CGFloat = 10
private let busIndicatorDiameter: CGFloat = 20
private let ttGraphLeadingPadding: CGFloat = 20

struct BusSegmentView: View {
    var estimates: [StopArrivalEstimates]
    var stopLookup: [String: LTABusStopInfo] = [:]

    // Number of points of spacing per minute, vertically
    var verticalScale: CGFloat = 40
    // Number of points of spacing per minute, horizontally. This value should never be larger than verticalScale
    @State var horizontalScale: CGFloat = 10
    @State var savedHorizontalScale: CGFloat = 10

    // the current time
    @State var now: Date = .now
    @State var nowRefreshTimer = Timer.publish(every: 0.1, on: .main, in: .default).autoconnect()

    // the current scroll position from the scroll view
    @State var scrollPosition: CGPoint = .zero

    var body: some View {
        // first we need to determine how large (horizontally and vertically) we need to be.

        // the time difference between the first and last stop time delta (ie. distance)
        let stopTimeRange = estimates.last!.deltaTime - estimates.first!.deltaTime
        // the time difference between the first and last bus arrival estimate
        let arrivalTimeRange = estimates.last!.estimates.last!.eta.timeDelta(since: .now)

        // we have tickers in 5 minute intervals for arrivals
        let tickerCount = Int((arrivalTimeRange.seconds / 60 / 5).rounded(.awayFromZero))

        NavigationStack {
            VStack(spacing: 0) {
                timeTickers(tickerCount: tickerCount)

                Divider()

                ScrollView([.horizontal, .vertical]) {
                    HStack(alignment: .top, spacing: 0) {
                        stopLine(stopTimeRange: stopTimeRange)
                            .offset(x: scrollPosition.x) // offset scroll position
                            .zIndex(2)

                        ttGraph(tickerCount: tickerCount, stopTimeRange: stopTimeRange)
                            .zIndex(1)

                        Spacer()
                    }
                    .padding(.top, 30)
                }
                .onScrollGeometryChange(for: CGPoint.self) { geo in
                    geo.contentOffset
                } action: { oldValue, newValue in
                    scrollPosition = newValue
                    print("New scroll position: \(scrollPosition)")
                }
                .simultaneousGesture(
                    MagnifyGesture(minimumScaleDelta: 0.05)
                        .onChanged { value in
                            withAnimation(.interactiveSpring) {
                                horizontalScale = max(8, min(savedHorizontalScale * value.magnification, verticalScale))
                            }
                            print("Horizontal scale changed to ", horizontalScale)
                        }
                        .onEnded { value in
                            withAnimation(.interactiveSpring) {
                                horizontalScale = max(8, min(savedHorizontalScale * value.magnification, verticalScale))
                                savedHorizontalScale = horizontalScale
                            }
                            print("Horizontal scale saved as ", horizontalScale)
                        }
                )
            }
            .navigationTitle("Bus 154")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onReceive(nowRefreshTimer) { _ in
            now = .now
        }
    }

    fileprivate func timeTickers(tickerCount: Int) -> some View {
        ZStack(alignment: .topLeading) {
            Spacer()
                .frame(height: 1)

            // time ticker labels
            Text("Now")
                .font(.caption)
                .foregroundStyle(Color.gray)
            ForEach(1..<(tickerCount+1), id: \.self) { tickerIndex in
                HStack(alignment: .bottom, spacing: 1) {
                    Rectangle()
                        .fill(Color.gray)
                        .opacity(0.5)
                        .frame(width: 1, height: 10)

                    Text("\(tickerIndex*5)min")
                        .font(.caption)
                        .foregroundStyle(Color.gray)
                }
                .offset(x: CGFloat(tickerIndex) * 5 * horizontalScale)
            }
        }
        .offset(x: -scrollPosition.x + ttGraphLeadingPadding)
        .padding(.leading, 30)
    }

    fileprivate func stopLine(stopTimeRange: TimeDelta) -> some View {
        ZStack(alignment: .top) {
            // stopline: the rectangle that goes from the top to the bottom
            Capsule()
                .fill(Color.green)
                .opacity(0.7)
                .frame(
                    width: stopLineWidth,
                    // adjust height so that timeDelta=0 is located at the center of the capsule's top semicircle
                    height: stopTimeRange.seconds / 60 * verticalScale + stopLineWidth
                )
                .padding(.vertical, (stopIndicatorDiameter - stopLineWidth)/2) // offset to be on same height as indicators

            // stop indicators
            ForEach(estimates, id: \.stopId) { estimate in
                Circle()
                    .fill(Color.green)
                    .frame(width: stopIndicatorDiameter, height: stopIndicatorDiameter)
                    .padding(
                        .top,
                        (stopTimeRange + estimate.deltaTime).seconds / 60 * verticalScale  // offset but actual position rather than just visual
                    )
            }

            // bus locations
            let busEarliestTimes = getBusEarliestTimes()
            ZStack(alignment: .topLeading) {
                ForEach(busEarliestTimes.enumerated(), id: \.offset) { (_, earliestTiming) in
                    let offset = earliestTiming.eta.timeDelta(since: now)

                    if offset > .zero, offset <= stopTimeRange { // dont show negative offsets, dont show ones too far away
                        Image(systemName: "bus")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Color.accentColor)
                            .frame(width: busIndicatorDiameter, height: busIndicatorDiameter)
                            .padding(.vertical, -stopLineWidth/2) // offset to be on same height as indicators
                            .offset(y: (stopTimeRange - offset).seconds / 60 * verticalScale)
                    }
                }
            }
        }
        .frame(width: 30)
        .background {
            ZStack(alignment: .trailing) {
                Color.white
                HStack { Divider() }
            }
            .padding(.top, -30)
            .offset(y: scrollPosition.y) // completely negate scroll
        }
    }

    @ViewBuilder
    fileprivate func ttGraph(tickerCount: Int, stopTimeRange: TimeDelta) -> some View {
        ZStack(alignment: .topLeading) {
            // time tickers
            ZStack(alignment: .topLeading) {
                ForEach(0..<(tickerCount+1), id: \.self) { tickerIndex in
                    Rectangle()
                        .fill(Color.gray)
                        .opacity(0.5)
                        .frame(width: 1)
                        .offset(x: CGFloat(tickerIndex) * 5 * horizontalScale)
                }
            }
            .padding(.vertical, -30)
            .offset(y: scrollPosition.y) // completely negate scroll
            .padding(.leading, ttGraphLeadingPadding)

            // bus diagonal lines
            let busEarliestTimes = getBusEarliestTimes()
            ZStack(alignment: .topLeading) {
                ForEach(busEarliestTimes.enumerated(), id: \.offset) { (_, earliestTiming) in
                    let offset = earliestTiming.eta.timeDelta(since: now)

                    if offset > .zero {
                        ZStack(alignment: .topLeading) {
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(width: ttGraphLeadingPadding - min(scrollPosition.x, 0), height: 2)
                                .offset(x: min(scrollPosition.x, 0))
                            AngledLine(angle: .radians(atan(Double(verticalScale/horizontalScale))))
                                .stroke(Color.accentColor, lineWidth: 2)
                                .offset(x: ttGraphLeadingPadding)
                        }
                        .padding(.top, stopIndicatorDiameter/2) // offset to be on same height as indicators
                        .opacity(0.5)
                        .offset(y: (stopTimeRange - offset).seconds / 60 * verticalScale)
                    }
                }
            }
            .mask {
                Rectangle()
                    .fill(.black)
                    .blur(radius: 20)
                    .padding(.top, -30)
                    .padding(.leading, min(scrollPosition.x, 0))
                    .padding(.all, -10)
            }

            // bus information
            ForEach(estimates.enumerated(), id: \.element.stopId) { (index, stopEstimate) in
                // if the previous one was less than 2x bus indicator diameter away from this one, show a mini version
                let useMini = index > 0 && (stopEstimate.deltaTime - estimates[index-1].deltaTime) <= .mins(20 / verticalScale)

                ZStack(alignment: .topLeading) {
                    // horizontal line and name of bus stop
                    VStack(alignment: .leading, spacing: 2) {
                        Rectangle()
                            .fill(Color.gray)
                            .frame(height: 1)

                        if !useMini {
                            Text(stopLookup[stopEstimate.stopId]?.description ?? stopEstimate.stopId)
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                                .padding(.leading, 2)
                        }
                    }
                    .padding(.leading, -ttGraphLeadingPadding) // completely negate leading padding
                    .offset(x: scrollPosition.x) // completely negate scroll

                    // bus indicators
                    ForEach(stopEstimate.estimates.enumerated(), id: \.offset) { (_, busEstimate) in
                        let etaFromNow = busEstimate.eta.timeDelta(since: now)

                        if etaFromNow > TimeDelta.zero {
                            Group {
                                if index + 1 < estimates.count {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: stopIndicatorDiameter, height: stopIndicatorDiameter)
                                        .offset( // make the bus appear ON the horizontal line, centered
                                            x: -(stopIndicatorDiameter)/2,
                                            y: -(stopIndicatorDiameter)/2
                                        )
                                } else {
                                    Text(busEstimate.busServiceNo)
                                        .font(.caption)
                                        .bold()
                                        .foregroundStyle(Color.white)
                                        .frame(width: busIndicatorDiameter + 4, height: busIndicatorDiameter - 6)
                                        .padding(3)
                                        .background {
                                            Capsule()
                                                .fill(Color.blue)
                                                .frame(height: busIndicatorDiameter)
                                        }
                                        .offset( // make the bus appear above the horizontal line, centered
                                            x: -(busIndicatorDiameter + 10)/2,
                                            y: -busIndicatorDiameter
                                        )
                                }
                            }
                            .padding(.leading, etaFromNow.seconds / 60 * horizontalScale)
                        }
                    }
                }
                .padding(
                    .top,
                    stopIndicatorDiameter/2 + // offset to be on same height as indicators
                    (stopTimeRange + stopEstimate.deltaTime).seconds / 60 * verticalScale  // offset but actual position rather than just visual
                )
                .padding(.leading, ttGraphLeadingPadding)
            }
        }
    }

    func getBusEarliestTimes() -> [(id: Int, eta: Date)] {
        var etaKeyedByBusId: [(Int, Date)] = []
        for stopEstimate in estimates {
            for busEstimate in stopEstimate.estimates {
                guard case let .ordered(index) = busEstimate.busId else { continue }
                // translate this to an ETA from the target stop
                etaKeyedByBusId.append((index, busEstimate.eta.incrementingBy(timeDelta: stopEstimate.deltaTime.scale(by: -1))))
            }
        }

        let keyed = [Int: Date].init(etaKeyedByBusId) { lhs, rhs in
            // whichever one has the earlier ETA survives, as it will be more accurate
            if lhs < rhs { lhs } else { rhs }
        }

        return keyed.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }
}
