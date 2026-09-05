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
    @Published private(set) var receivedPackets = 0
    @Published private(set) var sentPackets = 0
    @Published private(set) var lastError: String?

    var onDatagram: (@Sendable (DashDatagram) -> Void)?

    private let queue = DispatchQueue(label: "dev.dagerott.RideDash.dash-transport")
    private var controlConnection: NWConnection?
    private var videoConnection: NWConnection?
    private var inputListener: NWListener?
    private var inputConnections: [ObjectIdentifier: NWConnection] = [:]
    private var controlReady = false
    private var listenerReady = false

    func start(profile: DashProtocolProfile) throws {
        stop()
        guard !profile.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !profile.broadcastHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DashTransportError.invalidHost
        }
        guard let controlPort = NWEndpoint.Port(rawValue: profile.controlPort),
              let videoPort = NWEndpoint.Port(rawValue: profile.videoPort),
              let inputPort = NWEndpoint.Port(rawValue: profile.inputPort) else {
            throw DashTransportError.invalidPort
        }

        state = .preparing
        lastError = nil
        controlReady = false
        listenerReady = false

        // The public reference binds the control socket to UDP/2000 before broadcasting.
        // Preserve that source-port behavior: some embedded firmwares use it as part of
        // their fixed control-channel routing rather than replying to an arbitrary port.
        let controlParameters = NWParameters.udp
        controlParameters.allowLocalEndpointReuse = true
        controlParameters.requiredLocalEndpoint = .hostPort(
            host: NWEndpoint.Host("0.0.0.0"),
            port: controlPort
        )

        let control = NWConnection(
            host: NWEndpoint.Host(profile.broadcastHost),
            port: controlPort,
            using: controlParameters
        )
        controlConnection = control
        control.stateUpdateHandler = { [weak self] newState in
            Task { @MainActor in self?.handleControlState(newState) }
        }
        control.start(queue: queue)

        let video = NWConnection(
            host: NWEndpoint.Host(profile.host),
            port: videoPort,
            using: .udp
        )
        videoConnection = video
        video.stateUpdateHandler = { [weak self] newState in
            guard case .failed(let error) = newState else { return }
            Task { @MainActor in
                self?.lastError = "Video UDP: \(error.localizedDescription)"
            }
        }
        video.start(queue: queue)

        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters, on: inputPort)
        inputListener = listener
        listener.stateUpdateHandler = { [weak self] newState in
            Task { @MainActor in self?.handleListenerState(newState) }
        }
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in self?.acceptInput(connection) }
        }
        listener.start(queue: queue)
    }

    /// Lightweight diagnostic mode retained for the Diagnostics screen.
    func start(host: String, port: UInt16) throws {
        var profile = DashProtocolProfile.publicReference
        profile.host = host
        profile.broadcastHost = host
        profile.controlPort = port
        profile.videoPort = port
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
        controlReady = false
        listenerReady = false
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
                    guard let self else { return }
                    self.sentPackets += 1
                    self.emit(.init(
                        timestamp: .now,
                        direction: .outbound,
                        channel: channel,
                        endpoint: self.endpointDescription(connection.endpoint),
                        data: data
                    ))
                }
                continuation.resume()
            })
        }
    }

    private func handleControlState(_ newState: NWConnection.State) {
        switch newState {
        case .setup, .preparing:
            controlReady = false
            state = .preparing
        case .ready:
            controlReady = true
            updateReadyState()
        case .waiting(let error):
            controlReady = false
            state = .waiting("Control: \(error.localizedDescription)")
        case .failed(let error):
            controlReady = false
            lastError = error.localizedDescription
            state = .failed("Control: \(error.localizedDescription)")
        case .cancelled:
            controlReady = false
        @unknown default:
            state = .waiting("Unknown control transport state")
        }
    }

    private func handleListenerState(_ newState: NWListener.State) {
        switch newState {
        case .setup:
            listenerReady = false
        case .waiting(let error):
            listenerReady = false
            state = .waiting("Input listener: \(error.localizedDescription)")
        case .ready:
            listenerReady = true
            updateReadyState()
        case .failed(let error):
            listenerReady = false
            lastError = error.localizedDescription
            state = .failed("Input listener: \(error.localizedDescription)")
        case .cancelled:
            listenerReady = false
        @unknown default:
            break
        }
    }

    private func updateReadyState() {
        if controlReady && listenerReady { state = .ready }
    }

    private func acceptInput(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        inputConnections[id] = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            Task { @MainActor in
                guard let self, let connection else { return }
                switch state {
                case .ready:
                    self.receiveNext(on: connection)
                case .failed, .cancelled:
                    self.inputConnections.removeValue(forKey: id)
                default:
                    break
                }
            }
        }
        connection.start(queue: queue)
    }

    private func receiveNext(on connection: NWConnection) {
        connection.receiveMessage { [weak self, weak connection] data, _, _, error in
            Task { @MainActor in
                guard let self, let connection else { return }
                if let data, !data.isEmpty {
                    self.receivedPackets += 1
                    self.emit(.init(
                        timestamp: .now,
                        direction: .inbound,
                        channel: .input,
                        endpoint: self.endpointDescription(connection.endpoint),
                        data: data
                    ))
                }
                if error == nil { self.receiveNext(on: connection) }
            }
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
        case .invalidHost: return "Dash host/broadcast host is empty."
        case .invalidPort: return "A configured UDP port is invalid."
        case .notStarted: return "Dash UDP transport has not been started."
        }
    }
}
