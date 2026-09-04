import Foundation

struct ByteCursor {
    private let bytes: [UInt8]
    private(set) var offset: Int = 0

    init(_ data: Data) { bytes = Array(data) }

    var remaining: Int { bytes.count - offset }

    mutating func readUInt8() -> UInt8? {
        guard remaining >= 1 else { return nil }
        defer { offset += 1 }
        return bytes[offset]
    }

    mutating func readUInt16BE() -> UInt16? {
        guard remaining >= 2 else { return nil }
        defer { offset += 2 }
        return UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
    }

    mutating func readData(count: Int) -> Data? {
        guard count >= 0, remaining >= count else { return nil }
        defer { offset += count }
        return Data(bytes[offset..<(offset + count)])
    }
}
