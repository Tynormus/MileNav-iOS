import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var nav: NavigationEngine

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $preferences.avoidTolls) {
                        Label("Avoid Tolls", systemImage: "dollarsign.circle")
                    }
                    Toggle(isOn: $preferences.avoidHighways) {
                        Label("Avoid Highways", systemImage: "road.lanes")
                    }
                } header: {
                    Text("Routing")
                } footer: {
                    Text("Applies to new routes and to automatic re-routes while you're driving. If no route exists without them, the best available route is used and toll roads are flagged on the preview.")
                }

                Section {
                    Picker("Map Style", selection: $preferences.mapStyleOption) {
                        ForEach(MapStyleOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(preferences.mapStyleOption.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Map")
                } footer: {
                    Text("Used on the route preview, during navigation, and on trip maps.")
                }

                Section {
                    LabeledContent("Miles counted", value: "GPS, as driven")
                } header: {
                    Text("Mileage")
                } footer: {
                    Text("Logged miles are the miles your car actually travels, measured by GPS — wrong turns and detours included. The pre-calculated route distance is never counted.")
                }

                Section("About") {
                    LabeledContent("App", value: "MileNav")
                    LabeledContent("Version", value: "1.2.0")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
