//
//  StopArrivalEstimates+sampleData.swift
//  Railtime
//
//  Created by Kai Quan Tay on 10/9/26.
//

import Foundation

extension StopArrivalEstimates {
    static let sampleData: [StopArrivalEstimates] = [
        StopArrivalEstimates(
            stopId: "21019",
            deltaTime: TimeDelta(seconds: -1474.0),
            deltaError: TimeDelta(seconds: 76.5),
            estimates: [
                BusArrivalEstimate(
                    busId: BusArrivalEstimate.BusID.ordered(index: 3),
                    busServiceNo: "154",
                    eta: .now.addingTimeInterval(594),
                    source: BusArrivalEstimate.DataSource.live,
                    projectedFromStop: nil,
                    load: Optional(LTANextBusInfo.Load.seatsAvailable),
                    feature: Optional("WAB"),
                    busType: Optional(LTANextBusInfo.BusVariant.singleDeck)
                ),
                BusArrivalEstimate(
                    busId: BusArrivalEstimate.BusID.ordered(index: 4),
                    busServiceNo: "154",
                    eta: .now.addingTimeInterval(771),
                    source: BusArrivalEstimate.DataSource.live,
                    projectedFromStop: nil,
                    load: Optional(LTANextBusInfo.Load.seatsAvailable),
                    feature: Optional("WAB"),
                    busType: Optional(LTANextBusInfo.BusVariant.singleDeck)
                ),
                BusArrivalEstimate(
                    busId: BusArrivalEstimate.BusID.ordered(index: 5),
                    busServiceNo: "154",
                    eta: .now.addingTimeInterval(1338),
                    source: BusArrivalEstimate.DataSource.live,
                    projectedFromStop: nil,
                    load: Optional(LTANextBusInfo.Load.seatsAvailable),
                    feature: Optional("WAB"),
                    busType: Optional(LTANextBusInfo.BusVariant.singleDeck)
                )
            ]
        ),
        StopArrivalEstimates(
            stopId: "17189",
            deltaTime: TimeDelta(seconds: -797.5),
            deltaError: TimeDelta(seconds: 142.5),
            estimates: [
                BusArrivalEstimate(
                    busId: BusArrivalEstimate.BusID.ordered(index: 2),
                    busServiceNo: "154",
                    eta: .now.addingTimeInterval(128),
                    source: BusArrivalEstimate.DataSource.live,
                    projectedFromStop: nil,
                    load: Optional(LTANextBusInfo.Load.seatsAvailable),
                    feature: Optional("WAB"),
                    busType: Optional(LTANextBusInfo.BusVariant.doubleDeck)
                ),
                BusArrivalEstimate(
                    busId: BusArrivalEstimate.BusID.ordered(index: 3),
                    busServiceNo: "154",
                    eta: .now.addingTimeInterval(1271),
                    source: BusArrivalEstimate.DataSource.live,
                    projectedFromStop: nil,
                    load: Optional(LTANextBusInfo.Load.seatsAvailable),
                    feature: Optional("WAB"),
                    busType: Optional(LTANextBusInfo.BusVariant.singleDeck)
                ),
                BusArrivalEstimate(
                    busId: BusArrivalEstimate.BusID.ordered(index: 4),
                    busServiceNo: "154",
                    eta: .now.addingTimeInterval(1447),
                    source: BusArrivalEstimate.DataSource.live,
                    projectedFromStop: nil,
                    load: Optional(LTANextBusInfo.Load.seatsAvailable),
                    feature: Optional("WAB"),
                    busType: Optional(LTANextBusInfo.BusVariant.singleDeck)
                ),
                BusArrivalEstimate(
                    busId: BusArrivalEstimate.BusID.ordered(index: 5),
                    busServiceNo: "154",
                    eta: .now.addingTimeInterval(2014),
                    source: BusArrivalEstimate.DataSource.projected,
                    projectedFromStop: Optional("21019"),
                    load: Optional(LTANextBusInfo.Load.seatsAvailable),
                    feature: Optional("WAB"),
                    busType: Optional(LTANextBusInfo.BusVariant.singleDeck)
                )
            ]
        ),
        StopArrivalEstimates(
            stopId: "12061",
            deltaTime: TimeDelta(seconds: -295.0),
            deltaError: TimeDelta(seconds: 20.0),
            estimates: [
                BusArrivalEstimate(
                    busId: BusArrivalEstimate.BusID.ordered(index: 1),
                    busServiceNo: "154",
                    eta: .now.addingTimeInterval(139),
                    source: BusArrivalEstimate.DataSource.live,
                    projectedFromStop: nil,
                    load: Optional(LTANextBusInfo.Load.seatsAvailable),
                    feature: Optional("WAB"),
                    busType: Optional(LTANextBusInfo.BusVariant.doubleDeck)
                ),
                BusArrivalEstimate(
                    busId: BusArrivalEstimate.BusID.ordered(index: 2),
                    busServiceNo: "154",
                    eta: .now.addingTimeInterval(642),
                    source: BusArrivalEstimate.DataSource.live,
                    projectedFromStop: nil,
                    load: Optional(LTANextBusInfo.Load.seatsAvailable),
                    feature: Optional("WAB"),
                    busType: Optional(LTANextBusInfo.BusVariant.doubleDeck)
                ),
                BusArrivalEstimate(
                    busId: BusArrivalEstimate.BusID.ordered(index: 3),
                    busServiceNo: "154",
                    eta: .now.addingTimeInterval(1762),
                    source: BusArrivalEstimate.DataSource.live,
                    projectedFromStop: nil,
                    load: Optional(LTANextBusInfo.Load.seatsAvailable),
                    feature: Optional("WAB"),
                    busType: Optional(LTANextBusInfo.BusVariant.singleDeck)
                ),
                BusArrivalEstimate(
                    busId: BusArrivalEstimate.BusID.ordered(index: 4),
                    busServiceNo: "154",
                    eta: .now.addingTimeInterval(1949),
                    source: BusArrivalEstimate.DataSource.projected,
                    projectedFromStop: Optional("17189"),
                    load: Optional(LTANextBusInfo.Load.seatsAvailable),
                    feature: Optional("WAB"),
                    busType: Optional(LTANextBusInfo.BusVariant.singleDeck)
                ),
                BusArrivalEstimate(
                    busId: BusArrivalEstimate.BusID.ordered(index: 5),
                    busServiceNo: "154",
                    eta: .now.addingTimeInterval(2517),
                    source: BusArrivalEstimate.DataSource.projected,
                    projectedFromStop: Optional("21019"),
                    load: Optional(LTANextBusInfo.Load.seatsAvailable),
                    feature: Optional("WAB"),
                    busType: Optional(LTANextBusInfo.BusVariant.singleDeck)
                )
            ]
        ),
        StopArrivalEstimates(
            stopId: "12101",
            deltaTime: TimeDelta(seconds: 0.0),
            deltaError: TimeDelta(seconds: 0.0),
            estimates: [
                BusArrivalEstimate(
                    busId: BusArrivalEstimate.BusID.ordered(index: 0),
                    busServiceNo: "154",
                    eta: .now.addingTimeInterval(-140),
                    source: BusArrivalEstimate.DataSource.live,
                    projectedFromStop: nil,
                    load: Optional(LTANextBusInfo.Load.seatsAvailable),
                    feature: Optional("WAB"),
                    busType: Optional(LTANextBusInfo.BusVariant.singleDeck)
                ),
                BusArrivalEstimate(
                    busId: BusArrivalEstimate.BusID.ordered(index: 1),
                    busServiceNo: "154",
                    eta: .now.addingTimeInterval(454),
                    source: BusArrivalEstimate.DataSource.live,
                    projectedFromStop: nil,
                    load: Optional(LTANextBusInfo.Load.seatsAvailable),
                    feature: Optional("WAB"),
                    busType: Optional(LTANextBusInfo.BusVariant.doubleDeck)
                ),
                BusArrivalEstimate(
                    busId: BusArrivalEstimate.BusID.ordered(index: 2),
                    busServiceNo: "154",
                    eta: .now.addingTimeInterval(917),
                    source: BusArrivalEstimate.DataSource.live,
                    projectedFromStop: nil,
                    load: Optional(LTANextBusInfo.Load.seatsAvailable),
                    feature: Optional("WAB"),
                    busType: Optional(LTANextBusInfo.BusVariant.doubleDeck)
                ),
                BusArrivalEstimate(
                    busId: BusArrivalEstimate.BusID.ordered(index: 3),
                    busServiceNo: "154",
                    eta: .now.addingTimeInterval(2057),
                    source: BusArrivalEstimate.DataSource.projected,
                    projectedFromStop: Optional("12061"),
                    load: Optional(LTANextBusInfo.Load.seatsAvailable),
                    feature: Optional("WAB"),
                    busType: Optional(LTANextBusInfo.BusVariant.singleDeck)
                ),
                BusArrivalEstimate(
                    busId: BusArrivalEstimate.BusID.ordered(index: 4),
                    busServiceNo: "154",
                    eta: .now.addingTimeInterval(2244),
                    source: BusArrivalEstimate.DataSource.projected,
                    projectedFromStop: Optional("17189"),
                    load: Optional(LTANextBusInfo.Load.seatsAvailable),
                    feature: Optional("WAB"),
                    busType: Optional(LTANextBusInfo.BusVariant.singleDeck)
                ),
                BusArrivalEstimate(
                    busId: BusArrivalEstimate.BusID.ordered(index: 5),
                    busServiceNo: "154",
                    eta: .now.addingTimeInterval(2812),
                    source: BusArrivalEstimate.DataSource.projected,
                    projectedFromStop: Optional("21019"),
                    load: Optional(LTANextBusInfo.Load.seatsAvailable),
                    feature: Optional("WAB"),
                    busType: Optional(LTANextBusInfo.BusVariant.singleDeck)
                )
            ]
        )
    ]

    private typealias BusID = BusArrivalEstimate.BusID

    private static let referenceTimeInterval: TimeInterval = 810724892.03225994

    static let sampleData2: [StopArrivalEstimates] = [
        StopArrivalEstimates(
            stopId: "20029",
            deltaTime: TimeDelta(seconds: -1091.4999999999998),
            deltaError: TimeDelta(seconds: 29.666666666666664),
            estimates: [
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 2),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810725092.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .standingAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 3),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810725386.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 4),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810726111.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .doubleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 5),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810726621.0) - referenceTimeInterval),
                    source: .extrapolated
                ),
            ]
        ),
        StopArrivalEstimates(
            stopId: "17059",
            deltaTime: TimeDelta(seconds: -1001.1666666666665),
            deltaError: TimeDelta(seconds: 76.0),
            estimates: [
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 2),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810725182.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .standingAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 3),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810725475.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 4),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810726203.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .doubleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 5),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810726711.3333334) - referenceTimeInterval),
                    source: .extrapolated
                ),
            ]
        ),
        StopArrivalEstimates(
            stopId: "17189",
            deltaTime: TimeDelta(seconds: -865.1666666666665),
            deltaError: TimeDelta(seconds: 3.0),
            estimates: [
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 2),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810725314.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .standingAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 3),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810725613.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 4),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810726341.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .doubleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 5),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810726847.3333334) - referenceTimeInterval),
                    source: .extrapolated
                ),
            ]
        ),
        StopArrivalEstimates(
            stopId: "17179",
            deltaTime: TimeDelta(seconds: -803.1666666666665),
            deltaError: TimeDelta(seconds: 34.0),
            estimates: [
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 1),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810724793.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .standingAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 2),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810725373.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .standingAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 3),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810725678.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 4),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810726403.0) - referenceTimeInterval),
                    source: .projected,
                    projectedFromStop: "17189",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .doubleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 5),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810726909.3333334) - referenceTimeInterval),
                    source: .extrapolated
                ),
            ]
        ),
        StopArrivalEstimates(
            stopId: "17169",
            deltaTime: TimeDelta(seconds: -709.1666666666665),
            deltaError: TimeDelta(seconds: 120.66666666666666),
            estimates: [
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 1),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810724887.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .standingAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 2),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810725461.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .standingAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 3),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810725778.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 4),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810726497.0) - referenceTimeInterval),
                    source: .projected,
                    projectedFromStop: "17189",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .doubleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 5),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810727003.3333334) - referenceTimeInterval),
                    source: .extrapolated
                ),
            ]
        ),
        StopArrivalEstimates(
            stopId: "17159",
            deltaTime: TimeDelta(seconds: -588.4999999999999),
            deltaError: TimeDelta(seconds: 58.666666666666664),
            estimates: [
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 1),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810725001.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .standingAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 2),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810725585.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .standingAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 3),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810725902.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 4),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810726617.6666666) - referenceTimeInterval),
                    source: .projected,
                    projectedFromStop: "17189",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .doubleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 5),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810727124.0) - referenceTimeInterval),
                    source: .extrapolated
                ),
            ]
        ),
        StopArrivalEstimates(
            stopId: "17101",
            deltaTime: TimeDelta(seconds: -469.8333333333333),
            deltaError: TimeDelta(seconds: 18.0),
            estimates: [
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 1),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810725118.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .standingAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 2),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810725705.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .standingAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 3),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810726021.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 4),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810726736.3333334) - referenceTimeInterval),
                    source: .projected,
                    projectedFromStop: "17189",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .doubleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 5),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810727242.6666666) - referenceTimeInterval),
                    source: .extrapolated
                ),
            ]
        ),
        StopArrivalEstimates(
            stopId: "17111",
            deltaTime: TimeDelta(seconds: -367.8333333333333),
            deltaError: TimeDelta(seconds: 1.0),
            estimates: [
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 1),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810725211.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .standingAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 2),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810725811.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .standingAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 3),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810726128.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 4),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810726838.3333334) - referenceTimeInterval),
                    source: .projected,
                    projectedFromStop: "17189",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .doubleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 5),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810727344.6666666) - referenceTimeInterval),
                    source: .extrapolated
                ),
            ]
        ),
        StopArrivalEstimates(
            stopId: "12061",
            deltaTime: TimeDelta(seconds: -307.5),
            deltaError: TimeDelta(seconds: 26.5),
            estimates: [
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 1),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810725270.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .standingAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 2),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810725872.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .standingAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 3),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810726189.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 4),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810726898.6666666) - referenceTimeInterval),
                    source: .projected,
                    projectedFromStop: "17189",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .doubleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 5),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810727405.0) - referenceTimeInterval),
                    source: .extrapolated
                ),
            ]
        ),
        StopArrivalEstimates(
            stopId: "12071",
            deltaTime: TimeDelta(seconds: -221.0),
            deltaError: TimeDelta(seconds: 22.0),
            estimates: [
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 0),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810724812.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .doubleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 1),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810725356.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .standingAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 2),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810725959.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .standingAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 3),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810726275.5) - referenceTimeInterval),
                    source: .projected,
                    projectedFromStop: "12061",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 4),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810726985.1666666) - referenceTimeInterval),
                    source: .projected,
                    projectedFromStop: "17189",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .doubleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 5),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810727491.5) - referenceTimeInterval),
                    source: .extrapolated
                ),
            ]
        ),
        StopArrivalEstimates(
            stopId: "12081",
            deltaTime: TimeDelta(seconds: -123.0),
            deltaError: TimeDelta(seconds: 28.666666666666664),
            estimates: [
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 0),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810724909.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .doubleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 1),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810725452.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .standingAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 2),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810726060.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .standingAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 3),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810726373.5) - referenceTimeInterval),
                    source: .projected,
                    projectedFromStop: "12061",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 4),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810727083.1666666) - referenceTimeInterval),
                    source: .projected,
                    projectedFromStop: "17189",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .doubleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 5),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810727589.5) - referenceTimeInterval),
                    source: .extrapolated
                ),
            ]
        ),
        StopArrivalEstimates(
            stopId: "12091",
            deltaTime: TimeDelta(seconds: -91.66666666666666),
            deltaError: TimeDelta(seconds: 31.666666666666664),
            estimates: [
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 0),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810724941.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .doubleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 1),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810725483.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .standingAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 2),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810726091.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .standingAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 3),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810726404.8333334) - referenceTimeInterval),
                    source: .projected,
                    projectedFromStop: "12061",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 4),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810727114.5) - referenceTimeInterval),
                    source: .projected,
                    projectedFromStop: "17189",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .doubleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 5),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810727620.8333334) - referenceTimeInterval),
                    source: .extrapolated
                ),
            ]
        ),
        StopArrivalEstimates(
            stopId: "12101",
            deltaTime: TimeDelta(seconds: 0.0),
            deltaError: TimeDelta(seconds: 0.0),
            estimates: [
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 0),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810725026.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .doubleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 1),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810725578.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .standingAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 2),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810726186.0) - referenceTimeInterval),
                    source: .live,
                    projectedFromStop: "WAB",
                    load: .standingAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 3),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810726496.5) - referenceTimeInterval),
                    source: .projected,
                    projectedFromStop: "12061",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .singleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 4),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810727206.1666666) - referenceTimeInterval),
                    source: .projected,
                    projectedFromStop: "17189",
                    load: .seatsAvailable,
                    feature: "WAB",
                    busType: .doubleDeck
                ),
                BusArrivalEstimate(
                    busId: BusID.ordered(index: 5),
                    busServiceNo: "154",
                    eta: Date.now.addingTimeInterval((810727712.5) - referenceTimeInterval),
                    source: .extrapolated
                ),
            ]
        ),
    ]
}
