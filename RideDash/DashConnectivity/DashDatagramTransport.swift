import Foundation
import Network

final class DashDatagramTransport: @unchecked Sendable {
    let incomingPackets: AsyncStream<DashDatagram>

    private let queue = DispatchQueue(label: "dev.dagerott.RideDash.datagrams")
    private var continuation: AsyncStream<DashDatagram>.Continuation?
    private var listener: NWListener?
    private var connections: [String: NWConnection] = [:]
    private var configuration: DashProtocolConfiguration = .default

    init() {
        var captured: AsyncStream<DashDatagram>.Continuation?
        incomingPackets = AsyncStream { captured = $0 }
        continuation = captured
    }

    deinit {
        stop()
        continuation?.finish()
    }

    func start(configuration: DashProtocolConfiguration) throws {
        stop()
        self.configuration = configuration

        guard let inputPort = NWEndpoint.Port(rawValue: configuration.inputPort) else {
            throw DashTransportError.invalidPort
        }

        let listener = try NWListener(using: .udp, on: inputPort)
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            connection.start(queue: self.queue)
            self.receiveNext(on: connection)
        }
        listener.start(queue: queue)
        self.listener = listener

        // Pre-create the control channel. UDP send is still lazy and can queue while preparing.
        _ = channel(
            host: configuration.broadcastHost,
            port: configuration.controlPort,
            localPort: configuration.controlPort
        )
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for connection in connections.values { connection.cancel() }
        connections.removeAll()
    }

    func sendControl(_ data: Data) async throws {
        try await send(
            data,
            host: configuration.broadcastHost,
            port: configuration.controlPort,
            localPort: configuration.controlPort
        )
    }

    func sendVideo(_ data: Data) async throws {
        try await send(
            data,
            host: configuration.dashHost,
            port: configuration.videoPort,
            localPort: nil
        )
    }

    func send(
        _ data: Data,
        host: String,
        port: UInt16,
        localPort: UInt16? = nil
    ) async throws {
        guard let remotePort = NWEndpoint.Port(rawValue: port) else {
            throw DashTransportError.invalidPort
        }
        let connection = channel(host: host, port: port, localPort: localPort)

        try await withCheckedThrowingContinuation { (checked: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { [weak self] error in
                if let error {
                    checked.resume(throwing: error)
                    return
                }
                self?.continuation?.yield(
                    DashDatagram(
                        direction: .outbound,
                        host: host,
                        port: remotePort.rawValue,
                        payload: data
                    )
                )
                checked.resume()
            })
        }
    }

    private func channel(host: String, port: UInt16, localPort: UInt16?) -> NWConnection {
        let key = "\(host):\(port):\(localPort ?? 0)"
        if let existing = connections[key] { return existing }

        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        if let localPort, let sourcePort = NWEndpoint.Port(rawValue: localPort) {
            parameters.requiredLocalEndpoint = .hostPort(
                host: NWEndpoint.Host("0.0.0.0"),
                port: sourcePort
            )
        }

        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: parameters
        )
        connection.start(queue: queue)
        connections[key] = connection
        return connection
    }

    private func receiveNext(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                var host = "unknown"
                var port: UInt16 = 0
                if case let .hostPort(remoteHost, remotePort) = connection.endpoint {
                    host = String(describing: remoteHost)
                    port = remotePort.rawValue
                }
                self.continuation?.yield(
                    DashDatagram(
                        direction: .inbound,
                        host: host,
                        port: port,
                        payload: data
                    )
                )
            }
            if error == nil { self.receiveNext(on: connection) }
        }
    }
}
