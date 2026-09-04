import Foundation

/// Minimal, defensive framing helpers for the public K1G/TLV-shaped packets.
/// The protocol is intentionally represented as raw typed envelopes until hardware validation.
struct K1GPacket: Hashable, Sendable {
    let raw: Data

    var declaredLength: Int? {
        guard raw.count >= 2 else { return nil }
        return Int(raw[0]) << 8 | Int(raw[1])
    }

    var payload: Data {
        guard raw.count > 2 else { return Data() }
        return raw.dropFirst(2)
    }

    var isLengthPlausible: Bool {
        guard let declaredLength else { return false }
        // Public captures use an outer two-byte length. Some firmware wrappers may
        // count slightly differently, so keep decoding tolerant but never unsafe.
        return declaredLength <= raw.count + 4 && declaredLength >= 0
    }
}

enum K1GCodec {
    static func decode(_ data: Data) -> K1GPacket? {
        guard data.count >= 2 else { return nil }
        return K1GPacket(raw: data)
    }

    static func knownControlPacket(hex: String) throws -> K1GPacket {
        K1GPacket(raw: try HexCodec.data(from: hex))
    }

    static func contains(_ bytes: [UInt8], in data: Data) -> Bool {
        guard !bytes.isEmpty, data.count >= bytes.count else { return false }
        let raw = [UInt8](data)
        for i in 0...(raw.count - bytes.count) {
            if Array(raw[i..<(i + bytes.count)]) == bytes { return true }
        }
        return false
    }
}
