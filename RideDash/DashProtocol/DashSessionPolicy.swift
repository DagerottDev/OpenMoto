import Foundation

struct DashSessionPolicy: Sendable {
    var authenticationTimeout: TimeInterval = 8
    var reconnectDelay: TimeInterval = 2
    var maximumReconnectAttempts: Int = 5
    var projectionHeartbeatHz: Double = 4
    var routeHeartbeatHz: Double = 1
    var navInfoHeartbeatHz: Double = 1
}
