import SwiftUI
import CoreLocation
import LTAAPI

// MARK: - Bus Stop Home Row View (With Live Frequency Info)

struct BusStopHomeRow: View {
    let stop: BusStop
    var ltaService: LTAService
    var effectiveCenter: CLLocationCoordinate2D
    var onTapDistance: (() -> Void)?
    
    @State private var arrivals: [BusArrival] = []
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
                    Text("\(stop.roadName) • \(stop.id)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if let distanceStr = stop.formattedDistance(from: effectiveCenter) {
                    Button {
                        onTapDistance?()
                    } label: {
                        HStack(spacing: 3) {
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
            } else if !arrivals.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(arrivals.prefix(6)) { arrival in
                            if let next = arrival.nextBus {
                                HStack(spacing: 4) {
                                    Text(arrival.serviceNo)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.primary)
                                    
                                    Circle()
                                        .fill(next.load.color)
                                        .frame(width: 6, height: 6)
                                    
                                    if let mins = next.minutesRemaining {
                                        Text(mins == 0 ? "Arr" : "\(mins)m")
                                            .fontWeight(.semibold)
                                            .foregroundStyle(mins == 0 ? .green : .secondary)
                                    } else {
                                        Text("-")
                                            .foregroundStyle(.secondary)
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
            }
        }
        .padding(.vertical, 2)
        .task(id: stop.id) {
            await loadArrivals()
        }
    }
    
    private func loadArrivals() async {
        isLoading = true
        arrivals = await ltaService.fetchBusArrivals(for: stop.id)
        isLoading = false
    }
}
