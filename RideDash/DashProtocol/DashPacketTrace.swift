import Foundation

struct DashPacketTrace: Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let direction: DashDatagramDirection
    let host: String
    let port: UInt16
    let byteCount: Int
    let hexPreview: String

    init(datagram: DashDatagram) {
        id = datagram.id
        timestamp = datagram.timestamp
        direction = datagram.direction
        host = datagram.host
        port = datagram.port
        byteCount = datagram.payload.count
        hexPreview = datagram.hexPreview
    }
}
