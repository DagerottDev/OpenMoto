import Foundation

enum DERBuilder {
    static func rsaPublicKey(modulus: Data, exponent: Data) -> Data {
        let body = integer(modulus) + integer(exponent)
        return Data([0x30]) + length(body.count) + body
    }

    private static func integer(_ value: Data) -> Data {
        var normalized = DataIntegerEncoding.stripLeadingZeroes(value)
        if let first = normalized.first, first & 0x80 != 0 {
            normalized.insert(0, at: normalized.startIndex)
        }
        return Data([0x02]) + length(normalized.count) + normalized
    }

    private static func length(_ value: Int) -> Data {
        if value < 0x80 { return Data([UInt8(value)]) }
        var bytes: [UInt8] = []
        var remaining = value
        while remaining > 0 {
            bytes.insert(UInt8(remaining & 0xff), at: 0)
            remaining >>= 8
        }
        return Data([0x80 | UInt8(bytes.count)]) + Data(bytes)
    }
}
