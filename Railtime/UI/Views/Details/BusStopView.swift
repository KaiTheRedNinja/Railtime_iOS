import SwiftUI
import CoreLocation
import LTAAPI
import Combine
import BusEstimation

// MARK: - Bus Stop View (Live Bus Arrivals)

struct BusStopView: View {
    let busStop: BusStop
    var ltaService: LTAService
    var locationManager: LocationManager
    var effectiveCenter: CLLocationCoordinate2D
    var onTapDistance: ((CLLocationCoordinate2D, TransitPathItem) -> Void)?

    @State private var services: [String] = []
    @State private var arrivals: [BusServiceArrivals] = []
    @State private var sampleArrivals: [(serviceNo: String, eta: Date?, load: BusLoad?)] = []
    @State private var isLoading = true
    @State private var lastUpdated: Date? = nil

    @State private var now: Date = .now

    // Update the duration shown on screen every second
    var etaRefreshTimer = Timer.publish(every: 1, on: .main, in: .default).autoconnect()
    // Re-poll the API every 2 minutes
    var estimationRefreshTimer = Timer.publish(every: 60 * 2, on: .main, in: .default).autoconnect()

    var body: some View {
        List {
            Section {
                WrappingHStack(alignment: .leading) {
                    ForEach(sampleArrivals, id: \.serviceNo) { (serviceNo, eta, load) in
                        HStack(spacing: 4) {
                            Text(serviceNo)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)

                            if let load, let eta {
                                Circle()
                                    .fill(load.color)
                                    .frame(width: 6, height: 6)

                                let mins = Int((eta.timeIntervalSince(now) / 60).rounded(.towardZero))
                                Text(mins <= 0 ? "Arr" : "\(mins)m")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(mins == 0 ? .green : .secondary)
                            }
                        }
                        .font(.caption2)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color(.secondarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            Section {
                if isLoading {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Fetching live arrivals from LTA DataMall...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
                } else if arrivals.isEmpty {
                    ContentUnavailableView("No Bus Services", systemImage: "bus", description: Text("No live arrival information available for this stop right now."))
                } else {
                    ForEach(arrivals) { arrival in
                        NavigationLink(
                            value: TransitPathItem.busService(
                                BusServiceDetail(
                                    serviceNo: arrival.serviceNo,
                                    originStopCode: busStop.id
                                )
                            )
                        ) {
                            BusArrivalRow(arrival: arrival, now: now)
                        }
                    }
                }
            } header: {
                HStack {
                    if let updated = lastUpdated {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("Updated \(updated, style: .relative) ago")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                    }
                    Spacer()
                    Button {
                        Task { await loadData() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let dist = busStop.formattedDistance(from: effectiveCenter) {
                    Button {
                        onTapDistance?(busStop.coordinate, .busStop(busStop))
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text(dist)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .tint(Color.blue.opacity(0.25))
                        .foregroundStyle(Color(red: 0.2, green: 0.6, blue: 1.0))
                    }
                }
            }
        }
        // MARK: - Edge-to-Edge Header Area
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(busStop.iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(busStop.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        Text("\(busStop.roadName ?? "") • \(busStop.id)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black)
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
        .onReceive(estimationRefreshTimer) { _ in
            Task { await loadData() }
        }
        .onReceive(etaRefreshTimer) { _ in
            self.now = .now
        }
    }
    
    private func loadData() async {
        isLoading = arrivals.isEmpty
        guard let rawArrivals = try? await ltaService.estimator.getSingleStop(code: busStop.id, serviceNo: nil) else {
            print("Error getting arrivals")
            return
        }

        func compareBusIDs(lhs: String, rhs: String) -> Bool {
            let lhsNo = Int(lhs.trimmingCharacters(in: .letters))
            let rhsNo = Int(rhs.trimmingCharacters(in: .letters))

            // if both have valid numbers and their numbers are not the same
            if let lhsNo, let rhsNo, lhsNo != rhsNo { return lhsNo < rhsNo }
            // if either have an invalid number or their numbers are the same (i.e. one is express
            // one is not), sort by string
            return lhs < rhs
        }

        self.arrivals = rawArrivals
            .compactMap { arrival -> BusServiceArrivals? in
                guard let first = arrival.estimates.first, // has a first item
                      !arrival.estimates.dropFirst().contains(where: { $0.busServiceNo != first.busServiceNo }) // all services equal
                else { return nil }

                return BusServiceArrivals(
                    stopId: arrival.stopId,
                    serviceNo: first.busServiceNo,
                    operatorName: nil,
                    destinationCode: nil,
                    destinationName: nil,
                    arrivals: arrival.estimates
                )
            }
            .sorted { lhs, rhs in
                compareBusIDs(lhs: lhs.serviceNo, rhs: rhs.serviceNo)
            }
        self.services = ltaService.dataSource.getServices(busStopCode: busStop.busStopCode)?.sorted(by: compareBusIDs) ?? []

        self.sampleArrivals = []
        for service in services {
            guard let firstArrival = arrivals.first(where: { $0.serviceNo == service })?.arrivals.first else {
                sampleArrivals.append((service, nil, nil))
                continue
            }
            sampleArrivals.append((firstArrival.busServiceNo, firstArrival.eta, firstArrival.metadata.load))
        }

        lastUpdated = Date()
        isLoading = false
    }
}
