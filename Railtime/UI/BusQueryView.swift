//
//  BusQueryView.swift
//  Railtime
//
//  Created by Kai Quan Tay on 7/9/26.
//

import SwiftUI

struct BusQueryView: View {
    @AppStorage("start_id") var startId: String = ""
    @AppStorage("bus_id") var busId: String = ""
    @AppStorage("end_id") var endId: String = ""
    @AppStorage("est_count") var estimationCount: Int = 5

    @AppStorage("LTA_API_KEY") var apiKey: String = ""

    @State var journeyEstimator: BusJourneyEstimator? = nil

    @State var startInfo: LTABusStopInfo?
    @State var endInfo: LTABusStopInfo?

    @State var queryStatus: BusQueryStatus = .none

    enum BusQueryStatus {
        /// No query has been made
        case none
        /// Query has been sent, awaiting response
        case loading
        /// Query has failed with an error message
        case failed(any Error)
        /// Query succeeded
        case success([StopArrivalEstimates])
    }

    var body: some View {
        List {
            parameters
            if let journeyEstimator {
                confirmJourney(estimator: journeyEstimator)
            }
            switch queryStatus {
            case .none:
                EmptyView()
            case .loading:
                ProgressView()
                    .progressViewStyle(.circular)
            case .failed(let error):
                Text("Query failed: \(error)")
            case .success(let array):
                resultsView(estimates: array)
            }
        }
    }

    @ViewBuilder
    var parameters: some View {
        Section {
            HStack {
                Text("I am at")
                TextField("Starting bus stop ID", text: $startId)
                    .multilineTextAlignment(.trailing)
            }
            .listRowSeparator(.hidden)
            HStack {
                Text("Taking bus")
                TextField("Bus number", text: $busId)
                    .multilineTextAlignment(.trailing)
            }
            .listRowSeparator(.hidden)
            HStack {
                Text("To stop")
                TextField("Ending bus stop ID (optional)", text: $endId)
                    .multilineTextAlignment(.trailing)
            }
            .listRowSeparator(.hidden)
            HStack {
                Text("Tracking at least")
                Spacer()
                Picker("", selection: $estimationCount) {
                    ForEach(1..<11) { index in
                        Text("\(index)")
                            .tag(index)
                    }
                }
                Text(" busses")
            }
            .listRowSeparator(.hidden)
        }

        Section {
            HStack {
                Text("LTA Key")
                TextField("Your LTA API Key", text: $apiKey)
                    .multilineTextAlignment(.trailing)
            }
            .onChange(of: apiKey, initial: true) { _, newValue in
                if newValue != "" {
                    do {
                        let client = try LTAClient(accountKey: apiKey)
                        journeyEstimator = try .init(client: client)
                    } catch {
                        print("Client creation error: \(error)")
                    }
                }
            }
        }
    }

    func confirmJourney(estimator: BusJourneyEstimator) -> some View {
        Section {
            HStack {
                Text(startInfo?.description ?? "not specified")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.leading)
                Text("taking \(busId) to")
                Text(endInfo?.description ?? "not specified")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.trailing)
            }
            Button {
                estimator.now = .now
                Task {
                    queryStatus = .loading
                    do {
                        let estimates = try await estimator.estimate(
                            busStopCode: startId,
                            serviceNo: busId,
                            numTarget: estimationCount,
                            destinationStopCode: endId
                        )
                        queryStatus = .success(estimates)
                    } catch {
                        queryStatus = .failed(error)
                    }
                }
            } label: {
                Text("Go!")
                    .padding(10)
                    .frame(width: 200)
            }
            .buttonStyle(.borderedProminent)
            .padding(10)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: startId, initial: true) { _, newValue in
            Task {
                startInfo = try? await estimator.data.getStopInfo(busStopCode: newValue)
            }
        }
        .onChange(of: endId, initial: true) { _, newValue in
            if newValue == "" {
                endInfo = nil
                return
            }
            Task {
                endInfo = try? await estimator.data.getStopInfo(busStopCode: newValue)
            }
        }
    }

    func resultsView(estimates: [StopArrivalEstimates]) -> some View {
        var uniqueBusses: Set<String> = []
        var allBusses: [String] = []
        for stopEstimate in estimates {
            for busEstimate in stopEstimate.estimates where uniqueBusses.insert(busEstimate.busId).inserted {
                allBusses.append(busEstimate.busId)
            }
        }
        allBusses.sort() // we order busses in increasing order, so this should sort it properly
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        return ScrollView(.horizontal) {
            Grid(alignment: .topLeading, horizontalSpacing: 20, verticalSpacing: 20) {
                GridRow {
                    Text("Bus")
                        .bold()
                        .padding(5)
                    ForEach(estimates.enumerated(), id: \.offset) { (_, estimate) in
                        Text(estimate.stopId)
                            .bold()
                            .padding(5)
                            .background { Color.blue.opacity(0.2) }
                    }
                }
                ForEach(allBusses.enumerated(), id: \.offset) { (_, bus) in
                    GridRow {
                        Text(bus)
                            .bold()
                            .padding(5)
                            .background { Color.red.opacity(0.2) }
                        ForEach(estimates.enumerated(), id: \.offset) { (_, estimate) in
                            if let busEstimate = estimate.estimates.first(where: { $0.busId == bus }) {
                                HStack {
                                    Text(formatter.string(from: busEstimate.eta))
                                    switch busEstimate.source {
                                    case .live: Text("🚌")
                                    case .projected: Text("🔢")
                                    case .extrapolated: Text("🕑")
                                    }
                                }
                            } else {
                                Text("-")
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    BusQueryView()
}
