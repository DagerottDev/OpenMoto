import Foundation

enum DashDatagramDirection: String, Codable, Sendable {
    case inbound
    case outbound
}

struct DashDatagram: Identifiable, Hashable, Sendable {
    let id: UUID
    let timestamp: Date
    let direction: DashDatagramDirection
    let host: String
    let port: UInt16
    let payload: Data

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        direction: DashDatagramDirection,
        host: String,
        port: UInt16,
        payload: Data
    ) {
        self.id = id
        self.timestamp = timestamp
        self.direction = direction
        self.host = host
        self.port = port
        self.payload = payload
    }

    var hexPreview: String { HexCodec.string(from: payload, limit: 48) }
}
