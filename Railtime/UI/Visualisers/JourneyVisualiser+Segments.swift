//
//  JourneyVisualiser+Segments.swift
//  Railtime
//
//  Created by Kai Quan Tay on 17/9/26.
//

import SwiftUI
import Journey
import BusEstimation
import LTAAPI

extension JourneyVisualiser {
    @ViewBuilder
    func vehicleSegment(
        forPathItem pathItem: JourneyLegID,
        yOffsetLegMap: [JourneyLegID: CGFloat],
        timeDeltaTranslation: [JourneyLegID: TimeDelta],
        geometrySize: CGSize,
        busHOffset: CGFloat
    ) -> some View {
        if let busLeg = manager.journey.leg(for: pathItem, as: JourneyBusLeg.self),
           let busContext = manager.context.context(forLeg: busLeg) {
            typedSegment(
                leg: busLeg,
                context: busContext,
                yOffsetLegMap: yOffsetLegMap,
                timeDeltaTranslation: timeDeltaTranslation,
                geometrySize: geometrySize,
                busHOffset: busHOffset
            )
        } else if let trainLeg = manager.journey.leg(for: pathItem, as: JourneyTrainLeg.self),
                  let trainContext = manager.context.context(forLeg: trainLeg) {
            typedSegment(
                leg: trainLeg,
                context: trainContext,
                yOffsetLegMap: yOffsetLegMap,
                timeDeltaTranslation: timeDeltaTranslation,
                geometrySize: geometrySize,
                busHOffset: busHOffset
            )
        } else if let walkLeg = manager.journey.leg(for: pathItem, as: JourneyWalkLeg.self),
                  let walkContext = manager.context.context(forLeg: walkLeg) {
            JourneyWalkVisualiser(
                context: walkContext,
                geometrySize: geometrySize,
                scrollPosition: scrollPosition, // no need to adjust Y scroll position, walk doesnt use it
                now: now,
                verticalScale: verticalScale,
                horizontalScale: horizontalScale,
                vehicleHOffset: busHOffset,
                namespace: namespace
            )
            .padding(.top, yOffsetLegMap[walkLeg.id] ?? 0)
        } // add any other leg types after here
    }

    @ViewBuilder
    func typedSegment<Leg>(
        leg: Leg,
        context: Leg.Context,
        yOffsetLegMap: [JourneyLegID: CGFloat],
        timeDeltaTranslation: [JourneyLegID: TimeDelta],
        geometrySize: CGSize,
        busHOffset: CGFloat
    ) -> some View where Leg: JourneyLeg, Leg.Context: JourneyStopBasedLegContext {
        let yOffset = yOffsetLegMap[leg.id] ?? 0
        let xOffset = (timeDeltaTranslation[leg.id] ?? .zero).seconds / 60 * horizontalScale

        JourneyPathItemVisualiser<Leg>(
            context: context,
            stopLookup: manager.context.nodeContext,
            isExtension: manager.isExtension(pathItem: leg.id),
            geometrySize: geometrySize,
            scrollPosition: .init(
                x: scrollPosition.x,
                y: scrollPosition.y - yOffset
            ),
            now: now,
            verticalScale: verticalScale,
            horizontalScale: horizontalScale,
            vehicleHOffset: busHOffset - xOffset,
            isCollapsedExt: .init(get: {
                isCollapsed[leg.id] ?? true
            }, set: { newCollapsedState in
                isCollapsed[leg.id] = newCollapsedState
            }),
            namespace: namespace
        )
        .padding(.top, yOffset)
    }

    @ViewBuilder
    func vehicleTransfer(
        otherLegId: JourneyLegID,
        sameLevelAs targetLegId: UUID,
        yOffsetLegMap: [JourneyLegID: CGFloat],
        timeDeltaTranslation: [JourneyLegID: TimeDelta],
        geometrySize: CGSize,
        busHOffset: CGFloat
    ) -> some View {
        if let busLeg = manager.journey.leg(for: otherLegId, as: JourneyBusLeg.self),
           let busContext = manager.context.context(forLeg: busLeg) {
            typedTransfer(
                leg: busLeg,
                sameLevelAs: targetLegId,
                context: busContext,
                yOffsetLegMap: yOffsetLegMap,
                timeDeltaTranslation: timeDeltaTranslation,
                geometrySize: geometrySize,
                busHOffset: busHOffset
            )
        } else if let trainLeg = manager.journey.leg(for: otherLegId, as: JourneyTrainLeg.self),
                  let trainContext = manager.context.context(forLeg: trainLeg) {
            typedTransfer(
                leg: trainLeg,
                sameLevelAs: targetLegId,
                context: trainContext,
                yOffsetLegMap: yOffsetLegMap,
                timeDeltaTranslation: timeDeltaTranslation,
                geometrySize: geometrySize,
                busHOffset: busHOffset
            )
        } else { // add any other leg types after here
            Text("Unknown leg")
        }
    }

    @ViewBuilder
    func typedTransfer<Leg>(
        leg: Leg,
        sameLevelAs targetLegId: UUID,
        context: Leg.Context,
        yOffsetLegMap: [JourneyLegID: CGFloat],
        timeDeltaTranslation: [JourneyLegID: TimeDelta],
        geometrySize: CGSize,
        busHOffset: CGFloat
    ) -> some View where Leg: JourneyLeg, Leg.Context: JourneyStopBasedLegContext {
        let yOffset = yOffsetLegMap[targetLegId] ?? 0
        let xOffset = (timeDeltaTranslation[targetLegId] ?? .zero).seconds / 60 * horizontalScale

        JourneyTransferVisualiser<Leg>(
            context: context,
            geometrySize: geometrySize,
            now: now,
            verticalScale: verticalScale,
            horizontalScale: horizontalScale,
            vehicleHOffset: busHOffset - xOffset,
            namespace: namespace
        )
        .padding(.top, yOffset)
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
                            width: max(0, geometrySize.width - Sizing.stopLineAndLabelsWidth),
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
}
