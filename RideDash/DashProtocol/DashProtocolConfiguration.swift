import Foundation

struct DashProtocolConfiguration: Codable, Hashable, Sendable {
    var dashHost: String = "192.168.1.1"
    var broadcastHost: String = "192.168.1.255"
    var controlPort: UInt16 = 2000
    var inputPort: UInt16 = 2002
    var videoPort: UInt16 = 5000
    var renderWidth: Int = 526
    var renderHeight: Int = 300
    var projectionFPS: Double = 4
    var videoBitrate: Int = 240_000
    var routeTitle: String = "RideDash"
    var hostname: String = "iPhone"

    static let `default` = DashProtocolConfiguration()
}
