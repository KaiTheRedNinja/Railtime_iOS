import SwiftUI

// MARK: - Station Code Caplet View (Interchange Capsule Badge)

struct StationCodeCapletView: View {
    let station: Station
    var fontSize: CGFloat = 14
    var horizontalPadding: CGFloat = 7
    var verticalPadding: CGFloat = 3.5
    
    // Splits multi-station IDs such as "NS9/TE2" into ["NS9", "TE2"]
    private var stationCodes: [String] {
        station.id.split(separator: "/").map { String($0) }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(stationCodes.enumerated()), id: \.offset) { index, code in
                Text(code)
                    .font(.system(size: fontSize, weight: .bold))
                    .lineLimit(1)
                    .layoutPriority(1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, verticalPadding)
                    .background(colorForCode(code))
            }
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Single Station Code Caplet View (Large individual caplet)

struct SingleCodeCapletView: View {
    let code: String
    var fontSize: CGFloat = 14
    var horizontalPadding: CGFloat = 10
    var verticalPadding: CGFloat = 5
    
    var body: some View {
        Text(code)
            .font(.system(size: fontSize, weight: .bold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(.white)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(colorForCode(code))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Station Exit Icon View (Custom exit.svg with Exit Letter/Number)

struct StationExitIconView: View {
    let exitCode: String
    var size: CGFloat = 26
    
    private var exitText: String {
        let trimmed = exitCode.replacingOccurrences(of: "Exit", with: "", options: .caseInsensitive)
                              .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? exitCode : trimmed
    }
    
    var body: some View {
        ZStack {
            Image("exit")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
            
            Text(exitText)
                .font(.system(size: size * 0.46, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
        }
        .frame(width: size, height: size)
    }
}

func colorForCode(_ code: String) -> Color {
    let prefix = code.prefix(while: { $0.isLetter }).uppercased()
    switch prefix {
    case "NS": return Color(red: 0.83, green: 0.18, blue: 0.07)
    case "EW": return Color(red: 0.0, green: 0.58, blue: 0.29)
    case "NE": return Color(red: 0.56, green: 0.25, blue: 0.60)
    case "CC", "CE": return Color(red: 1.0, green: 0.60, blue: 0.0)
    case "DT": return Color(red: 0.0, green: 0.37, blue: 0.77)
    case "TE": return Color(red: 0.62, green: 0.36, blue: 0.15)
    default: return Color(red: 0.45, green: 0.52, blue: 0.49)
    }
}

#Preview {
    VStack(spacing: 12) {
        StationCodeCapletView(station: Station(id: "NS22", name: "Orchard", coordinate: .init(), lines: ["NS"]))
        StationCodeCapletView(station: Station(id: "NS22/TE14", name: "Orchard Interchange", coordinate: .init(), lines: ["NS", "TE"]))
        StationCodeCapletView(station: Station(id: "NS24/NE6/CC1", name: "Dhoby Ghaut Interchange", coordinate: .init(), lines: ["NS", "NE", "CC"]))
        
        HStack(spacing: 8) {
            SingleCodeCapletView(code: "NS1")
            SingleCodeCapletView(code: "EW24")
            StationExitIconView(exitCode: "Exit A")
            StationExitIconView(exitCode: "Exit 1")
        }
    }
}
