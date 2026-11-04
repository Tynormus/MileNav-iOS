import Foundation
import MapKit
import CoreLocation
import AVFoundation

/// Route planning + turn-by-turn guidance.
///
/// Planning uses MKDirections from the current location to the chosen
/// destination. During a drive it advances through the route's steps as the
/// car reaches each maneuver point, speaks instructions with AVSpeech,
/// re-routes when the car leaves the route polyline, detects arrival, and
/// hands the finished drive to the Work / Personal picker as a `TripDraft`.
final class NavigationEngine: ObservableObject {
    // Planning
    @Published var destination: MKMapItem?
    @Published var route: MKRoute?
    @Published var routeError: String?

    // Active navigation
    @Published var isNavigating = false
    @Published var isPresentingNavigation = false
    @Published var currentStepIndex = 0
    @Published var distanceToNextManeuver: CLLocationDistance = 0
    @Published var distanceRemaining: CLLocationDistance = 0
    @Published var timeRemaining: TimeInterval = 0

    /// Set the moment a drive ends — ContentView presents the classifier.
    @Published var pendingClassification: TripDraft?

    private let locationManager: LocationManager
    private let preferences: AppPreferences
    private let speech = AVSpeechSynthesizer()
    private let geocoder = CLGeocoder()

    private var directions: MKDirections?
    private var tripStartDate: Date?
    private var tripStartCoordinate: CLLocationCoordinate2D?
    private var tripStartAddress = "Current location"
    private var offRouteCount = 0
    private var lastRerouteAt: Date?
    private var announcedEarlyForStep = -1
    private var announcedNearForStep = -1
    private var resetGuidanceOnNextRoute = false

    init(locationManager: LocationManager, preferences: AppPreferences) {
        self.locationManager = locationManager
        self.preferences = preferences
        locationManager.onLocationUpdate = { [weak self] location in
            DispatchQueue.main.async {
                self?.handleLocation(location)
            }
        }
    }

    // MARK: - Derived guidance values

    var currentStep: MKRoute.Step? {
        guard let route = route, route.steps.indices.contains(currentStepIndex) else { return nil }
        return route.steps[currentStepIndex]
    }

    var nextStep: MKRoute.Step? {
        guard let route = route, route.steps.indices.contains(currentStepIndex + 1) else { return nil }
        return route.steps[currentStepIndex + 1]
    }

    /// The instruction to show/say now: the upcoming maneuver is described by
    /// the NEXT step (step i+1's text says what to do at the end of step i).
    var currentInstruction: String {
        if let next = nextStep, !next.instructions.isEmpty {
            return next.instructions
        }
        return currentStep?.instructions ?? ""
    }

    var destinationCoordinate: CLLocationCoordinate2D? {
        destination?.placemark.coordinate
    }

    var destinationName: String {
        guard let destination = destination else { return "Destination" }
        return mapItemTitle(destination)
    }

    var destinationAddress: String {
        guard let destination = destination else { return "" }
        return formattedAddress(destination.placemark)
    }

    var arrivalTime: Date {
        Date().addingTimeInterval(timeRemaining)
    }

    // MARK: - Planning

    func setDestination(_ item: MKMapItem) {
        destination = item
        route = nil
        routeError = nil
        calculateRoute()
    }

    func clearDestination() {
        destination = nil
        route = nil
        routeError = nil
    }

    func calculateRoute() {
        guard let destination = destination else { return }
        guard let from = locationManager.currentLocation else {
            routeError = "Waiting for your location…"
            return
        }
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from.coordinate))
        request.destination = destination
        request.transportType = .automobile
        // Personalization (Settings tab): honored for new routes AND for
        // automatic re-routes, since every calculation goes through here.
        request.tollPreference = preferences.avoidTolls ? .avoid : .any
        request.highwayPreference = preferences.avoidHighways ? .avoid : .any
        directions?.cancel()
        let calc = MKDirections(request: request)
        directions = calc
        calc.calculate { [weak self] response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let newRoute = response?.routes.first {
                    self.route = newRoute
                    self.routeError = nil
                    if self.resetGuidanceOnNextRoute {
                        self.resetGuidanceOnNextRoute = false
                        self.currentStepIndex = 0
                        self.announcedEarlyForStep = -1
                        self.announcedNearForStep = -1
                        self.offRouteCount = 0
                        self.distanceRemaining = newRoute.distance
                        self.timeRemaining = newRoute.expectedTravelTime
                    } else if !self.isNavigating {
                        self.distanceRemaining = newRoute.distance
                        self.timeRemaining = newRoute.expectedTravelTime
                    }
                } else {
                    self.route = nil
                    self.routeError = error?.localizedDescription
                        ?? "Could not find a driving route there."
                }
            }
        }
    }

    // MARK: - Start / end a drive

    func startNavigation() {
        guard let route = route,
              destination != nil,
              let from = locationManager.currentLocation else { return }
        tripStartDate = Date()
        tripStartCoordinate = from.coordinate
        tripStartAddress = "Current location"
        geocoder.reverseGeocodeLocation(from) { [weak self] placemarks, _ in
            if let placemark = placemarks?.first {
                DispatchQueue.main.async {
                    self?.tripStartAddress = formattedAddress(placemark)
                }
            }
        }
        currentStepIndex = 0
        offRouteCount = 0
        announcedEarlyForStep = -1
        announcedNearForStep = -1
        distanceRemaining = route.distance
        timeRemaining = route.expectedTravelTime
        distanceToNextManeuver = maneuverDistance(from: from)
        locationManager.startTracking()
        isNavigating = true
        isPresentingNavigation = true
        activateAudioSession()
        speak("Starting navigation to \(destinationName).")
        if !currentInstruction.isEmpty {
            speak(currentInstruction)
        }
    }

    /// Ends the drive early (button in the navigation screen). The miles
    /// driven so far are still logged.
    func endTripEarly() {
        guard isNavigating else { return }
        finishTrip()
    }

    private func finishTrip() {
        guard let start = tripStartDate,
              let startCoord = tripStartCoordinate,
              let destCoord = destinationCoordinate else {
            isNavigating = false
            isPresentingNavigation = false
            locationManager.stopTracking()
            return
        }
        let draft = TripDraft(
            startDate: start,
            endDate: Date(),
            startAddress: tripStartAddress,
            endAddress: destinationAddress,
            destinationName: destinationName,
            startCoordinate: startCoord,
            endCoordinate: destCoord,
            trackedDistanceMeters: locationManager.trackedDistanceMeters,
            routeDistanceMeters: route?.distance ?? 0)
        speech.stopSpeaking(at: .immediate)
        deactivateAudioSession()
        locationManager.stopTracking()
        isNavigating = false
        isPresentingNavigation = false
        route = nil
        destination = nil
        pendingClassification = draft
    }

    // MARK: - Guidance loop

    private func handleLocation(_ location: CLLocation) {
        guard isNavigating, let activeRoute = route else { return }

        // Arrival: within ~55 m of the destination, the drive is done.
        if let destCoord = destinationCoordinate {
            let toDestination = location.distance(
                from: CLLocation(latitude: destCoord.latitude, longitude: destCoord.longitude))
            if toDestination < 55 {
                speak("You have arrived at your destination.")
                finishTrip()
                return
            }
        }

        // Step advancement + voice announcements.
        let toManeuver = maneuverDistance(from: location)
        distanceToNextManeuver = toManeuver
        if let next = nextStep {
            let upcomingIndex = currentStepIndex + 1
            if toManeuver < 650, announcedEarlyForStep != upcomingIndex, !next.instructions.isEmpty {
                announcedEarlyForStep = upcomingIndex
                speak("In \(Formatters.maneuverDistance(toManeuver)), \(sentenceFragment(next.instructions))")
            } else if toManeuver < 200, announcedNearForStep != upcomingIndex, !next.instructions.isEmpty {
                announcedNearForStep = upcomingIndex
                speak(next.instructions)
            }
            if toManeuver < 30, currentStepIndex + 1 < activeRoute.steps.count {
                currentStepIndex += 1
            }
        }

        // Remaining distance = to the next maneuver + every step after it.
        var remaining = toManeuver
        var idx = currentStepIndex + 1
        while idx < activeRoute.steps.count {
            remaining += activeRoute.steps[idx].distance
            idx += 1
        }
        distanceRemaining = remaining
        if activeRoute.distance > 0 {
            timeRemaining = activeRoute.expectedTravelTime * (remaining / activeRoute.distance)
        }

        // Off-route: three consecutive fixes > 60 m from the route polyline
        // trigger a re-route (throttled to one per 15 seconds).
        if distanceToPolyline(location, polyline: activeRoute.polyline) > 60 {
            offRouteCount += 1
            let throttled = lastRerouteAt.map { Date().timeIntervalSince($0) < 15 } ?? false
            if offRouteCount >= 3, !throttled {
                lastRerouteAt = Date()
                offRouteCount = 0
                resetGuidanceOnNextRoute = true
                speak("Rerouting.")
                calculateRoute()
            }
        } else {
            offRouteCount = 0
        }
    }

    /// Straight-line distance to the start of the next step's segment —
    /// that point is the maneuver. On the last step it is the destination.
    private func maneuverDistance(from location: CLLocation) -> CLLocationDistance {
        if let next = nextStep {
            let point = next.polyline.points()[0]
            let c = point.coordinate
            return location.distance(from: CLLocation(latitude: c.latitude, longitude: c.longitude))
        }
        if let destCoord = destinationCoordinate {
            return location.distance(
                from: CLLocation(latitude: destCoord.latitude, longitude: destCoord.longitude))
        }
        return 0
    }

    // MARK: - Speech

    private func speak(_ text: String) {
        guard !text.isEmpty else { return }
        // Settings > Voice Guidance: off means silent navigation.
        guard preferences.voiceEnabled else { return }
        let utterance = AVSpeechUtterance(string: text)
        // Settings > Voice: a chosen voice, or the system default when unset.
        if !preferences.voiceIdentifier.isEmpty,
           let chosen = AVSpeechSynthesisVoice(identifier: preferences.voiceIdentifier) {
            utterance.voice = chosen
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speech.speak(utterance)
    }

    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        // .voicePrompt + .duckOthers: directions briefly lower the music
        // instead of talking over it. .allowBluetooth lets the prompts ride
        // the car's hands-free (HFP) channel like a call prompt, so they are
        // heard through the car speakers even in cars that don't stream app
        // audio — this is also the channel CarPlay audio uses. No CarPlay
        // entitlement is needed for audio; only the on-screen CarPlay UI is
        // entitlement-gated (see CarPlaySceneDelegate).
        try? session.setCategory(.playback, mode: .voicePrompt,
                                 options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers, .allowBluetooth])
        try? session.setActive(true)
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
