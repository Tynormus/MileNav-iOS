import Foundation
import MapKit
import SwiftUI // for MapStyle (declared in MapKit's SwiftUI overlay)

/// How the map looks. Applied to every map in the app (route preview,
/// active navigation, trip detail).
enum MapStyleOption: String, CaseIterable, Identifiable {
    case standard = "Standard"
    case satellite = "Satellite"
    case hybrid = "Hybrid"

    var id: String { rawValue }

    var mapStyle: MapStyle {
        switch self {
        case .standard: return .standard(elevation: .realistic)
        case .satellite: return .imagery(elevation: .realistic)
        case .hybrid: return .hybrid(elevation: .realistic)
        }
    }

    var description: String {
        switch self {
        case .standard: return "Road map"
        case .satellite: return "Satellite imagery"
        case .hybrid: return "Satellite with road labels"
        }
    }
}

/// User personalization, persisted in UserDefaults:
/// routing preferences (avoid tolls / avoid highways) and the map style.
final class AppPreferences: ObservableObject {
    @Published var avoidTolls: Bool {
        didSet { UserDefaults.standard.set(avoidTolls, forKey: Keys.avoidTolls) }
    }
    @Published var avoidHighways: Bool {
        didSet { UserDefaults.standard.set(avoidHighways, forKey: Keys.avoidHighways) }
    }
    @Published var mapStyleOption: MapStyleOption {
        didSet { UserDefaults.standard.set(mapStyleOption.rawValue, forKey: Keys.mapStyle) }
    }
    /// Spoken guidance on/off. Defaults to ON.
    @Published var voiceEnabled: Bool {
        didSet { UserDefaults.standard.set(voiceEnabled, forKey: Keys.voiceEnabled) }
    }
    /// AVSpeechSynthesisVoice identifier; empty = system default voice.
    @Published var voiceIdentifier: String {
        didSet { UserDefaults.standard.set(voiceIdentifier, forKey: Keys.voiceIdentifier) }
    }

    private enum Keys {
        static let avoidTolls = "pref.avoidTolls"
        static let avoidHighways = "pref.avoidHighways"
        static let mapStyle = "pref.mapStyle"
        static let voiceEnabled = "pref.voiceEnabled"
        static let voiceIdentifier = "pref.voiceIdentifier"
    }

    init() {
        avoidTolls = UserDefaults.standard.bool(forKey: Keys.avoidTolls)
        avoidHighways = UserDefaults.standard.bool(forKey: Keys.avoidHighways)
        mapStyleOption = MapStyleOption(
            rawValue: UserDefaults.standard.string(forKey: Keys.mapStyle) ?? "") ?? .standard
        // Voice guidance defaults to ON — only an explicit stored value turns it off.
        voiceEnabled = UserDefaults.standard.object(forKey: Keys.voiceEnabled) as? Bool ?? true
        voiceIdentifier = UserDefaults.standard.string(forKey: Keys.voiceIdentifier) ?? ""
    }
}
