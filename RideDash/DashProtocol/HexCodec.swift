import Foundation

enum HexCodecError: LocalizedError {
    case oddLength
    case invalidByte(String)

    var errorDescription: String? {
        switch self {
        case .oddLength: return "Hex string must contain an even number of digits."
        case .invalidByte(let value): return "Invalid hex byte: \(value)"
        }
    }
}

enum HexCodec {
    static func data(from string: String) throws -> Data {
        let cleaned = string
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\t", with: "")
        guard cleaned.count.isMultiple(of: 2) else { throw HexCodecError.oddLength }

        var result = Data()
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            let byteString = String(cleaned[index..<next])
            guard let byte = UInt8(byteString, radix: 16) else {
                throw HexCodecError.invalidByte(byteString)
            }
            result.append(byte)
            index = next
        }
        return result
    }

    static func string(from data: Data, limit: Int? = nil) -> String {
        let bytes = limit.map { data.prefix($0) } ?? data[...]
        let value = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        if let limit, data.count > limit { return value + " …" }
        return value
    }
}
