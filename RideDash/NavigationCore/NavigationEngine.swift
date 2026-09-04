import Combine
import CoreLocation
import Foundation
import MapKit

@MainActor
final class NavigationEngine: ObservableObject {
    @Published private(set) var route: MKRoute?
    @Published private(set) var destination: MKMapItem?
    @Published private(set) var projectionState: ProjectionUIState = .init()
    @Published private(set) var isCalculating = false
    @Published private(set) var lastError: String?

    private var stepIndex = 0

    func plan(destinationQuery: String, from origin: CLLocation) async throws {
        isCalculating = true
        defer { isCalculating = false }

        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = destinationQuery
        searchRequest.region = MKCoordinateRegion(
            center: origin.coordinate,
            latitudinalMeters: 100_000,
            longitudinalMeters: 100_000
        )
        let searchResponse = try await MKLocalSearch(request: searchRequest).start()
        guard let item = searchResponse.mapItems.first else {
            throw NavigationEngineError.destinationNotFound
        }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin.coordinate))
        request.destination = item
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        let response = try await MKDirections(request: request).calculate()
        guard let route = response.routes.first else {
            throw NavigationEngineError.routeUnavailable
        }

        self.destination = item
        self.route = route
        stepIndex = firstUsefulStep(in: route.steps)
        update(location: origin)
    }

    func clearRoute() {
        route = nil
        destination = nil
        stepIndex = 0
        projectionState = .init()
    }

    func update(location: CLLocation) {
        guard let route else {
            projectionState.speedKPH = max(0, location.speed * 3.6)
            projectionState.gpsAccuracyMeters = max(0, location.horizontalAccuracy)
            return
        }

        let steps = route.steps
        guard !steps.isEmpty else { return }
        stepIndex = min(max(0, stepIndex), steps.count - 1)

        var step = steps[stepIndex]
        var distanceToTurn = distance(from: location, toEndOf: step)
        if distanceToTurn < 30, stepIndex + 1 < steps.count {
            stepIndex += 1
            step = steps[stepIndex]
            distanceToTurn = distance(from: location, toEndOf: step)
        }

        let laterDistance = steps.dropFirst(stepIndex + 1).reduce(0) { $0 + $1.distance }
        let remaining = max(0, distanceToTurn + laterDistance)
        let remainingRatio = route.distance > 0 ? remaining / route.distance : 0
        let eta = Date().addingTimeInterval(max(0, route.expectedTravelTime * remainingRatio))

        projectionState = ProjectionUIState(
            maneuver: maneuver(from: step.instructions),
            distanceToTurnMeters: Int(distanceToTurn.rounded()),
            remainingDistanceMeters: Int(remaining.rounded()),
            eta: eta,
            roadName: step.instructions.isEmpty ? (destination?.name ?? "Continue") : step.instructions,
            speedKPH: max(0, location.speed * 3.6),
            gpsAccuracyMeters: max(0, location.horizontalAccuracy),
            isRerouting: false,
            statusText: location.horizontalAccuracy > 35 ? "GPS accuracy low" : "Navigation"
        )
    }

    private func firstUsefulStep(in steps: [MKRoute.Step]) -> Int {
        steps.firstIndex(where: { !$0.instructions.isEmpty && $0.distance > 0 }) ?? 0
    }

    private func distance(from location: CLLocation, toEndOf step: MKRoute.Step) -> CLLocationDistance {
        guard step.polyline.pointCount > 0 else { return step.distance }
        let point = step.polyline.point(at: step.polyline.pointCount - 1).coordinate
        return location.distance(from: CLLocation(latitude: point.latitude, longitude: point.longitude))
    }

    private func maneuver(from instructions: String) -> NavigationManeuver {
        let text = instructions.lowercased()
        if text.contains("u-turn") || text.contains("u turn") { return .uTurn }
        if text.contains("roundabout") || text.contains("circle") { return .roundabout }
        if text.contains("slight left") || text.contains("keep left") { return .slightLeft }
        if text.contains("slight right") || text.contains("keep right") { return .slightRight }
        if text.contains("left") { return .turnLeft }
        if text.contains("right") { return .turnRight }
        if text.contains("arrive") || text.contains("destination") { return .arrive }
        return .continueStraight
    }
}

enum NavigationEngineError: LocalizedError {
    case destinationNotFound
    case routeUnavailable

    var errorDescription: String? {
        switch self {
        case .destinationNotFound: return "Destination could not be found."
        case .routeUnavailable: return "No driving route is available."
        }
    }
}
