import Foundation

struct ProjectionUIState: Sendable, Equatable {
    var maneuver: NavigationManeuver = .continueStraight
    var distanceToTurnMeters: Int = 0
    var remainingDistanceMeters: Int = 0
    var eta: Date?
    var roadName: String = "Ready"
    var speedKPH: Double = 0
    var gpsAccuracyMeters: Double?
    var isRerouting = false
    var statusText = "RideDash"

    static let preview = ProjectionUIState(
        maneuver: .turnRight,
        distanceToTurnMeters: 350,
        remainingDistanceMeters: 12_400,
        eta: Date().addingTimeInterval(1_800),
        roadName: "Continue to destination",
        speedKPH: 42,
        gpsAccuracyMeters: 5,
        isRerouting: false,
        statusText: "Navigation"
    )
}
