import SwiftUI
import CoreLocation
import LTAAPI
import BusEstimation

// MARK: - Bus Stop Home Row View (With Live Frequency Info)

struct BusStopHomeRow: View {
    let stop: BusStop
    var ltaService: LTAService
    var effectiveCenter: CLLocationCoordinate2D
    var onTapDistance: (() -> Void)?
    let now: Date

    @State private var sampleArrivals: [(serviceNo: String, eta: Date?, load: BusLoad?)] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                // Custom bus or bus_int asset icon to the left of the bus stop name
                Image(stop.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(stop.name)
                        .font(.headline)
                    Text([stop.roadName, stop.id].compactMap { $0 }.joined(separator: "•"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if let distanceStr = stop.formattedDistance(from: effectiveCenter) {
                    Button {
                        onTapDistance?()
                    } label: {
                        HStack(spacing: 3) {
                            Text(stop.direction(from: effectiveCenter))
                                .font(.caption)
                                .fontWeight(.semibold)
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text(distanceStr)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.12))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Live Bus Frequency & Upcoming Timings Bar
            if isLoading {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Fetching bus timings...")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else if !sampleArrivals.isEmpty {
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
        }
        .padding(.vertical, 2)
        .task(id: stop.id) {
            await loadArrivals()
        }
    }
    
    private func loadArrivals() async {
        isLoading = true

        func compareBusIDs(lhs: String, rhs: String) -> Bool {
            let lhsNo = Int(lhs.trimmingCharacters(in: .letters))
            let rhsNo = Int(rhs.trimmingCharacters(in: .letters))

            // if both have valid numbers and their numbers are not the same
            if let lhsNo, let rhsNo, lhsNo != rhsNo { return lhsNo < rhsNo }
            // if either have an invalid number or their numbers are the same (i.e. one is express
            // one is not), sort by string
            return lhs < rhs
        }

        let services = ltaService.dataSource.getServices(busStopCode: stop.busStopCode)?.sorted(by: compareBusIDs) ?? []
        self.sampleArrivals = services.map { ($0, nil, nil) }

        if let estimates = try? await ltaService.estimator.getSingleStop(code: stop.id, serviceNo: nil) {
            self.sampleArrivals = estimates.compactMap { $0.estimates.first }.sorted(by: { $0.eta < $1.eta }).map {
                ($0.busServiceNo, $0.eta, $0.metadata.load)
            }
            let servicesWithArrivals = Set(sampleArrivals.map { $0.serviceNo })
            for service in services where !servicesWithArrivals.contains(service) {
                sampleArrivals.append((service, nil, nil))
            }
        }
        isLoading = false
    }
}
