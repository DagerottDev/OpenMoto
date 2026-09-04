import Foundation

struct DashCompatibilityProfile: Codable, Hashable, Identifiable, Sendable {
    var id: String { "\(model)-\(firmware)" }
    var model: String
    var firmware: String
    var configuration: DashProtocolConfiguration
    var requiresButtonAck: Bool = true
    var projectionHeartbeatHz: Double = 4
    var routeHeartbeatHz: Double = 1
    var navigationHeartbeatHz: Double = 1
    var statusHeartbeatHz: Double = 1

    static let researchDefault = DashCompatibilityProfile(
        model: "Generic compatible dash",
        firmware: "unverified",
        configuration: .default
    )
}
