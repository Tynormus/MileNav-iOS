import SwiftUI
import AVFoundation

struct SettingsView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var nav: NavigationEngine
    @State private var previewSynth = AVSpeechSynthesizer()

    /// English voices installed on this device, alphabetical by name.
    private var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { $0.name < $1.name }
    }

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
                    Toggle(isOn: $preferences.voiceEnabled) {
                        Label("Voice Guidance", systemImage: "speaker.wave.2.fill")
                    }
                    if preferences.voiceEnabled {
                        Picker("Voice", selection: $preferences.voiceIdentifier) {
                            Text("System Default").tag("")
                            ForEach(availableVoices, id: \.identifier) { voice in
                                Text("\(voice.name) (\(voice.language))").tag(voice.identifier)
                            }
                        }
                        Button {
                            previewVoice()
                        } label: {
                            Label("Test Voice", systemImage: "play.circle")
                        }
                    }
                } header: {
                    Text("Voice")
                } footer: {
                    Text("Turn voice guidance off for silent navigation, or pick a different voice. Changes apply right away — including mid-drive. Extra voices can be downloaded in iOS Settings > Accessibility > Spoken Content > Voices.")
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
                    LabeledContent("Version", value: "1.3.0")
                }
            }
            .navigationTitle("Settings")
        }
    }

    /// Speaks a sample line with the currently selected voice — works even
    /// while you're just browsing voices, so you can hear before you commit.
    private func previewVoice() {
        previewSynth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: "In half a mile, turn right. Your trip miles are being counted as you drive.")
        if !preferences.voiceIdentifier.isEmpty,
           let chosen = AVSpeechSynthesisVoice(identifier: preferences.voiceIdentifier) {
            utterance.voice = chosen
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        previewSynth.speak(utterance)
    }
}
