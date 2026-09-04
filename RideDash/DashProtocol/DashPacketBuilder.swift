import Foundation

enum DashPacketBuilder {
    /// Builds a conservative opaque route-card payload used by the session coordinator.
    /// The public protocol's outer 0x007E route-card framing is firmware-sensitive;
    /// manual hardware testing may refine this builder without touching navigation UI.
    static func routeCard(_ card: RouteCard) -> Data {
        var body = Data()
        body.append(contentsOf: [0x00, 0x7E])
        let title = Data(card.title.utf8.prefix(48))
        body.append(UInt8(clamping: title.count))
        body.append(title)
        let distance = UInt32(clamping: card.remainingDistanceMeters)
        body.append(UInt8((distance >> 24) & 0xff))
        body.append(UInt8((distance >> 16) & 0xff))
        body.append(UInt8((distance >> 8) & 0xff))
        body.append(UInt8(distance & 0xff))
        body.append(card.projectionOn ? 1 : 0)
        return body
    }

    /// Local typed format. This is kept separate from the public K1G constants so
    /// firmware validation can replace only this function when exact nav-info framing is confirmed.
    static func navigationInfo(_ instruction: DashNavigationInstruction) -> Data {
        var body = Data([0x4E, 0x41, 0x56, 0x01]) // NAV + local schema version
        body.append(instruction.maneuver.rawValue)
        appendUInt32(UInt32(clamping: instruction.distanceToTurnMeters), to: &body)
        appendUInt32(UInt32(clamping: instruction.remainingDistanceMeters), to: &body)
        let road = Data(instruction.roadName.utf8.prefix(48))
        body.append(UInt8(clamping: road.count))
        body.append(road)
        return body
    }

    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        data.append(UInt8((value >> 24) & 0xff))
        data.append(UInt8((value >> 16) & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8(value & 0xff))
    }
}
