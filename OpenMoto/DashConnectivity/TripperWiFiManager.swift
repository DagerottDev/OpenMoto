import Combine
import Foundation
import NetworkExtension

protocol DashWiFiJoining {
    func join(ssid: String, passphrase: String) async throws
    func removeConfiguration(forSSID ssid: String) async
}

@MainActor
final class TripperWiFiManager: ObservableObject, DashWiFiJoining {
    enum Status: Equatable {
        case idle
        case requesting
        case joined
        case failed(String)

        var description: String {
            switch self {
            case .idle: return "Idle"
            case .requesting: return "Requesting Wi-Fi join…"
            case .joined: return "Join request completed"
            case .failed(let message): return "Failed: \(message)"
            }
        }
    }

    @Published private(set) var status: Status = .idle

    func join(ssid: String, passphrase: String) async throws {
        let trimmedSSID = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSSID.isEmpty else {
            throw WiFiJoinError.missingSSID
        }

        status = .requesting

        let configuration: NEHotspotConfiguration
        if passphrase.isEmpty {
            configuration = NEHotspotConfiguration(ssid: trimmedSSID)
        } else {
            configuration = NEHotspotConfiguration(
                ssid: trimmedSSID,
                passphrase: passphrase,
                isWEP: false
            )
        }

        // Persist the app-managed accessory-network configuration instead of using
        // joinOnce. Projection sessions can last for hours and joinOnce is intentionally
        // short-lived. The user can remove this configuration explicitly from OpenMoto.
        configuration.joinOnce = false

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                NEHotspotConfigurationManager.shared.apply(configuration) { error in
                    if let nsError = error as NSError?,
                       nsError.domain == NEHotspotConfigurationErrorDomain,
                       nsError.code == NEHotspotConfigurationError.alreadyAssociated.rawValue {
                        // Already being on the requested accessory network is success for our flow.
                        continuation.resume(returning: ())
                    } else if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
            status = .joined
        } catch {
            status = .failed(error.localizedDescription)
            throw error
        }
    }

    func removeConfiguration(forSSID ssid: String) async {
        let trimmedSSID = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSSID.isEmpty else { return }
        NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: trimmedSSID)
        status = .idle
    }
}

enum WiFiJoinError: LocalizedError {
    case missingSSID

    var errorDescription: String? {
        switch self {
        case .missingSSID:
            return "Enter the dash Wi-Fi SSID first."
        }
    }
}
