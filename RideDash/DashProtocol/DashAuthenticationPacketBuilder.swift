import Foundation

enum DashAuthenticationPacketBuilder {
    static func makeEncryptedSessionPacket(
        ssid: String,
        sessionKey: Data,
        modulus: Data,
        exponent: Data
    ) throws -> Data {
        var plaintext = Data(ssid.utf8)
        plaintext.append(sessionKey)

        let encrypted = try RSAEncryptor.encryptPKCS1(
            plaintext: plaintext,
            modulus: modulus,
            exponent: exponent
        )

        // Public reference uses a 128-byte RSA ciphertext field for the known dash.
        // Do not silently truncate if a different firmware/key size is encountered.
        guard encrypted.count == 128 else {
            throw DashProtocolError.invalidPacket(
                "Expected 128-byte RSA ciphertext, got \(encrypted.count). Add a firmware capability profile before sending."
            )
        }

        var packet = try HexCodec.data(from: DashProtocolConstants.authenticationPayloadPrefixHex)
        packet.append(encrypted)
        return packet
    }
}
