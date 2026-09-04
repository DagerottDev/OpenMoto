import Foundation

struct DashPublicKeyMaterial: Sendable {
    var modulus: Data?
    var exponent: Data?

    var isComplete: Bool { modulus != nil && exponent != nil }
}
