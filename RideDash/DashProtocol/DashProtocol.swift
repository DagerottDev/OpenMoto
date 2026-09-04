import Foundation
import Security

// MARK: - Protocol profile

struct DashProtocolProfile: Codable, Hashable, Sendable {
    var host: String = "192.168.1.1"
    var broadcastHost: String = "192.168.1.255"
    var controlPort: UInt16 = 2000
    var inputPort: UInt16 = 2002
    var videoPort: UInt16 = 5000
    var renderWidth: Int = 526
    var renderHeight: Int = 300
    var fps: Int = 4
    var bitrateKbps: Int = 250
    var respondToInput: Bool = true

    static let publicReference = DashProtocolProfile()
}

// MARK: - Hex helpers

enum HexCodec {
    static func data(from string: String) throws -> Data {
        let clean = string
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\t", with: "")
        guard clean.count.isMultiple(of: 2) else { throw DashProtocolError.invalidHex }

        var output = Data(capacity: clean.count / 2)
        var index = clean.startIndex
        while index < clean.endIndex {
            let next = clean.index(index, offsetBy: 2)
            guard let byte = UInt8(clean[index..<next], radix: 16) else {
                throw DashProtocolError.invalidHex
            }
            output.append(byte)
            index = next
        }
        return output
    }

    static func string(_ data: Data, maxBytes: Int? = nil) -> String {
        let bytes = maxBytes.map { data.prefix($0) } ?? data[...]
        return bytes.map { String(format: "%02X", $0) }.joined()
    }
}

// MARK: - K1G

struct K1GSegment: Hashable, Sendable {
    let type: UInt8
    let subtype: UInt8
    let payload: Data

    var hex: String {
        let length = UInt16(clamping: payload.count)
        return String(format: "%02X%02X%04X", type, subtype, length) + HexCodec.string(payload)
    }
}

struct K1GEnvelope: Hashable, Sendable {
    let outerLength: Int
    let declaredSegmentCount: Int
    let segments: [K1GSegment]
}

enum K1GCodec {
    static let requestAuthHex = "0016000200000000020100054B314720000804000101"
    static let sessionKeyPrefixHex = "0095000200000000020100054B3147200008000080"
    static let navContextHex = "0016000200000000020100054B31472000052E00011E"
    static let emptyListsHex = "002A000600000000020100054B31472000052F0001000530000100053100010005320001000533000100"
    static let startNavigationHex = "0016000200000000020100054B31472000068000010B"
    static let projectionFrameHex = "0016000200000000020100054B314720000556000155"
    static let projectionOnHex = "0016000200000000020100054B314720000605000155"
    static let projectionStopHex = "0016000200000000020100054B3147200005560001AA"
    static let projectionOffHex = "0016000200000000020100054B3147200006050001AA"
    static let buttonAckPrefixHex = "0016000200000000020100054B3147200006800001"

    static let initialBurst: [String?] = [
        requestAuthHex,
        nil,
        "0018000200000000020100054B31472002060600030E3334",
        "0016000200000000020100054B314720030557000155",
        "0016000200000000020100054B3147200405560001AA",
        "0016000200000000020100054B3147200506050001AA",
        "0016000200000000020100054B3147200605170001AA",
        "001D000200000000020100054B314720080A020008AA55000000000000",
        "0044000A00000000020100054B3147200906080001FF060300015506040001A2060F0001AA0601000101054C000113052D00020000051B0001190521000132054D000132"
    ]

    private static let navTemplateHex =
        "007E001100000000020100054B31472025050100145461696C6C65206465204D617320647520477200" +
        "050200013C050300013405050002000A05060001300507000130050800043033303305540001300509" +
        "0002004F0546000110050A000155050C000104050B0006303031303030055500012006050001AA060D0001AA"

    static func decode(_ data: Data) -> K1GEnvelope? {
        guard data.count >= 8 else { return nil }
        let outerLength = Int(data[0]) << 8 | Int(data[1])
        let segmentCount = Int(data[2]) << 8 | Int(data[3])
        var offset = 8
        var segments: [K1GSegment] = []
        segments.reserveCapacity(segmentCount)

        for _ in 0..<segmentCount {
            guard offset + 4 <= data.count else { break }
            let type = data[offset]
            let subtype = data[offset + 1]
            let length = Int(data[offset + 2]) << 8 | Int(data[offset + 3])
            offset += 4
            let end = min(data.count, offset + length)
            guard offset <= end else { break }
            segments.append(.init(type: type, subtype: subtype, payload: Data(data[offset..<end])))
            offset = end
        }

        return K1GEnvelope(outerLength: outerLength, declaredSegmentCount: segmentCount, segments: segments)
    }

    static func patchSequence(_ packet: Data, sequence: UInt8) throws -> Data {
        var bytes = [UInt8](packet)
        let marker: [UInt8] = [0x4B, 0x31, 0x47, 0x20]
        guard let markerIndex = find(marker, in: bytes), markerIndex + 4 < bytes.count else {
            throw DashProtocolError.missingK1GMarker
        }
        bytes[markerIndex + 4] = sequence
        return Data(bytes)
    }

    static func hostnameAnnounce(_ hostname: String) -> Data {
        let raw = Data(hostname.utf8.prefix(200))
        var body = (try? HexCodec.data(from: "0021000200000000020100054B314720")) ?? Data()
        body.append(contentsOf: [0x01, 0x06, 0x0B, 0x00, UInt8(clamping: raw.count + 1)])
        body.append(raw)
        body.append(0)
        setUInt16BE(UInt16(clamping: body.count), at: 0, in: &body)
        return body
    }

    static func routeCard(title: String, projectionOn: Bool) throws -> Data {
        let template = try HexCodec.data(from: navTemplateHex)
        guard let markerRange = template.range(of: Data("K1G ".utf8)) else {
            throw DashProtocolError.missingK1GMarker
        }
        let sequenceOffset = markerRange.lowerBound + 4
        let titleTLVOffset = sequenceOffset + 1
        guard titleTLVOffset + 4 <= template.count,
              template[titleTLVOffset] == 0x05,
              template[titleTLVOffset + 1] == 0x01 else {
            throw DashProtocolError.invalidTemplate
        }

        let oldLength = Int(template[titleTLVOffset + 2]) << 8 | Int(template[titleTLVOffset + 3])
        let oldTitleStart = titleTLVOffset + 4
        let oldTitleEnd = min(template.count, oldTitleStart + oldLength)
        let titleData = Data(title.utf8.prefix(60)) + Data([0])

        var output = Data(template.prefix(oldTitleStart))
        let lengthBytes = withUnsafeBytes(of: UInt16(clamping: titleData.count).bigEndian) { Data($0) }
        output.replaceSubrange(titleTLVOffset + 2..<titleTLVOffset + 4, with: lengthBytes)
        output.append(titleData)
        output.append(template.suffix(from: oldTitleEnd))

        let projectionMarker = Data([0x06, 0x05, 0x00, 0x01])
        if let range = output.range(of: projectionMarker, options: .backwards), range.upperBound < output.count {
            output[range.upperBound] = projectionOn ? 0x55 : 0xAA
        }
        setUInt16BE(UInt16(clamping: output.count), at: 0, in: &output)
        return output
    }

    static func buttonAck(_ buttonByte: UInt8) throws -> Data {
        try HexCodec.data(from: buttonAckPrefixHex + String(format: "%02X", buttonByte))
    }

    static func buildSessionKeyPacket(ciphertext: Data) throws -> Data {
        guard ciphertext.count == 128 else { throw DashProtocolError.unexpectedRSAKeySize }
        return try HexCodec.data(from: sessionKeyPrefixHex) + ciphertext
    }

    private static func find(_ needle: [UInt8], in haystack: [UInt8]) -> Int? {
        guard !needle.isEmpty, haystack.count >= needle.count else { return nil }
        for i in 0...(haystack.count - needle.count) {
            if haystack[i..<(i + needle.count)].elementsEqual(needle) { return i }
        }
        return nil
    }

    private static func setUInt16BE(_ value: UInt16, at offset: Int, in data: inout Data) {
        guard data.count >= offset + 2 else { return }
        data[offset] = UInt8((value >> 8) & 0xFF)
        data[offset + 1] = UInt8(value & 0xFF)
    }
}

// MARK: - Input / auth events

enum DashButton: UInt8, Codable, Hashable, Sendable, CaseIterable {
    case right = 0x13
    case left = 0x14
    case down = 0x15
    case click = 0x18
}

enum DashProtocolEvent: Hashable, Sendable {
    case rsaModulus(Data)
    case rsaExponent(Data)
    case authAccepted
    case authRejected(UInt8)
    case button(DashButton)
    case segment(K1GSegment)
}

enum DashEventDecoder {
    static func events(from datagram: Data) -> [DashProtocolEvent] {
        guard let envelope = K1GCodec.decode(datagram) else { return [] }
        return envelope.segments.map { segment in
            switch (segment.type, segment.subtype) {
            case (0x07, 0x00): return .rsaModulus(segment.payload)
            case (0x07, 0x03): return .rsaExponent(segment.payload)
            case (0x07, 0x01):
                let status = segment.payload.first ?? 0
                return status == 0x01 ? .authAccepted : .authRejected(status)
            case (0x09, 0x00):
                if let value = segment.payload.first, let button = DashButton(rawValue: value) { return .button(button) }
                return .segment(segment)
            default: return .segment(segment)
            }
        }
    }
}

// MARK: - Authentication

struct DashAuthenticatedSession: Sendable {
    let aesKey: Data
}

enum DashAuthenticator {
    static func randomAES256Key() throws -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { throw DashProtocolError.randomGenerationFailed(status) }
        return Data(bytes)
    }

    static func encryptedSessionPayload(
        ssid: String,
        modulus: Data,
        exponent: Data,
        aesKey: Data
    ) throws -> Data {
        guard aesKey.count == 32 else { throw DashProtocolError.invalidAESKey }
        let publicKeyDER = DER.rsaPublicKey(modulus: modulus, exponent: exponent)
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits: modulus.count * 8
        ]

        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(publicKeyDER as CFData, attributes as CFDictionary, &error) else {
            if let error { throw error.takeRetainedValue() }
            throw DashProtocolError.publicKeyCreationFailed
        }
        guard SecKeyIsAlgorithmSupported(key, .encrypt, .rsaEncryptionPKCS1) else {
            throw DashProtocolError.unsupportedRSAAlgorithm
        }

        let payload = Data(ssid.utf8) + aesKey
        guard let encrypted = SecKeyCreateEncryptedData(key, .rsaEncryptionPKCS1, payload as CFData, &error) else {
            if let error { throw error.takeRetainedValue() }
            throw DashProtocolError.rsaEncryptionFailed
        }
        return encrypted as Data
    }
}

private enum DER {
    static func rsaPublicKey(modulus: Data, exponent: Data) -> Data {
        sequence(integer(modulus) + integer(exponent))
    }

    private static func integer(_ raw: Data) -> Data {
        var body = Data(raw.drop(while: { $0 == 0 }))
        if body.isEmpty { body.append(0) }
        if let first = body.first, first & 0x80 != 0 { body.insert(0, at: 0) }
        return Data([0x02]) + length(body.count) + body
    }

    private static func sequence(_ content: Data) -> Data {
        Data([0x30]) + length(content.count) + content
    }

    private static func length(_ count: Int) -> Data {
        if count < 0x80 { return Data([UInt8(count)]) }
        var value = count
        var bytes: [UInt8] = []
        while value > 0 {
            bytes.insert(UInt8(value & 0xFF), at: 0)
            value >>= 8
        }
        return Data([0x80 | UInt8(bytes.count)]) + Data(bytes)
    }
}

enum DashProtocolError: LocalizedError {
    case invalidHex
    case missingK1GMarker
    case invalidTemplate
    case unexpectedRSAKeySize
    case invalidAESKey
    case randomGenerationFailed(OSStatus)
    case publicKeyCreationFailed
    case unsupportedRSAAlgorithm
    case rsaEncryptionFailed

    var errorDescription: String? {
        switch self {
        case .invalidHex: return "Protocol hex string is malformed."
        case .missingK1GMarker: return "K1G marker was not found in the packet."
        case .invalidTemplate: return "The navigation packet template is invalid."
        case .unexpectedRSAKeySize: return "The current protocol profile expects an RSA-1024 key."
        case .invalidAESKey: return "The negotiated AES session key must be 32 bytes."
        case .randomGenerationFailed(let status): return "Secure random generation failed (\(status))."
        case .publicKeyCreationFailed: return "Could not create the dash RSA public key."
        case .unsupportedRSAAlgorithm: return "RSA PKCS#1 v1.5 encryption is not supported by this key."
        case .rsaEncryptionFailed: return "Could not encrypt the dash session payload."
        }
    }
}
