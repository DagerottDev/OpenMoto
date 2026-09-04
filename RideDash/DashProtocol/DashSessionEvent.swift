import Foundation

enum DashSessionEvent: Sendable {
    case wifiJoinRequested
    case networkSatisfied
    case transportReady
    case authenticationStarted
    case authenticationSucceeded
    case authenticationFailed(String)
    case navigationReady
    case projectionStarted
    case projectionStopped
    case input(DashInputAction)
    case transportLost(String)
}
