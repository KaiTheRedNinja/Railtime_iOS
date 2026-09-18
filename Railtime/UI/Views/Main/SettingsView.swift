import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("LTA_ACCOUNT_KEY") private var accountKey: String = ""
    @AppStorage("LTA_API_KEY") private var apiKey: String = ""
    @AppStorage("colorSchemeMode") private var colorSchemeMode: String = "system"
    @AppStorage("mrtStationRangeMeters") private var mrtRangeMeters: Int = 1000
    @AppStorage("mrtZoomThreshold") private var mrtZoomThreshold: Int = 1
    @AppStorage("busStopsZoomThreshold") private var busStopsZoomThreshold: Int = 40
    @AppStorage("exitsZoomThreshold") private var exitsZoomThreshold: Int = 60

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - LTA API Credentials
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LTA Account Key")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Enter Account Key", text: $accountKey)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LTA API Key")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Enter API Key", text: $apiKey)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                } header: {
                    Text("LTA DataMall Credentials")
                } footer: {
                    Text("Stored securely in AppStorage. Leave blank to use the default key.")
                }

                // MARK: - Display & Theme
                Section("Appearance") {
                    Picker("Theme", selection: $colorSchemeMode) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: - MRT Station Nearby Distance Filter
                Section {
                    Picker("MRT Range Filter", selection: $mrtRangeMeters) {
                        Text("250m").tag(250)
                        Text("500m").tag(500)
                        Text("1 km").tag(1000)
                        Text("2 km").tag(2000)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Nearby MRT Stations Range")
                } footer: {
                    Text("Shows MRT/LRT stations within this distance on the home list when search is empty.")
                }

                // MARK: - Map Zoom Visibility Thresholds
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("MRT Stations Threshold")
                            Spacer()
                            Text("\(mrtZoomThreshold)%")
                                .fontWeight(.bold)
                                .monospacedDigit()
                        }
                        Slider(value: Binding(get: { Double(mrtZoomThreshold) }, set: { mrtZoomThreshold = Int($0) }), in: 0...100, step: 1)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Bus Stops Threshold")
                            Spacer()
                            Text("\(busStopsZoomThreshold)%")
                                .fontWeight(.bold)
                                .monospacedDigit()
                        }
                        Slider(value: Binding(get: { Double(busStopsZoomThreshold) }, set: { busStopsZoomThreshold = Int($0) }), in: 0...100, step: 1)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Station Exits Threshold")
                            Spacer()
                            Text("\(exitsZoomThreshold)%")
                                .fontWeight(.bold)
                                .monospacedDigit()
                        }
                        Slider(value: Binding(get: { Double(exitsZoomThreshold) }, set: { exitsZoomThreshold = Int($0) }), in: 0...100, step: 1)
                    }
                } header: {
                    Text("Map Zoom Visibility Thresholds")
                } footer: {
                    Text("Controls the map zoom level percentage at which map pins become visible.")
                }

                // Reset to Defaults
                Section {
                    Button(role: .destructive) {
                        mrtZoomThreshold = 1
                        busStopsZoomThreshold = 40
                        exitsZoomThreshold = 60
                        mrtRangeMeters = 1000
                        colorSchemeMode = "system"
                    } label: {
                        HStack {
                            Spacer()
                            Text("Reset Settings to Defaults")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
