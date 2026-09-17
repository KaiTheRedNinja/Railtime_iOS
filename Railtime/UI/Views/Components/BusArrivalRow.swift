import SwiftUI

// MARK: - Bus Arrival Row View

struct BusArrivalRow: View {
    let arrival: BusArrival
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                // Service Number & Destination
                VStack(alignment: .leading, spacing: 2) {
                    Text(arrival.serviceNo)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let dest = arrival.destinationName ?? arrival.destinationCode {
                        HStack(spacing: 3) {
                            Text("to")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(dest)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(minWidth: 100, alignment: .leading)
                
                Spacer()
                
                // Live Arrivals
                HStack(spacing: 12) {
                    if let next = arrival.nextBus {
                        TimingBadge(timing: next, isNext: true)
                    } else {
                        Text("No data")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let subsequent = arrival.subsequentBus {
                        TimingBadge(timing: subsequent, isNext: false)
                    }
                    
                    if let third = arrival.thirdBus {
                        TimingBadge(timing: third, isNext: false)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
