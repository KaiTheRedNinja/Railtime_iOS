import SwiftUI
import CoreLocation

// MARK: - Bus Stop View (Live Bus Arrivals)

struct BusStopView: View {
    let busStop: BusStop
    var ltaService: LTAService
    var locationManager: LocationManager
    var effectiveCenter: CLLocationCoordinate2D
    var onTapDistance: ((CLLocationCoordinate2D, TransitItem) -> Void)?
    
    @State private var arrivals: [BusArrival] = []
    @State private var isLoading = true
    @State private var lastUpdated: Date? = nil
    
    var body: some View {
        List {
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
                        NavigationLink(value: BusServiceDetail(serviceNo: arrival.serviceNo, originStopCode: busStop.id)) {
                            BusArrivalRow(arrival: arrival)
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
                        
                        Text("\(busStop.roadName) • \(busStop.id)")
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
    }
    
    private func loadData() async {
        isLoading = arrivals.isEmpty
        arrivals = await ltaService.fetchBusArrivals(for: busStop.id)
        lastUpdated = Date()
        isLoading = false
    }
}
