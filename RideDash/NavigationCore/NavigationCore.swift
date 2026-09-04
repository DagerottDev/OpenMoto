import Combine
import CoreLocation
import Foundation
import MapKit

@MainActor
final class NavigationLocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var location: CLLocation?
    @Published private(set) var heading: CLHeading?
    @Published private(set) var errorMessage: String?

    private let manager = CLLocationManager()

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 3
        manager.headingFilter = 2
        manager.activityType = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = false
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        if manager.authorizationStatus == .notDetermined { requestPermission() }
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() { manager.startUpdatingHeading() }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    func setBackgroundNavigationEnabled(_ enabled: Bool) {
        manager.allowsBackgroundLocationUpdates = enabled
        manager.showsBackgroundLocationIndicator = enabled
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newest = locations.last else { return }
        location = newest
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }
}

struct ResolvedDestination: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: ResolvedDestination, rhs: ResolvedDestination) -> Bool {
        lhs.name == rhs.name &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
    }
}

enum RouteResolver {
    static func resolve(_ input: String, near location: CLLocation?) async throws -> ResolvedDestination {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw NavigationError.emptyDestination }

        if let coordinate = coordinate(from: trimmed) {
            return .init(name: trimmed, coordinate: coordinate)
        }

        if let url = URL(string: trimmed), url.scheme != nil {
            if let coordinate = coordinate(from: url.absoluteString) {
                return .init(name: url.host ?? "Shared destination", coordinate: coordinate)
            }
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let keys = Set(["q", "query", "destination", "daddr", "ll"])
            if let value = components?.queryItems?.first(where: { keys.contains($0.name.lowercased()) })?.value,
               !value.isEmpty {
                if let coordinate = coordinate(from: value) {
                    return .init(name: value, coordinate: coordinate)
                }
                return try await localSearch(value, near: location)
            }
        }

        return try await localSearch(trimmed, near: location)
    }

    private static func localSearch(_ query: String, near location: CLLocation?) async throws -> ResolvedDestination {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let location {
            request.region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 100_000,
                longitudinalMeters: 100_000
            )
        }
        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first else { throw NavigationError.destinationNotFound }
        return .init(name: item.name ?? query, coordinate: item.placemark.coordinate)
    }

    private static func coordinate(from text: String) -> CLLocationCoordinate2D? {
        let pattern = #"(-?\d{1,2}(?:\.\d+)?)\s*[, ]\s*(-?\d{1,3}(?:\.\d+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let latRange = Range(match.range(at: 1), in: text),
              let lonRange = Range(match.range(at: 2), in: text),
              let latitude = Double(text[latRange]),
              let longitude = Double(text[lonRange]),
              (-90...90).contains(latitude),
              (-180...180).contains(longitude) else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

@MainActor
final class NavigationViewModel: ObservableObject {
    @Published var destinationInput = ""
    @Published private(set) var destination: ResolvedDestination?
    @Published private(set) var route: MKRoute?
    @Published private(set) var activeStepIndex = 0
    @Published private(set) var isCalculating = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var projectionState = ProjectionUIState()

    let locationService: NavigationLocationService
    private var cancellables: Set<AnyCancellable> = []

    init(locationService: NavigationLocationService = NavigationLocationService()) {
        self.locationService = locationService
        locationService.$location
            .sink { [weak self] location in self?.handleLocation(location) }
            .store(in: &cancellables)
    }

    func startLocation() { locationService.start() }
    func stopLocation() { locationService.stop() }

    func calculateRoute() async {
        isCalculating = true
        errorMessage = nil
        defer { isCalculating = false }

        do {
            let resolved = try await RouteResolver.resolve(destinationInput, near: locationService.location)
            destination = resolved
            guard let originLocation = locationService.location else {
                throw NavigationError.locationUnavailable
            }

            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: originLocation.coordinate))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: resolved.coordinate))
            request.transportType = .automobile
            request.requestsAlternateRoutes = false

            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else { throw NavigationError.routeNotFound }
            self.route = route
            activeStepIndex = firstUsableStep(in: route)
            rebuildProjectionState(location: originLocation)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearRoute() {
        route = nil
        destination = nil
        activeStepIndex = 0
        projectionState = ProjectionUIState()
    }

    func openInAppleMaps() {
        guard let destination else { return }
        let item = MKMapItem(placemark: MKPlacemark(coordinate: destination.coordinate))
        item.name = destination.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    func importURL(_ url: URL) {
        if url.scheme?.lowercased() == "ridedash" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let value = components?.queryItems?.first(where: {
                ["url", "q", "destination"].contains($0.name.lowercased())
            })?.value {
                destinationInput = value
            }
        } else {
            destinationInput = url.absoluteString
        }
    }

    func handleDashButton(_ button: DashButton) {
        guard let route, !route.steps.isEmpty else { return }
        let lastIndex = route.steps.count - 1
        switch button {
        case .left:
            activeStepIndex = max(firstUsableStep(in: route), activeStepIndex - 1)
        case .right:
            activeStepIndex = min(lastIndex, activeStepIndex + 1)
        case .down, .click:
            if let location = locationService.location {
                activeStepIndex = nearestUpcomingStep(in: route, to: location)
            }
        }
        rebuildProjectionState(location: locationService.location)
    }

    private func handleLocation(_ location: CLLocation?) {
        guard let location else { return }
        if let route, !route.steps.isEmpty {
            let suggested = nearestUpcomingStep(in: route, to: location)
            if suggested >= activeStepIndex { activeStepIndex = suggested }
        }
        rebuildProjectionState(location: location)
    }

    private func rebuildProjectionState(location: CLLocation?) {
        guard let route, let destination else {
            projectionState = ProjectionUIState(
                destination: destination?.name ?? "RideDash",
                speedKph: max(0, (location?.speed ?? 0) * 3.6),
                gpsAccuracy: location?.horizontalAccuracy
            )
            return
        }

        let step: MKRoute.Step? = route.steps.isEmpty
            ? nil
            : route.steps[min(max(0, activeStepIndex), route.steps.count - 1)]
        let instruction = (step?.instructions.isEmpty == false) ? (step?.instructions ?? "Continue") : "Continue"
        let distance = step.map { Self.formatDistance($0.distance) } ?? "--"
        let etaDate = Date().addingTimeInterval(route.expectedTravelTime)
        let etaFormatter = DateFormatter()
        etaFormatter.dateFormat = "HH:mm"

        projectionState = ProjectionUIState(
            destination: destination.name,
            maneuver: instruction,
            distanceToManeuver: distance,
            eta: etaFormatter.string(from: etaDate),
            remainingDistance: Self.formatDistance(route.distance),
            speedKph: max(0, (location?.speed ?? 0) * 3.6),
            gpsAccuracy: location?.horizontalAccuracy,
            isCalibrationGrid: false,
            statusMessage: (location?.horizontalAccuracy ?? 0) > 50 ? "GPS accuracy degraded" : nil
        )
    }

    private func firstUsableStep(in route: MKRoute?) -> Int {
        guard let route, !route.steps.isEmpty else { return 0 }
        return route.steps.firstIndex(where: { !$0.instructions.isEmpty && $0.distance > 0 }) ?? 0
    }

    private func nearestUpcomingStep(in route: MKRoute, to location: CLLocation) -> Int {
        guard !route.steps.isEmpty else { return 0 }
        let start = min(max(0, activeStepIndex), route.steps.count - 1)
        var bestIndex = start
        var bestDistance = CLLocationDistance.greatestFiniteMagnitude

        for index in start..<route.steps.count {
            let step = route.steps[index]
            guard step.polyline.pointCount > 0 else { continue }
            let points = step.polyline.points()
            let endPoint = points[step.polyline.pointCount - 1].coordinate
            let endLocation = CLLocation(latitude: endPoint.latitude, longitude: endPoint.longitude)
            let distance = location.distance(from: endLocation)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
            if distance < 30, index + 1 < route.steps.count { return index + 1 }
        }
        return bestIndex
    }

    private static func formatDistance(_ meters: CLLocationDistance) -> String {
        let safeMeters = max(0, meters)
        if safeMeters < 1_000 { return "\(Int(safeMeters.rounded())) m" }
        return String(format: "%.1f km", safeMeters / 1_000)
    }
}

enum NavigationError: LocalizedError {
    case emptyDestination
    case destinationNotFound
    case locationUnavailable
    case routeNotFound

    var errorDescription: String? {
        switch self {
        case .emptyDestination: return "Enter a destination, coordinate, or map URL."
        case .destinationNotFound: return "The destination could not be resolved."
        case .locationUnavailable: return "Current location is not available yet."
        case .routeNotFound: return "MapKit did not return a driving route."
        }
    }
}
