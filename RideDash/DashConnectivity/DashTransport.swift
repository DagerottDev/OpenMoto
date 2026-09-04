import Foundation
import Network

@MainActor
final class DashTransport: ObservableObject {
    enum State: Equatable {
        case stopped
        case preparing
        case ready
        case waiting(String)
        case failed(String)

        var description: String {
            switch self {
            case .stopped: return "Stopped"
            case .preparing: return "Preparing"
            case .ready: return "UDP route ready"
            case .waiting(let reason): return "Waiting: \(reason)"
            case .failed(let error): return "Failed: \(error)"
            }
        }
    }

    @Published private(set) var state: State = .stopped

    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "dev.dagerott.RideDash.udp-transport")

    func start(host: String, port: UInt16) throws {
        stop()

        guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DashTransportError.invalidHost
        }
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
            throw DashTransportError.invalidPort
        }

        state = .preparing
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: endpointPort,
            using: .udp
        )
        self.connection = connection

        connection.stateUpdateHandler = { [weak self] newState in
            Task { @MainActor in
                guard let self else { return }
                switch newState {
                case .setup:
                    self.state = .preparing
                case .preparing:
                    self.state = .preparing
                case .ready:
                    self.state = .ready
                case .waiting(let error):
                    self.state = .waiting(error.localizedDescription)
                case .failed(let error):
                    self.state = .failed(error.localizedDescription)
                case .cancelled:
                    self.state = .stopped
                @unknown default:
                    self.state = .waiting("Unknown Network.framework state")
                }
            }
        }

        connection.start(queue: queue)
    }

    func stop() {
        connection?.cancel()
        connection = nil
        state = .stopped
    }
}

enum DashTransportError: LocalizedError {
    case invalidHost
    case invalidPort

    var errorDescription: String? {
        switch self {
        case .invalidHost: return "Dash host is empty."
        case .invalidPort: return "Dash UDP port is invalid."
        }
    }
}
