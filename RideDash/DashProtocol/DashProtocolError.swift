import Foundation

enum DashProtocolError: LocalizedError {
    case transportNotReady
    case authenticationTimeout
    case missingPublicKey
    case invalidPublicKey
    case authenticationRejected
    case invalidPacket(String)
    case projectionNotReady

    var errorDescription: String? {
        switch self {
        case .transportNotReady: return "Dash transport is not ready."
        case .authenticationTimeout: return "Dash authentication timed out."
        case .missingPublicKey: return "Dash did not provide the required public-key material."
        case .invalidPublicKey: return "Dash public-key material could not be imported."
        case .authenticationRejected: return "Dash rejected the session authentication."
        case .invalidPacket(let reason): return "Invalid dash packet: \(reason)"
        case .projectionNotReady: return "Dash session is not ready for projection."
        }
    }
}
