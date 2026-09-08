//
//  StopArrivalEstimates.swift
//  Railtime
//
//  Created by Kai Quan Tay on 6/9/26.
//

import Foundation

/// All the estimates for when busses will arrive at this stop.
struct StopArrivalEstimates {
    /// The ID of this stop.
    var stopId: String
    /// The delta-time of this stop, relative to some downstream target, in
    /// seconds (equivalent to the Python `timedelta` field of the same
    /// name).
    var deltaTime: TimeDelta
    /// The error in the delta-time of this stop, relative to some
    /// downstream target, in seconds.
    var deltaError: TimeDelta
    /// The arrival estimates, first.
    var estimates: [BusArrivalEstimate]

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
}
