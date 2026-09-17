import SwiftUI
import CoreLocation

// MARK: - Bus Service View

struct BusServiceView: View {
    let serviceNo: String
    let originStopCode: String?
    var ltaService: LTAService
    
    @State private var selectedDirection: Int = 1
    @State private var route: BusServiceRoute? = nil
    @State private var isLoading: Bool = true
    
    private var currentStops: [BusRouteStop] {
        guard let route = route else { return [] }
        return selectedDirection == 1 ? route.direction1Stops : route.direction2Stops
    }
    
    private var currentDestination: String {
        guard let route = route else { return "Terminal" }
        return selectedDirection == 1 ? route.direction1Terminal : route.direction2Terminal
    }
    
    // Index of the origin stop if accessed from a specific stop
    private var originStopIndex: Int? {
        guard let origin = originStopCode else { return nil }
        return currentStops.firstIndex { $0.busStopCode == origin }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    // Big Service Badge (Not rounded)
                    Text(serviceNo)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.26, green: 0.65, blue: 0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("To \(currentDestination)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        if let op = route?.operatorName, !op.isEmpty {
                            Text("\(op)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        } else {
                            Text("LTA Live Bus Route")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    
                    Spacer()
                    
                    // Direction Flip Toggle Button (Textless icon arrow.up.arrow.down)
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selectedDirection = (selectedDirection == 1) ? 2 : 1
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 15, weight: .bold))
                            .padding(9)
                            .background(Color.white.opacity(0.22))
                            .foregroundStyle(.white)
                            .clipShape(Circle())
                    }
                }
                
                // Segmented Direction Control
                if let route = route, !route.direction2Stops.isEmpty {
                    Picker("Route Direction", selection: $selectedDirection) {
                        Text("To \(route.direction1Terminal)")
                            .tag(1)
                        Text("To \(route.direction2Terminal)")
                            .tag(2)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.black) // Green background
            
            // MARK: - Bus Stops List
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Fetching route for Bus \(serviceNo)...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else if currentStops.isEmpty {
                ContentUnavailableView("Route Unavailable", systemImage: "bus", description: Text("Could not retrieve bus stop sequence for service \(serviceNo)."))
            } else {
                ScrollViewReader { proxy in
                    List {
                        // MARK: - First & Last Bus Operating Hours
                        if let origin = currentStops.first {
                            Section("First & Last Bus Operating Hours") {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "clock.fill")
                                            .foregroundStyle(.blue)
                                            .font(.caption)
                                        Text("From \(origin.busStop?.name ?? "Terminal \(origin.busStopCode)")")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    HStack(spacing: 8) {
                                        // Weekdays
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("Weekdays")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.secondary)
                                            HStack(spacing: 4) {
                                                Text("1st:")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                Text(formatBusTime(origin.wdFirstBus))
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                            }
                                            HStack(spacing: 4) {
                                                Text("Last:")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                Text(formatBusTime(origin.wdLastBus))
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .foregroundStyle(.red)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(8)
                                        .background(Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        
                                        // Saturdays
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("Saturdays")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.secondary)
                                            HStack(spacing: 4) {
                                                Text("1st:")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                Text(formatBusTime(origin.satFirstBus))
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                            }
                                            HStack(spacing: 4) {
                                                Text("Last:")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                Text(formatBusTime(origin.satLastBus))
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .foregroundStyle(.red)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(8)
                                        .background(Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        
                                        // Sun / PH
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("Sun / PH")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.secondary)
                                            HStack(spacing: 4) {
                                                Text("1st:")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                Text(formatBusTime(origin.sunFirstBus))
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                            }
                                            HStack(spacing: 4) {
                                                Text("Last:")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                Text(formatBusTime(origin.sunLastBus))
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .foregroundStyle(.red)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(8)
                                        .background(Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        
                        Section {
                            ForEach(Array(currentStops.enumerated()), id: \.element.id) { index, stopItem in
                                let isOrigin = (originStopCode == stopItem.busStopCode)
                                let isHighlighted: Bool = {
                                    guard let originIdx = originStopIndex else {
                                        return true // If searched / no origin stop specified, highlight ALL stops
                                    }
                                    return index >= originIdx // Highlight current & subsequent stops
                                }()
                                
                                BusRouteStopRow(
                                    stopItem: stopItem,
                                    index: index,
                                    totalStops: currentStops.count,
                                    isOrigin: isOrigin,
                                    isHighlighted: isHighlighted
                                )
                                .id(stopItem.busStopCode)
                                .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                            }
                        } header: {
                            Text("\(currentStops.count) Bus Stops")
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .onAppear {
                        scrollToOrigin(proxy: proxy)
                    }
                    .onChange(of: selectedDirection) { _, _ in
                        scrollToOrigin(proxy: proxy)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Service \(serviceNo)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadRouteData()
        }
    }
    
    private func scrollToOrigin(proxy: ScrollViewProxy) {
        if let origin = originStopCode {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 40_000_000)
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(origin, anchor: .top)
                }
            }
        }
    }
    
    private func loadRouteData() async {
        isLoading = true
        let fetched = await ltaService.fetchBusRoute(for: serviceNo)
        
        if let origin = originStopCode, let route = fetched {
            let inDir1 = route.direction1Stops.contains { $0.busStopCode == origin }
            let inDir2 = route.direction2Stops.contains { $0.busStopCode == origin }
            
            if !inDir1 && inDir2 {
                selectedDirection = 2
            } else {
                selectedDirection = 1
            }
        }
        
        route = fetched
        isLoading = false
    }
    
    private func formatBusTime(_ raw: String?) -> String {
        guard let raw = raw, !raw.isEmpty else { return "05:30 AM" }
        if raw == "0" || raw == "-" { return "05:30 AM" }
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.count == 4, let val = Int(trimmed) {
            let h = val / 100
            let m = val % 100
            let isPM = h >= 12
            let displayH = h % 12 == 0 ? 12 : h % 12
            let ampm = isPM ? "PM" : "AM"
            return String(format: "%02d:%02d %@", displayH, m, ampm)
        }
        return raw
    }
}

// MARK: - Bus Route Stop Row Component

struct BusRouteStopRow: View {
    let stopItem: BusRouteStop
    let index: Int
    let totalStops: Int
    let isOrigin: Bool
    let isHighlighted: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Timeline connector & node indicator
            ZStack {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(index == 0 ? Color.clear : (isHighlighted ? Color.blue.opacity(0.8) : Color.gray.opacity(0.3)))
                        .frame(width: 3)
                    
                    Rectangle()
                        .fill(index == totalStops - 1 ? Color.clear : (isHighlighted ? Color.blue.opacity(0.8) : Color.gray.opacity(0.3)))
                        .frame(width: 3)
                }
                .frame(width: 24, height: 44)
                
                if isOrigin {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                } else if index == 0 || index == totalStops - 1 {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                } else {
                    Circle()
                        .fill(isHighlighted ? Color.blue : Color.gray.opacity(0.4))
                        .frame(width: 8, height: 8)
                }
            }
            .frame(width: 24)
            
            // Stop Name & Details
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(stopItem.busStop?.name ?? "\(stopItem.busStopCode)")
                        .font(.body)
                        .fontWeight(isOrigin ? .bold : (isHighlighted ? .semibold : .regular))
                        .foregroundStyle(isHighlighted ? .primary : .secondary)
                    
                    if isOrigin {
                        Text("YOUR STOP")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                
                HStack(spacing: 8) {
                    Text(stopItem.busStopCode)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let dist = stopItem.distance {
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        let distKmStr = dist < 1.0 ? String(format: "%.2f km", dist) : String(format: "%.1f km", dist)
                        Text(distKmStr)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Connecting Station Badge
            if let stn = stopItem.nearbyStation {
                StationCodeCapletView(station: stn)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
