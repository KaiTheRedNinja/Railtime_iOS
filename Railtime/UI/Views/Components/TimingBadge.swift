import SwiftUI
import LTAAPI
import BusEstimation

// MARK: - Timing Badge Component

struct TimingBadge: View {
    let timing: BusArrivalEstimate
    let now: Date

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 4) {
                // Occupancy Dot
                Circle()
                    .fill(timing.metadata.load?.color ?? .gray)
                    .frame(width: 8, height: 8)
                
                // Timing text
                let mins = Int((timing.eta.timeIntervalSince(now) / 60).rounded(.down))
                if mins == 0 {
                    Text("Arr")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                } else {
                    Text("\(mins)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("m")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Bus Features (Type & Wheelchair)
            HStack(spacing: 4) {
                if timing.metadata.busType == .doubleDeck {
                    Text("DD")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .cornerRadius(3)
                }

                // wheelchair accessible
                if timing.metadata.feature == "WAB" {
                    Image(systemName: "figure.roll")
                        .font(.system(size: 9))
                        .foregroundStyle(.blue)
                }
            }
        }
    }
}
