import UIKit
import CarPlay
import MapKit
import Combine

/// CarPlay front-end: a map template on the car display that mirrors the
/// phone's active navigation (same engine, same trip).
///
/// IMPORTANT — why this is dormant in sideloaded builds: iOS only connects
/// a CarPlay scene when the app holds Apple's CarPlay navigation
/// entitlement (`com.apple.developer.carplay-navigation`). Apple grants
/// that entitlement per app, after review, to App Store–distributed apps;
/// a build signed with a personal Apple ID (Sideloadly/AltStore) does not
/// carry it, so this scene simply never activates and the phone UI is
/// unaffected. The implementation is complete so the app is CarPlay-ready
/// if the entitlement is ever granted (paid developer account + Apple's
/// CarPlay approval). In the car today, guidance is heard through the car
/// speakers via the phone's audio session (see NavigationEngine).
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var mapTemplate: CPMapTemplate?
    private var navigationSession: CPNavigationSession?
    private var cancellables = Set<AnyCancellable>()
    private var lastStepIndex = -1

    private var engine: NavigationEngine { AppServices.shared.navEngine }
    private var locationManager: LocationManager { AppServices.shared.locationManager }

    // MARK: - Scene connection

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        let mapTemplate = CPMapTemplate()
        self.mapTemplate = mapTemplate
        interfaceController.setRootTemplate(mapTemplate, animated: true) { _, _ in }
        observeEngine()
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        cancellables.removeAll()
        navigationSession = nil
        mapTemplate = nil
        self.interfaceController = nil
        lastStepIndex = -1
    }

    // MARK: - Mirroring the phone's navigation

    private func observeEngine() {
        engine.$isNavigating
            .receive(on: DispatchQueue.main)
            .sink { [weak self] navigating in
                guard let self = self else { return }
                if navigating {
                    self.startMirroringIfPossible()
                } else {
                    self.stopMirroring()
                }
            }
            .store(in: &cancellables)

        engine.$currentStepIndex
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateManeuver()
            }
            .store(in: &cancellables)

        engine.$distanceToNextManeuver
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateEstimates()
            }
            .store(in: &cancellables)

        if engine.isNavigating {
            startMirroringIfPossible()
        }
    }

    private func startMirroringIfPossible() {
        guard navigationSession == nil,
              let mapTemplate = mapTemplate,
              let destination = engine.destination,
              let from = locationManager.currentLocation else { return }
        let origin = MKMapItem(placemark: MKPlacemark(coordinate: from.coordinate))
        let routeChoice = CPRouteChoice(
            summaryText: "Route from MileNav",
            variants: ["Route from MileNav"],
            selectionSummary: "Navigation started on iPhone")
        let trip = CPTrip(origin: origin, destination: destination, routeChoices: [routeChoice])
        navigationSession = mapTemplate.startNavigationSession(for: trip)
        lastStepIndex = -1
        updateManeuver()
    }

    private func stopMirroring() {
        navigationSession?.cancelTrip()
        navigationSession = nil
        lastStepIndex = -1
    }

    private func makeManeuver() -> CPManeuver? {
        let text = engine.currentInstruction
        guard !text.isEmpty else { return nil }
        let maneuver = CPManeuver()
        maneuver.instructionVariants = [text]
        maneuver.initialTravelEstimates = CPTravelEstimates(
            distanceRemaining: Measurement(value: max(engine.distanceToNextManeuver, 0),
                                           unit: UnitLength.meters),
            timeRemaining: engine.timeRemaining)
        return maneuver
    }

    private func updateManeuver() {
        guard let session = navigationSession else { return }
        guard engine.currentStepIndex != lastStepIndex else { return }
        lastStepIndex = engine.currentStepIndex
        if let maneuver = makeManeuver() {
            session.upcomingManeuvers = [maneuver]
        }
    }

    private func updateEstimates() {
        guard let session = navigationSession,
              let maneuver = session.upcomingManeuvers.first else { return }
        let estimates = CPTravelEstimates(
            distanceRemaining: Measurement(value: max(engine.distanceToNextManeuver, 0),
                                           unit: UnitLength.meters),
            timeRemaining: engine.timeRemaining)
        session.updateEstimates(estimates, for: maneuver)
    }
}
