import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    let wiFiManager = TripperWiFiManager()
    let locationService = LocationService()
    let navigationEngine = NavigationEngine()
    let dashSession = DashSessionCoordinator()

    @Published var dashSSID = ""
    @Published var dashPassphrase = ""
    @Published var destinationQuery = ""

    private var cancellables: Set<AnyCancellable> = []

    init() {
        locationService.$location
            .compactMap { $0 }
            .sink { [weak self] location in
                guard let self else { return }
                self.navigationEngine.update(location: location)
                self.dashSession.updateNavigation(self.navigationEngine.projectionState)
            }
            .store(in: &cancellables)

        navigationEngine.$projectionState
            .sink { [weak self] state in
                self?.dashSession.updateNavigation(state)
            }
            .store(in: &cancellables)
    }

    func connectDash() async {
        guard !dashSSID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            try await wiFiManager.join(ssid: dashSSID, passphrase: dashPassphrase)
            dashPassphrase = ""
            await dashSession.connect(ssid: dashSSID)
        } catch {
            dashPassphrase = ""
        }
    }

    func startProjection() async {
        await dashSession.startProjection { [weak self] in
            self?.navigationEngine.projectionState ?? .preview
        }
    }

    func stopProjection() async {
        await dashSession.stopProjection()
    }

    func planRoute() async {
        guard let origin = locationService.location,
              !destinationQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            try await navigationEngine.plan(destinationQuery: destinationQuery, from: origin)
        } catch {
            // NavigationEngine exposes its own state; UI can surface failure after manual validation.
        }
    }
}
