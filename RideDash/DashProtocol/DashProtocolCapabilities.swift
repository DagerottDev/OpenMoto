import Foundation

struct DashProtocolCapabilities: Codable, Hashable, Sendable {
    var supportsAuthentication = true
    var supportsProjection = true
    var supportsButtonInput = true
    var supportsNavigationInfo = true
    var supportsRouteCard = true
    var supportsProjectionHeartbeat = true

    static let `default` = DashProtocolCapabilities()
}
