import Foundation
import Security

enum RSAEncryptor {
    static func encryptPKCS1(
        plaintext: Data,
        modulus: Data,
        exponent: Data
    ) throws -> Data {
        let der = DERBuilder.rsaPublicKey(modulus: modulus, exponent: exponent)
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits: modulus.count * 8
        ]

        var importError: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(
            der as CFData,
            attributes as CFDictionary,
            &importError
        ) else {
            throw importError?.takeRetainedValue() ?? DashProtocolError.invalidPublicKey as CFError
        }

        let algorithm = SecKeyAlgorithm.rsaEncryptionPKCS1
        guard SecKeyIsAlgorithmSupported(key, .encrypt, algorithm) else {
            throw DashProtocolError.invalidPublicKey
        }

        var encryptionError: Unmanaged<CFError>?
        guard let encrypted = SecKeyCreateEncryptedData(
            key,
            algorithm,
            plaintext as CFData,
            &encryptionError
        ) else {
            if let error = encryptionError?.takeRetainedValue() { throw error }
            throw DashProtocolError.invalidPublicKey
        }
        return encrypted as Data
    }
}
