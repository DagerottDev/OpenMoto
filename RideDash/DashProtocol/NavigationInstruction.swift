import Foundation

enum NavigationManeuver: UInt8, Codable, Sendable {
    case continueStraight = 0
    case turnLeft = 1
    case turnRight = 2
    case slightLeft = 3
    case slightRight = 4
    case uTurn = 5
    case roundabout = 6
    case arrive = 7
}

struct DashNavigationInstruction: Sendable {
    var maneuver: NavigationManeuver
    var distanceToTurnMeters: Int
    var remainingDistanceMeters: Int
    var roadName: String
}
