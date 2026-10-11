//
//  Annotations.swift
//  Railtime
//
//  Created by Kai Quan Tay on 11/10/26.
//

import SwiftUI
import LTAAPI

struct TrainAnnotation: View {
    @ObservedObject var manager: TransitMapManager
    let station: LTATrainStopInfo

    var body: some View {
        Group {
            if manager.showMRTStations {
                StationCodeCapletView(station: station)
            } else {
                StationCodeMiniCapletView(station: station)
            }
        }
        .scaleEffect(manager.stationCapletScale)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.85), value: manager.stationCapletScale)
        .onTapGesture {
            manager.selectAndNavigateTo(item: .trainStop(station), atRoot: true)
        }
    }
}

struct BusAnnotation: View {
    @ObservedObject var manager: TransitMapManager
    let stop: LTABusStopInfo

    var body: some View {
        Group {
            if manager.showBusStops {
                Image(stop.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .padding(5)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                    .contentShape(Circle())
            } else if manager.showMRTStations {
                Circle()
                    .foregroundStyle(.blue)
                    .frame(width: 10, height: 10)
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
            }
        }
        .scaleEffect(manager.detailIconScale)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.85), value: manager.detailIconScale)
        .onTapGesture {
            manager.selectAndNavigateTo(item: .busStop(stop), atRoot: true)
        }
    }
}

struct ExitAnnotation: View {
    @ObservedObject var manager: TransitMapManager
    let exit: LTATrainStopInfo.Exit

    var body: some View {
        StationExitIconView(exitCode: exit.code, size: 24)
            .scaleEffect(manager.detailIconScale)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.85), value: manager.detailIconScale)
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            .onTapGesture {
                // TODO: make this work
                //                manager.selectAndNavigateTo(item: .trainStop(station), atRoot: true)
            }
    }
}
