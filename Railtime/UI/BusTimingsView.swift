//
//  BusTimingsView.swift
//  Railtime
//
//  Created by Kai Quan Tay on 8/9/26.
//

import SwiftUI

struct BusTimingsView: View {
    var estimates: [StopArrivalEstimates]

    var scale: CGFloat = 10 // 10 points of spacing per minute

    var body: some View {
        // first we need to determine how large (horizontally and vertically) we need to be.
        // width  = scale * time delta between the latest and earliest bus stops
        // height = scale * time to the furthest away bus

        let estTimeRange = estimates.last!.deltaTime - estimates.first!.deltaTime
        let width = estTimeRange.seconds / 60 * scale
        let estTimeDomain = estimates.last!.estimates.last!.eta.timeDelta(since: .now)
        let height = estTimeDomain.seconds / 60 * scale

        Grid(
            alignment: .topLeading,
            horizontalSpacing: 20,
            verticalSpacing: 20
        ) {
            GridRow {
                Text("mins")
                    .font(.caption)
                    .frame(width: 40, height: 40, alignment: .bottomTrailing)

                ZStack(alignment: .bottomLeading) {
                    Spacer()
                        .frame(width: width + 40, height: 40)
                    ForEach(estimates.enumerated(), id: \.offset) { (_, estimate) in
                        Text(estimate.stopId)
                            .frame(width: 100, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .font(.caption)
                            .rotationEffect(.degrees(-45), anchor: .bottomLeading)
                            .offset(x: (estTimeRange + estimate.deltaTime).seconds / 60 * scale)
                    }
                }
                .frame(width: width + 40, height: 40)
            }

            GridRow {
                // we have tickers in 5 minute intervals
                let tickerCount = Int((estTimeDomain.seconds / 60 / 5).rounded(.awayFromZero))

                ZStack(alignment: .topTrailing) {
                    Spacer()
                        .frame(width: 40, height: height + 40)

                    ForEach(0..<(tickerCount + 1), id: \.self) { tickerIndex in
                        Text("\(tickerIndex * 5)")
                            .font(.caption)
                            .offset(y: CGFloat(tickerIndex) * scale * 5 - 8)
                    }
                }
                .frame(width: 40, height: height + 40)

                timeTimeGraph(
                    estTimeRange: estTimeRange,
                    width: width,
                    estTimeDomain: estTimeDomain,
                    height: height,
                    tickerCount: tickerCount
                )
            }
        }

        EmptyView()
    }

    func timeTimeGraph(
        estTimeRange: TimeDelta,
        width: CGFloat,
        estTimeDomain: TimeDelta,
        height: CGFloat,
        tickerCount: Int
    ) -> some View {
        ZStack(alignment: .topLeading) {
            Spacer()
                .frame(width: width + 40, height: height + 40)

            // tickers
            ForEach(0..<(tickerCount + 1), id: \.self) { tickerIndex in
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: width + 40, height: 1)
                    .offset(x: -10, y: CGFloat(tickerIndex) * scale * 5)
            }

            // guides for bus stops
            ForEach(estimates.enumerated(), id: \.offset) { (_, estimate) in
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: 1, height: height + 40)
                    .offset(x: (estTimeRange + estimate.deltaTime).seconds / 60 * scale, y: -10)
            }

            // bus dots
            let allBusses = getAllBusses()
            ForEach(allBusses.enumerated(), id: \.offset) { (_, bus) in
                ForEach(estimates.enumerated(), id: \.offset) { (_, stopEstimate) in
                    if let busEstimate = stopEstimate.estimates.first(where: { $0.busId == .ordered(index: bus) }) {
                        let etaDelta = busEstimate.eta.timeDelta(since: .now)
                        let yOffset = etaDelta.seconds / 60 * scale
                        let shapeFillColor = if etaDelta > .zero { Color.blue } else { Color.green }

                        Group {
                            Group {
                                switch busEstimate.source {
                                case .live: Image(systemName: "star.fill").foregroundStyle(shapeFillColor)
                                case .projected: Image(systemName: "circle.fill").foregroundStyle(shapeFillColor)
                                case .extrapolated: Image(systemName: "circle.dotted").foregroundStyle(shapeFillColor)
                                }
                            }
                            .frame(width: 10, height: 10, alignment: .center)
                            .offset(x: -5, y: -5)

                            let minutes = Int((etaDelta.seconds / 60).rounded(.towardZero))
                            Text("\(minutes) min")
                                .font(.caption)
                                .offset(x: 10, y: -10)
                        }
                        .offset(
                            x: (estTimeRange + stopEstimate.deltaTime).seconds / 60 * scale,
                            y: max(0, yOffset)
                        )
                    }
                }
            }

            // bus lines. We use the earliest estimation for each bus.
            let busEarliestTimes = getBusEarliestTimes()
            ForEach(busEarliestTimes.enumerated(), id: \.offset) { (_, earliestTiming) in
                let offset = earliestTiming.eta.timeDelta(since: .now)

                if offset > .zero {
                    DiagonalLine()
                        .stroke(Color.accentColor, lineWidth: 2)
                        .frame(width: offset.seconds / 60 * scale)
                        .padding(.leading, (estTimeRange - offset).seconds / 60 * scale)
                        .opacity(0.75)
                }
            }
        }
        .mask {
            Rectangle()
                .fill(.black)
                .blur(radius: 20)
                .padding(.all, -10)
        }
    }

    func getAllBusses() -> [Int] {
        var uniqueBusses: Set<Int> = []
        var allBusses: [Int] = []
        for stopEstimate in estimates {
            for busEstimate in stopEstimate.estimates {
                guard case let .ordered(index) = busEstimate.busId, uniqueBusses.insert(index).inserted else { continue }
                allBusses.append(index)
            }
        }
        allBusses.sort() // we order busses in increasing order, so this should sort it properly

        return allBusses
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

struct DiagonalLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: .init(x: rect.minX, y: rect.minY))
            path.addLine(to: .init(x: rect.maxX, y: rect.minY + rect.width))
        }
    }
}
