import Foundation

enum DashAuthenticationResponseParser {
    enum Event: Sendable {
        case modulus(Data)
        case exponent(Data)
        case authenticated
        case rejected
    }

    /// Parses the public response markers documented by the interoperability reference.
    /// The outer packet wrapper is intentionally tolerated; the marker is searched inside.
    static func parse(_ data: Data) -> Event? {
        let bytes = [UInt8](data)
        guard bytes.count >= 3 else { return nil }

        // 07 01 01 => auth OK in the public reference.
        if contains([0x07, 0x01, 0x01], in: bytes) { return .authenticated }
        if contains([0x07, 0x01, 0x00], in: bytes) { return .rejected }

        // 07 00 <modulus> and 07 03 <exponent>. Capture bytes after the marker;
        // hardware testing may refine wrapper-length stripping per firmware.
        if let index = index(of: [0x07, 0x00], in: bytes), index + 2 < bytes.count {
            return .modulus(Data(bytes[(index + 2)...]))
        }
        if let index = index(of: [0x07, 0x03], in: bytes), index + 2 < bytes.count {
            return .exponent(Data(bytes[(index + 2)...]))
        }
        return nil
    }

    private static func contains(_ needle: [UInt8], in haystack: [UInt8]) -> Bool {
        index(of: needle, in: haystack) != nil
    }

    private static func index(of needle: [UInt8], in haystack: [UInt8]) -> Int? {
        guard !needle.isEmpty, haystack.count >= needle.count else { return nil }
        for i in 0...(haystack.count - needle.count) {
            if Array(haystack[i..<(i + needle.count)]) == needle { return i }
        }
        return nil
    }
}
