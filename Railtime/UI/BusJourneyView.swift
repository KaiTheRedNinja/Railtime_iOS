//
//  BusJourneyView.swift
//  Railtime
//
//  Created by Kai Quan Tay on 10/9/26.
//

import SwiftUI

struct BusJourneyView: View {
    var estimates: [StopArrivalEstimates]
    var stopLookup: [String: LTABusStopInfo] = [:]

    // Number of points of spacing per minute, vertically
    var verticalScale: CGFloat = 40
    // Number of points of spacing per minute, horizontally. This value should never be larger than verticalScale
    var horizontalScale: CGFloat = 10

    // horizontal offset, in TimeDelta
    var horizontalOffset: TimeDelta = .zero

    // the current time
    @State var now: Date = .now

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
                ZStack(alignment: .topLeading) {
                    Spacer()
                        .frame(height: 1)

                    // time ticker labels
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
                .padding(.leading, 30)

                Divider()

                content(
                    stopTimeRange: stopTimeRange,
                    arrivalTimeRange: arrivalTimeRange,
                    tickerCount: tickerCount
                )
            }
            .navigationTitle("Bus 154")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    func content(stopTimeRange: TimeDelta, arrivalTimeRange: TimeDelta, tickerCount: Int) -> some View {
        OffsetScrollView { offset in
            HStack(alignment: .top, spacing: 0) {
                let stopLineWidth: CGFloat = 5
                let stopIndicatorDiameter: CGFloat = 10
                let busIndicatorDiameter: CGFloat = 20

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
                }
                .padding(.horizontal, 10)

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

                    // bus indexes
                    let busEarliestTimes = getBusEarliestTimes()
                    ForEach(busEarliestTimes.enumerated(), id: \.offset) { (_, earliestTiming) in
                        let offset = earliestTiming.eta.timeDelta(since: now)

                        if offset > .zero {
                            AngledLine(angle: .radians(atan(Double(verticalScale/horizontalScale))))
                                .stroke(Color.accentColor, lineWidth: 2)
                                .opacity(0.5)
                                .padding(.top, stopIndicatorDiameter/2) // offset to be on same height as indicators
                                .offset(y: (stopTimeRange - offset).seconds / 60 * verticalScale)
                        }
                    }

                    // bus information
                    ForEach(estimates, id: \.stopId) { stopEstimate in
                        ZStack(alignment: .topLeading) {
                            // horizontal line and name of bus stop
                            VStack(alignment: .leading, spacing: 2) {
                                Rectangle()
                                    .fill(Color.gray)
                                    .frame(height: 1)

                                Text(stopLookup[stopEstimate.stopId]?.description ?? stopEstimate.stopId)
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                            }

                            // bus indicators
                            ForEach(stopEstimate.estimates.enumerated(), id: \.offset) { (_, busEstimate) in
                                let etaFromNow = busEstimate.eta.timeDelta(since: now)

                                if etaFromNow > TimeDelta.zero {
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
                                        .offset(x: etaFromNow.seconds / 60 * horizontalScale)
                                }
                            }
                        }
                        .padding(
                            .top,
                            stopIndicatorDiameter/2 + // offset to be on same height as indicators
                            (stopTimeRange + stopEstimate.deltaTime).seconds / 60 * verticalScale  // offset but actual position rather than just visual
                        )
                    }
                }
                .mask {
                    Rectangle()
                        .fill(.black)
                        .blur(radius: 20)
                        .padding(.top, -30)
                        .padding(.all, -10)
                }

                Spacer()
            }
            .padding(.top, 30)
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
