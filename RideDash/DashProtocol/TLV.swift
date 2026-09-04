import Foundation

struct TLV: Hashable, Sendable {
    let type: UInt16
    let value: Data
}

enum TLVCodec {
    /// Generic two-byte type + two-byte big-endian length helper for local fixtures.
    /// Hardware-specific outer framing remains in K1GCodec.
    static func encode(_ tlv: TLV) -> Data {
        var result = Data()
        result.append(UInt8((tlv.type >> 8) & 0xff))
        result.append(UInt8(tlv.type & 0xff))
        let length = UInt16(clamping: tlv.value.count)
        result.append(UInt8((length >> 8) & 0xff))
        result.append(UInt8(length & 0xff))
        result.append(tlv.value)
        return result
    }

    static func decodeMany(_ data: Data) -> [TLV] {
        var cursor = ByteCursor(data)
        var result: [TLV] = []
        while cursor.remaining >= 4 {
            guard let type = cursor.readUInt16BE(),
                  let length = cursor.readUInt16BE(),
                  let value = cursor.readData(count: Int(length)) else { break }
            result.append(TLV(type: type, value: value))
        }
        return result
    }
}
