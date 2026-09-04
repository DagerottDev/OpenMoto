import Foundation

struct DashProtocolVersion: Codable, Hashable, Sendable {
    var firmware: String
    var notes: String

    static let unknown = DashProtocolVersion(firmware: "unknown", notes: "Hardware validation pending")
}
