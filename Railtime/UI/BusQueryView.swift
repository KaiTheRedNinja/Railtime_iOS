//
//  BusQueryView.swift
//  Railtime
//
//  Created by Kai Quan Tay on 7/9/26.
//

import SwiftUI
import Journey
import BusEstimation
import LTAAPI

struct BusQueryView: View {
    @AppStorage("start_id") var startId: String = ""
    @AppStorage("bus_id") var serviceNo: String = ""
    @AppStorage("end_id") var endId: String = ""
    @AppStorage("est_count") var estimationCount: Int = 5

    @AppStorage("LTA_API_KEY") var apiKey: String = ""

    @State var journeyEstimator: BusArrivalEstimator? = nil

    @State var startInfo: LTABusStopInfo?
    @State var endInfo: LTABusStopInfo?

    @State var queryStatus: BusQueryStatus = .none
    @State var stopLookup: [String: LTABusStopInfo] = [:]

    @State var showSheet: Bool = false

    enum BusQueryStatus: Equatable {
        // NOTE: this cannot differentiate between certain values of `failed` and `success`,
        // but can differentiate between cases.
        static func == (lhs: BusQueryView.BusQueryStatus, rhs: BusQueryView.BusQueryStatus) -> Bool {
            lhs.description == rhs.description
        }

        /// No query has been made
        case none
        /// Query has been sent, awaiting response
        case loading
        /// Query has failed with an error message
        case failed(any Error)
        /// Query succeeded
        case success([StopArrivalEstimates])

        var description: String {
            switch self {
            case .none: "none"
            case .loading: "loading"
            case .failed(let error): "failed(\(error.localizedDescription))"
            case .success(let array): "success(\(array.count) elements)"
            }
        }
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
                Text("Query failed: \(error.localizedDescription)")
            case .success(_):
//                BusTimingsView(estimates: array)
                Text("Showing sheet...")
                    .sheet(isPresented: $showSheet) {
//                        SkewedBusSegmentView(estimates: array, stopLookup: stopLookup)
                    }
            }
        }
        .onChange(of: queryStatus) { _, newValue in
            switch newValue {
            case .success: showSheet = true
            default: showSheet = false
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
                Text("Taking bus service")
                TextField("Bus number", text: $serviceNo)
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
                        journeyEstimator = .init(client: client)
                    } catch {
                        print("Client creation error: \(error)")
                    }
                }
            }
        }
    }

    func confirmJourney(estimator: BusArrivalEstimator) -> some View {
        Section {
            HStack {
                Text(startInfo?.description ?? "not specified")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.leading)
                Text("taking \(serviceNo) to")
                Text(endInfo?.description ?? "not specified")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.trailing)
            }
            Button {
                estimator.now = .now
                guard !startId.isEmpty, !endId.isEmpty else {
                    print("Need both start and end to be defined!")
                    return
                }

                Task {
                    queryStatus = .loading
                    print(estimator.data.cache.root)
                    do {
                        let rawEstimates = try await estimator.track(
                            stopIdsOfInterest: [startId, endId],
                            serviceNo: serviceNo
                        )
                        guard let startIndex = rawEstimates.firstIndex(where: { $0.stopId == startId }),
                              let endIndex = rawEstimates.lastIndex(where: { $0.stopId == endId }),
                              startIndex < endIndex else {
                            queryStatus = .failed(BusArrivalEstimatorError.stopNotFound(stopCode: startId, serviceNo: serviceNo))
                            return
                        }
                        let estimates = rawEstimates[startIndex...endIndex]

                        queryStatus = .success(Array(estimates))

                        for stop in estimates {
                            stopLookup[stop.stopId] = try await estimator.data.getStopInfo(busStopCode: stop.stopId)
                        }
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
            Button {
                loadSampleData(estimator: estimator)
            } label: {
                Text("Load Sample Data")
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
//        .onAppear {
//            loadSampleData(estimator: estimator)
//        }
    }

    func loadSampleData(estimator: BusArrivalEstimator) {
        let sampleData = StopArrivalEstimates.sampleData2
        queryStatus = .success(sampleData)

        Task {
            do {
                for stop in sampleData {
                    stopLookup[stop.stopId] = try await estimator.data.getStopInfo(busStopCode: stop.stopId)
                }
            } catch {
                print("Error loading sample data: \(sampleData)")
            }
        }
    }
}

#Preview {
    BusQueryView()
}
