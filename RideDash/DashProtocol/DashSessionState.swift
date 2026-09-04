import Foundation

enum DashSessionState: String, Codable, CaseIterable, Sendable {
    case disconnected
    case joiningWiFi
    case networkReady
    case transportReady
    case authenticating
    case authenticated
    case navigationReady
    case projecting
    case recovering
    case failed
}

enum DashInputAction: String, Codable, Sendable {
    case right
    case left
    case down
    case click
    case unknown
}
