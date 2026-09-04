import Foundation

struct DashInputEvent: Identifiable, Sendable {
    let id = UUID()
    let action: DashInputAction
    let rawCode: UInt8
    let payload: Data
}

enum DashInputDecoder {
    /// Public references show button events containing `09 00 00 01 XX`.
    /// We intentionally search for that marker instead of assuming a fixed outer wrapper.
    static func decode(_ data: Data) -> DashInputEvent? {
        let bytes = [UInt8](data)
        guard bytes.count >= 5 else { return nil }

        for index in 0...(bytes.count - 5) {
            guard bytes[index] == 0x09,
                  bytes[index + 1] == 0x00,
                  bytes[index + 2] == 0x00,
                  bytes[index + 3] == 0x01 else { continue }

            let code = bytes[index + 4]
            let action: DashInputAction
            switch code {
            case DashProtocolConstants.buttonRight: action = .right
            case DashProtocolConstants.buttonLeft: action = .left
            case DashProtocolConstants.buttonDown: action = .down
            case DashProtocolConstants.buttonClick: action = .click
            default: action = .unknown
            }
            return DashInputEvent(action: action, rawCode: code, payload: data)
        }
        return nil
    }

    static func acknowledgement(for event: DashInputEvent) throws -> Data? {
        guard event.action != .unknown else { return nil }
        return try HexCodec.data(
            from: DashProtocolConstants.buttonAckPrefixHex + String(format: "%02X", event.rawCode)
        )
    }
}
