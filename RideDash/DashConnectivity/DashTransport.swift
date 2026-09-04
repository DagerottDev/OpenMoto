import Combine
import Foundation
import Network

struct DashDatagram: Identifiable, Sendable {
    enum Direction: String, Sendable { case inbound, outbound }
    enum Channel: String, Sendable { case control, input, video }

    let id = UUID()
    let timestamp: Date
    let direction: Direction
    let channel: Channel
    let endpoint: String
    let data: Data
}

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
            case .ready: return "UDP transport ready"
            case .waiting(let reason): return "Waiting: \(reason)"
            case .failed(let error): return "Failed: \(error)"
            }
        }
    }

    @Published private(set) var state: State = .stopped
    @Published private(set) var receivedPackets: Int = 0
    @Published private(set) var sentPackets: Int = 0
    @Published private(set) var lastError: String?

    var onDatagram: (@Sendable (DashDatagram) -> Void)?

    private let queue = DispatchQueue(label: "dev.dagerott.RideDash.dash-transport")
    private var controlConnection: NWConnection?
    private var videoConnection: NWConnection?
    private var inputListener: NWListener?
    private var inputConnections: [ObjectIdentifier: NWConnection] = [:]
    private var profile: DashProtocolProfile?

    func start(profile: DashProtocolProfile) throws {
        stop()
        guard !profile.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DashTransportError.invalidHost
        }
        guard let controlPort = NWEndpoint.Port(rawValue: profile.controlPort),
              let videoPort = NWEndpoint.Port(rawValue: profile.videoPort),
              let inputPort = NWEndpoint.Port(rawValue: profile.inputPort) else {
            throw DashTransportError.invalidPort
        }

        self.profile = profile
        state = .preparing
        lastError = nil

        let control = NWConnection(
            host: NWEndpoint.Host(profile.broadcastHost),
            port: controlPort,
            using: .udp
        )
        controlConnection = control
        observe(connection: control, label: "control")
        control.start(queue: queue)

        let video = NWConnection(
            host: NWEndpoint.Host(profile.host),
            port: videoPort,
            using: .udp
        )
        videoConnection = video
        video.stateUpdateHandler = { [weak self] state in
            guard case .failed(let error) = state else { return }
            Task { @MainActor in self?.lastError = "Video UDP: \(error.localizedDescription)" }
        }
        video.start(queue: queue)

        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters, on: inputPort)
        inputListener = listener
        listener.stateUpdateHandler = { [weak self] newState in
            Task { @MainActor in
                guard let self else { return }
                switch newState {
                case .ready:
                    if self.controlConnection?.state == .ready { self.state = .ready }
                case .waiting(let error):
                    self.state = .waiting("Input listener: \(error.localizedDescription)")
                case .failed(let error):
                    self.state = .failed("Input listener: \(error.localizedDescription)")
                    self.lastError = error.localizedDescription
                default:
                    break
                }
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            self.acceptInput(connection)
        }
        listener.start(queue: queue)
    }

    /// Backward-compatible diagnostic route used by DiagnosticsView.
    func start(host: String, port: UInt16) throws {
        var profile = DashProtocolProfile.publicReference
        profile.host = host
        profile.broadcastHost = host
        profile.videoPort = port
        profile.controlPort = port
        try start(profile: profile)
    }

    func stop() {
        controlConnection?.cancel()
        videoConnection?.cancel()
        inputListener?.cancel()
        inputConnections.values.forEach { $0.cancel() }
        controlConnection = nil
        videoConnection = nil
        inputListener = nil
        inputConnections.removeAll()
        profile = nil
        state = .stopped
    }

    func sendControl(_ data: Data) async throws {
        guard let connection = controlConnection else { throw DashTransportError.notStarted }
        try await send(data, on: connection, channel: .control)
    }

    func sendVideo(_ data: Data) async throws {
        guard let connection = videoConnection else { throw DashTransportError.notStarted }
        try await send(data, on: connection, channel: .video)
    }

    private func send(_ data: Data, on connection: NWConnection, channel: DashDatagram.Channel) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { [weak self] error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                Task { @MainActor in
                    self?.sentPackets += 1
                    self?.emit(.init(
                        timestamp: .now,
                        direction: .outbound,
                        channel: channel,
                        endpoint: self?.endpointDescription(connection.endpoint) ?? "unknown",
                        data: data
                    ))
                }
                continuation.resume()
            })
        }
    }

    private func observe(connection: NWConnection, label: String) {
        connection.stateUpdateHandler = { [weak self, weak connection] newState in
            Task { @MainActor in
                guard let self else { return }
                switch newState {
                case .setup, .preparing:
                    self.state = .preparing
                case .ready:
                    if self.inputListener?.state == .ready { self.state = .ready }
                case .waiting(let error):
                    self.state = .waiting("\(label): \(error.localizedDescription)")
                case .failed(let error):
                    self.state = .failed("\(label): \(error.localizedDescription)")
                    self.lastError = error.localizedDescription
                case .cancelled:
                    if connection === self.controlConnection { self.state = .stopped }
                @unknown default:
                    self.state = .waiting("Unknown Network.framework state")
                }
            }
        }
    }

    private func acceptInput(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        inputConnections[id] = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            if case .ready = state { self.receiveNext(on: connection) }
            if case .failed = state { self.inputConnections.removeValue(forKey: id) }
            if case .cancelled = state { self.inputConnections.removeValue(forKey: id) }
        }
        connection.start(queue: queue)
    }

    private func receiveNext(on connection: NWConnection) {
        connection.receiveMessage { [weak self, weak connection] data, _, _, error in
            guard let self, let connection else { return }
            if let data, !data.isEmpty {
                Task { @MainActor in
                    self.receivedPackets += 1
                    self.emit(.init(
                        timestamp: .now,
                        direction: .inbound,
                        channel: .input,
                        endpoint: self.endpointDescription(connection.endpoint),
                        data: data
                    ))
                }
            }
            if error == nil { self.receiveNext(on: connection) }
        }
    }

    private func emit(_ datagram: DashDatagram) {
        onDatagram?(datagram)
    }

    private func endpointDescription(_ endpoint: NWEndpoint) -> String {
        switch endpoint {
        case .hostPort(let host, let port): return "\(host):\(port)"
        default: return String(describing: endpoint)
        }
    }
}

enum DashTransportError: LocalizedError {
    case invalidHost
    case invalidPort
    case notStarted

    var errorDescription: String? {
        switch self {
        case .invalidHost: return "Dash host is empty."
        case .invalidPort: return "Dash UDP port is invalid."
        case .notStarted: return "Dash UDP transport has not been started."
        }
    }
}
