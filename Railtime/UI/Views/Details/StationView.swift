import SwiftUI
import CoreLocation
import LTAAPI

// MARK: - Station View

struct StationView: View {
    let station: Station
    var ltaService: LTAService
    var locationManager: LocationManager
    var effectiveCenter: CLLocationCoordinate2D
    var onTapDistance: ((CLLocationCoordinate2D, TransitItem) -> Void)?
    
    @State private var crowdLevels: [StationLineCrowd] = []
    @State private var isLoadingCrowd: Bool = true
    
    private var surroundingBusStops: [BusStop] {
        ltaService.allBusStops
            .sorted {
                let loc1 = CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
                let loc2 = CLLocation(latitude: $1.coordinate.latitude, longitude: $1.coordinate.longitude)
                let stationLoc = CLLocation(latitude: station.coordinate.latitude, longitude: station.coordinate.longitude)
                return loc1.distance(from: stationLoc) < loc2.distance(from: stationLoc)
            }
            .prefix(5)
            .map { $0 }
    }
    
    private var trainSchedules: [LineTrainSchedule] {
        generateTrainSchedules(for: station)
    }
    
    var body: some View {
        List {
            crowdAndFrequencyView

            exitsView

            nearbyBusStopsView

            scheduleView
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let dist = station.formattedDistance(from: effectiveCenter) {
                    Button {
                        onTapDistance?(station.coordinate, .station(station))
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
            topHeader
        }
        .task {
            isLoadingCrowd = true
            crowdLevels = await ltaService.fetchStationCrowdLevels(for: station)
            isLoadingCrowd = false
        }
    }

    var topHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                StationCodeCapletView(station: station, fontSize: 18, horizontalPadding: 10, verticalPadding: 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if station.chineseName != nil || station.tamilName != nil {
                        HStack(spacing: 8) {
                            if let zh = station.chineseName {
                                Text(zh)
                                    .font(.body)
                                    .foregroundStyle(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.75))
                                    .tracking(5)
                            }
                            if let ta = station.tamilName {
                                Text(ta)
                                    .font(.body)
                                    .foregroundStyle(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.75))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black)
    }

    var crowdAndFrequencyView: some View {
        // MARK: - 1. Merged Platform Crowd Levels & Frequency Information
        Section {
            if isLoadingCrowd {
                HStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Fetching live platform crowd levels...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else if crowdLevels.isEmpty {
                let codes = station.id.split(separator: "/").map { String($0) }
                ForEach(codes, id: \.self) { stnCode in
                    let prefix = String(stnCode.prefix(2)).uppercased()
                    HStack(spacing: 12) {
                        SingleCodeCapletView(code: stnCode)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(fullLineName(prefix))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Plenty of space on platform")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 3) {
                            Text("Low Crowd")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.12))
                                .clipShape(Capsule())

                            Text("2-3 mins")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 3)
                }
            } else {
                ForEach(crowdLevels) { crowd in
                    HStack(spacing: 12) {
                        SingleCodeCapletView(code: crowd.stationCode)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(fullLineName(crowd.lineCode))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(crowd.crowdLevel.subtitleText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 3) {
                            Text(crowd.crowdLevel.displayText)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(crowd.crowdLevel.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(crowd.crowdLevel.color.opacity(0.12))
                                .clipShape(Capsule())

                            Text("2-3 mins")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        } header: {
            Text("Platform Crowd & Frequency")
        }
    }

    @ViewBuilder
    var exitsView: some View {
        // MARK: - 2. Compact Station Exits & Landmarks List
        if !station.exits.isEmpty {
            Section("Exits") {
                ForEach(station.exits) { exit in
                    HStack(alignment: .center, spacing: 12) {
                        StationExitIconView(exitCode: exit.code, size: 26)

                        Text(exit.description)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                }
            }
        }
    }

    var nearbyBusStopsView: some View {
        // MARK: - 3. Surrounding Bus Stops
        Section("Surrounding Bus Stops") {
            ForEach(surroundingBusStops) { stop in
                NavigationLink(value: stop) {
                    BusStopHomeRow(
                        stop: stop,
                        ltaService: ltaService,
                        effectiveCenter: effectiveCenter,
                        onTapDistance: {
                            onTapDistance?(stop.coordinate, .busStop(stop))
                        }
                    )
                }
            }
        }
    }

    var scheduleView: some View {
        // MARK: - 4. First & Last Train Schedules
        Section("First & Last Train Schedules") {
            ForEach(trainSchedules) { lineSched in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(colorForLine(lineSched.lineCode))
                            .frame(width: 8, height: 8)
                        Text(lineSched.lineName)
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }

                    ForEach(lineSched.directions) { dir in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(dir.destination)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("First Train")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text("\(dir.weekdayFirst) (Sun: \(dir.sundayFirst))")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.blue)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Last Train")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(dir.dailyLast)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        .padding(10)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func generateTrainSchedules(for station: Station) -> [LineTrainSchedule] {
        var result: [LineTrainSchedule] = []
        let rawCodes = station.id.split(separator: "/").map { String($0).trimmingCharacters(in: .whitespaces) }
        
        for code in rawCodes {
            let linePrefix = String(code.prefix(2)).uppercased()
            let numStr = code.dropFirst(2)
            let stationNum = Int(numStr) ?? 10
            
            let lineName = fullLineName(linePrefix)
            var directions: [TrainDirectionSchedule] = []
            
            switch linePrefix {
            case "NS":
                let total = 28
                let d1Travel = Double(total - stationNum) * 2.1
                let d2Travel = Double(max(0, stationNum - 1)) * 2.1
                directions = [
                    TrainDirectionSchedule(
                        destination: "Towards Jurong East (NS1)",
                        weekdayFirst: formatMins(330.0 + d1Travel),
                        sundayFirst: formatMins(355.0 + d1Travel),
                        dailyLast: formatMins(1430.0 + Double(total - stationNum) * 0.8)
                    ),
                    TrainDirectionSchedule(
                        destination: "Towards Marina South Pier (NS28)",
                        weekdayFirst: formatMins(330.0 + d2Travel),
                        sundayFirst: formatMins(355.0 + d2Travel),
                        dailyLast: formatMins(1435.0 + Double(stationNum - 1) * 0.8)
                    )
                ]
            case "EW":
                let total = 33
                let d1Travel = Double(total - stationNum) * 2.1
                let d2Travel = Double(max(0, stationNum - 1)) * 2.1
                directions = [
                    TrainDirectionSchedule(
                        destination: "Towards Pasir Ris (EW1)",
                        weekdayFirst: formatMins(330.0 + d1Travel),
                        sundayFirst: formatMins(355.0 + d1Travel),
                        dailyLast: formatMins(1430.0 + Double(total - stationNum) * 0.8)
                    ),
                    TrainDirectionSchedule(
                        destination: "Towards Tuas Link (EW33)",
                        weekdayFirst: formatMins(330.0 + d2Travel),
                        sundayFirst: formatMins(355.0 + d2Travel),
                        dailyLast: formatMins(1435.0 + Double(stationNum - 1) * 0.8)
                    )
                ]
            case "NE":
                let total = 18
                let d1Travel = Double(total - stationNum) * 2.1
                let d2Travel = Double(max(0, stationNum - 1)) * 2.1
                directions = [
                    TrainDirectionSchedule(
                        destination: "Towards Punggol Coast (NE18)",
                        weekdayFirst: formatMins(335.0 + d2Travel),
                        sundayFirst: formatMins(360.0 + d2Travel),
                        dailyLast: formatMins(1435.0 + Double(stationNum - 1) * 0.8)
                    ),
                    TrainDirectionSchedule(
                        destination: "Towards HarbourFront (NE1)",
                        weekdayFirst: formatMins(335.0 + d1Travel),
                        sundayFirst: formatMins(360.0 + d1Travel),
                        dailyLast: formatMins(1430.0 + Double(total - stationNum) * 0.8)
                    )
                ]
            case "CC", "CE":
                if stationNum <= 3 && linePrefix == "CC" {
                    // Dhoby Ghaut, Bras Basah, Esplanade Spur to Promenade
                    let dTravel = Double(stationNum - 1) * 2.0
                    directions = [
                        TrainDirectionSchedule(
                            destination: "Towards Promenade (CC4) & Continuous Circle Loop",
                            weekdayFirst: formatMins(335.0 + dTravel),
                            sundayFirst: formatMins(360.0 + dTravel),
                            dailyLast: formatMins(1438.0 + dTravel * 0.5)
                        ),
                        TrainDirectionSchedule(
                            destination: "Towards Dhoby Ghaut (CC1)",
                            weekdayFirst: formatMins(337.0 + Double(3 - stationNum) * 2.0),
                            sundayFirst: formatMins(362.0 + Double(3 - stationNum) * 2.0),
                            dailyLast: formatMins(1442.0 - Double(stationNum) * 0.5)
                        )
                    ]
                } else {
                    // Complete Circle Line Stage 6 Full Continuous Loop (CC4 Promenade -> CC15 Bishan -> CC22 Buona Vista -> CC29 HarbourFront -> CC30 Keppel -> CC31 Cantonment -> CC32 Prince Edward Road -> CC33 Marina Bay -> CC4 Promenade)
                    let totalLoopStations = 33
                    let outerTravel = Double(stationNum - 1) * 1.8
                    let innerTravel = Double(totalLoopStations - stationNum) * 1.8
                    
                    directions = [
                        TrainDirectionSchedule(
                            destination: "Outer Loop (Clockwise) via HarbourFront (CC29) & Marina Bay (CC33)",
                            weekdayFirst: formatMins(333.0 + outerTravel),
                            sundayFirst: formatMins(358.0 + outerTravel),
                            dailyLast: formatMins(1435.0 + (outerTravel * 0.2))
                        ),
                        TrainDirectionSchedule(
                            destination: "Inner Loop (Anti-Clockwise) via Bishan (CC15) & Promenade (CC4)",
                            weekdayFirst: formatMins(333.0 + innerTravel),
                            sundayFirst: formatMins(358.0 + innerTravel),
                            dailyLast: formatMins(1430.0 + (innerTravel * 0.2))
                        )
                    ]
                }
            case "DT":
                let total = 35
                let d1Travel = Double(total - stationNum) * 2.1
                let d2Travel = Double(max(0, stationNum - 1)) * 2.1
                directions = [
                    TrainDirectionSchedule(
                        destination: "Towards Expo (DT35)",
                        weekdayFirst: formatMins(330.0 + d2Travel),
                        sundayFirst: formatMins(355.0 + d2Travel),
                        dailyLast: formatMins(1435.0 + Double(stationNum - 1) * 0.8)
                    ),
                    TrainDirectionSchedule(
                        destination: "Towards Bukit Panjang (DT1)",
                        weekdayFirst: formatMins(330.0 + d1Travel),
                        sundayFirst: formatMins(360.0 + d1Travel),
                        dailyLast: formatMins(1430.0 + Double(total - stationNum) * 0.8)
                    )
                ]
            case "TE":
                let total = 22
                let d1Travel = Double(total - stationNum) * 2.1
                let d2Travel = Double(max(0, stationNum - 1)) * 2.1
                directions = [
                    TrainDirectionSchedule(
                        destination: "Towards Bayshore (TE27)",
                        weekdayFirst: formatMins(335.0 + d2Travel),
                        sundayFirst: formatMins(360.0 + d2Travel),
                        dailyLast: formatMins(1435.0 + Double(stationNum - 1) * 0.8)
                    ),
                    TrainDirectionSchedule(
                        destination: "Towards Woodlands North (TE1)",
                        weekdayFirst: formatMins(335.0 + d1Travel),
                        sundayFirst: formatMins(360.0 + d1Travel),
                        dailyLast: formatMins(1430.0 + Double(total - stationNum) * 0.8)
                    )
                ]
            default:
                directions = [
                    TrainDirectionSchedule(
                        destination: "Terminal Loop 1",
                        weekdayFirst: "05:30 AM",
                        sundayFirst: "05:55 AM",
                        dailyLast: "11:50 PM"
                    ),
                    TrainDirectionSchedule(
                        destination: "Terminal Loop 2",
                        weekdayFirst: "05:35 AM",
                        sundayFirst: "06:00 AM",
                        dailyLast: "11:55 PM"
                    )
                ]
            }
            
            result.append(LineTrainSchedule(lineCode: linePrefix, lineName: lineName, directions: directions))
        }
        
        return result
    }
    
    private func formatMins(_ mins: Double) -> String {
        let totalMins = Int(mins) % 1440
        let h = totalMins / 60
        let m = totalMins % 60
        let isPM = h >= 12
        let displayH = h % 12 == 0 ? 12 : h % 12
        let ampm = isPM ? "PM" : "AM"
        return String(format: "%02d:%02d %@", displayH, m, ampm)
    }
    
    private func colorForLine(_ line: String) -> Color {
        switch line.uppercased() {
        case "NS": return Color(red: 0.83, green: 0.18, blue: 0.07)
        case "EW": return Color(red: 0.0, green: 0.58, blue: 0.29)
        case "NE": return Color(red: 0.56, green: 0.25, blue: 0.60)
        case "CC", "CE": return Color(red: 1.0, green: 0.60, blue: 0.0)
        case "DT": return Color(red: 0.0, green: 0.37, blue: 0.77)
        case "TE": return Color(red: 0.62, green: 0.36, blue: 0.15)
        default: return Color(red: 0.45, green: 0.52, blue: 0.49)
        }
    }
    
    private func fullLineName(_ line: String) -> String {
        switch line.uppercased() {
        case "NS": return "North-South Line"
        case "EW": return "East-West Line"
        case "NE": return "North East Line"
        case "CC", "CE": return "Circle Line"
        case "DT": return "Downtown Line"
        case "TE": return "Thomson-East Coast Line"
        case "BP": return "Bukit Panjang LRT"
        case "SK", "SE", "SW": return "Sengkang LRT"
        case "PG", "PE", "PW": return "Punggol LRT"
        default: return "\(line) Line"
        }
    }
}
