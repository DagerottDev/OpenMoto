import Foundation

struct DashSessionMetrics: Sendable {
    var connectedAt: Date?
    var authenticatedAt: Date?
    var projectionStartedAt: Date?
    var inboundPackets: Int = 0
    var outboundPackets: Int = 0
    var videoPackets: Int = 0
    var encodedFrames: Int = 0
    var reconnectAttempts: Int = 0

    var projectionDuration: TimeInterval {
        guard let projectionStartedAt else { return 0 }
        return Date().timeIntervalSince(projectionStartedAt)
    }
}
