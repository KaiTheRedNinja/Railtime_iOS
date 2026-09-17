//
//  Journey+sampleData.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 17/9/26.
//

import Foundation

private let journeyId: UUID = .init(uuidString: "956B9872-555C-47BB-B37D-06A9DAE3528E")!
private let npNodeId: UUID = .init(uuidString: "91FA23F2-5FC5-4EE7-9A2F-5D6E3E87C762")!
private let oppCJCNodeId: UUID = .init(uuidString: "E6F7C1E8-4BA4-4EBD-90D4-537300882206")!
private let trellisTwrsNodeId: UUID = .init(uuidString: "DE3FCCCD-2221-4FD1-A196-D58845CC7A79")!
private let oppEunosStnNodeId: UUID = .init(uuidString: "A948D00A-0EB3-4FE4-AA72-7CA3787BA5F3")!
private let blk322NodeId: UUID = .init(uuidString: "79646C24-5B1D-4B6B-A7B6-393A69DCA11E")!

private let npToCJCLegId: UUID = .init(uuidString: "517B946F-637C-455E-A1F1-F3CF31A496ED")!
private let cjcToTrellisLegId: UUID = .init(uuidString: "3F225CE8-0DE5-4C23-9A3F-062C0B47630C")!
private let trellisToBlk322LegId: UUID = .init(uuidString: "76003C8A-652B-4379-910E-1E999395C657")!
private let cjcToEunosLegId: UUID = .init(uuidString: "B30D29E3-56E7-43C2-8BB3-6E7253D5B92D")!

extension Journey {
    public static let sampleJourney: Journey = .init(
        id: journeyId,
        startNodeId: npNodeId,
        nodes: [
            npNodeId: JourneyBusStopNode(
                id: npNodeId,
                busStopCode: "12101",
                nextLegIds: [npToCJCLegId]
            ),
            oppCJCNodeId: JourneyBusStopNode(
                id: oppCJCNodeId,
                busStopCode: "51091",
                nextLegIds: [cjcToTrellisLegId, cjcToEunosLegId]
            ),
            trellisTwrsNodeId: JourneyBusStopNode(
                id: trellisTwrsNodeId,
                busStopCode: "52071",
                nextLegIds: [trellisToBlk322LegId]
            ),
            oppEunosStnNodeId: JourneyBusStopNode(id: oppEunosStnNodeId, busStopCode: "83109", nextLegIds: []),
            blk322NodeId: JourneyBusStopNode(id: blk322NodeId, busStopCode: "72011", nextLegIds: []),
        ],
        legs: [
            npToCJCLegId: JourneyBusLeg(
                id: npToCJCLegId,
                serviceNo: "151",
                destinationId: oppCJCNodeId
            ),
            cjcToTrellisLegId: JourneyBusLeg(
                id: cjcToTrellisLegId,
                serviceNo: "151",
                destinationId: trellisTwrsNodeId
            ),
            cjcToEunosLegId: JourneyBusLeg(
                id: cjcToEunosLegId,
                serviceNo: "966",
                destinationId: oppEunosStnNodeId
            ),
            trellisToBlk322LegId: JourneyBusLeg(
                id: trellisToBlk322LegId,
                serviceNo: "5",
                destinationId: blk322NodeId
            )
        ],
        path: [
            npToCJCLegId,
            cjcToTrellisLegId,
            trellisToBlk322LegId
        ]
    )
}
