import SwiftUI

// MARK: - Timing Badge Component

struct TimingBadge: View {
    let timing: BusTimingInfo
    let isNext: Bool
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 4) {
                // Occupancy Dot
                Circle()
                    .fill(timing.load.color)
                    .frame(width: 8, height: 8)
                
                // Timing text
                if let mins = timing.minutesRemaining {
                    if mins == 0 {
                        Text("Arr")
                            .font(isNext ? .title3 : .subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    } else {
                        Text("\(mins)")
                            .font(isNext ? .title3 : .subheadline)
                            .fontWeight(.semibold)
                        Text("m")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("-")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Bus Features (Type & Wheelchair)
            HStack(spacing: 4) {
                if timing.busType == .doubleDeck {
                    Text("DD")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .cornerRadius(3)
                }
                
                if timing.isWheelchairAccessible {
                    Image(systemName: "figure.roll")
                        .font(.system(size: 9))
                        .foregroundStyle(.blue)
                }
            }
        }
    }
}
