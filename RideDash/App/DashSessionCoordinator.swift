import Combine
import Foundation

@MainActor
final class DashSessionCoordinator: ObservableObject {
    enum State: Equatable {
        case disconnected
        case startingTransport
        case requestingAuthentication
        case awaitingPublicKey
        case sendingSessionKey
        case authenticated
        case enteringNavigation
        case navigationReady
        case projecting
        case stopping
        case failed(String)

        var label: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .startingTransport: return "Starting transport"
            case .requestingAuthentication: return "Requesting authentication"
            case .awaitingPublicKey: return "Waiting for dash public key"
            case .sendingSessionKey: return "Sending encrypted session key"
            case .authenticated: return "Authenticated"
            case .enteringNavigation: return "Entering navigation"
            case .navigationReady: return "Navigation ready"
            case .projecting: return "Projecting"
            case .stopping: return "Stopping"
            case .failed(let message): return "Failed: \(message)"
            }
        }
    }

    @Published private(set) var state: State = .disconnected
    @Published private(set) var lastButton: DashButton?
    @Published private(set) var authenticatedSession: DashAuthenticatedSession?
    @Published var routeTitle: String = "Navigation"

    let transport: DashTransport
    let log: DiagnosticLog

    var onButton: ((DashButton) -> Void)?
    var onAuthenticated: (() -> Void)?

    private var profile = DashProtocolProfile.publicReference
    private var ssid = ""
    private var hostname = "iPhone"
    private var sequence: UInt8 = 0
    private var modulus: Data?
    private var exponent: Data?
    private var authTimeoutTask: Task<Void, Never>?
    private var projectionHeartbeatTask: Task<Void, Never>?
    private var routeHeartbeatTask: Task<Void, Never>?
    private var navEntered = false

    init(transport: DashTransport = DashTransport(), log: DiagnosticLog = DiagnosticLog()) {
        self.transport = transport
        self.log = log
        transport.onDatagram = { [weak self] datagram in
            Task { @MainActor in self?.handle(datagram) }
        }
    }

    func connect(
        ssid: String,
        hostname: String,
        profile: DashProtocolProfile = .publicReference,
        authTimeout: Duration = .seconds(8)
    ) async {
        disconnect()
        self.ssid = ssid
        self.hostname = hostname.isEmpty ? "iPhone" : hostname
        self.profile = profile
        sequence = 0
        modulus = nil
        exponent = nil
        authenticatedSession = nil
        navEntered = false

        do {
            state = .startingTransport
            try transport.start(profile: profile)
            log.append("Control/input/video UDP transport requested", category: "session")

            // Network.framework is asynchronous. A short preparation window prevents
            // the first burst from racing listener setup on normal device hardware.
            try await Task.sleep(for: .milliseconds(250))
            try Task.checkCancellation()

            state = .requestingAuthentication
            try await sendInitialBurst()
            state = .awaitingPublicKey
            log.append("Initial K1G burst sent; awaiting RSA public key", category: "auth")

            authTimeoutTask?.cancel()
            authTimeoutTask = Task { [weak self] in
                try? await Task.sleep(for: authTimeout)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self else { return }
                    if self.authenticatedSession == nil {
                        self.state = .failed("Authentication timed out")
                        self.log.append("Authentication timeout", category: "auth", level: .error)
                    }
                }
            }
        } catch {
            state = .failed(error.localizedDescription)
            log.append(error.localizedDescription, category: "session", level: .error)
        }
    }

    func enterNavigation(title: String? = nil) async throws {
        guard authenticatedSession != nil else { throw DashSessionError.notAuthenticated }
        if let title, !title.isEmpty { routeTitle = title }

        state = .enteringNavigation
        try await sendHex(K1GCodec.navContextHex)
        try await sendHex(K1GCodec.emptyListsHex)

        for index in 0..<4 {
            try await sendRaw(K1GCodec.routeCard(title: routeTitle, projectionOn: index == 3))
            if index < 3 { try await Task.sleep(for: .milliseconds(350)) }
        }

        try await sendHex(K1GCodec.projectionFrameHex)
        try await sendHex(K1GCodec.projectionOnHex)
        try await sendHex(K1GCodec.startNavigationHex)
        try await sendRaw(K1GCodec.routeCard(title: routeTitle, projectionOn: true))

        navEntered = true
        state = .navigationReady
        startRouteHeartbeat()
        log.append("Navigation control plane entered", category: "session")
    }

    func beginProjectionHeartbeat() {
        guard navEntered else { return }
        projectionHeartbeatTask?.cancel()
        let fps = max(1, profile.fps)
        projectionHeartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    try await self.sendHex(K1GCodec.projectionFrameHex)
                } catch {
                    self.log.append(error.localizedDescription, category: "projection", level: .error)
                }
                try? await Task.sleep(for: .seconds(1.0 / Double(fps)))
            }
        }
        state = .projecting
    }

    func stopProjection() async {
        projectionHeartbeatTask?.cancel()
        projectionHeartbeatTask = nil
        guard navEntered else { return }
        state = .stopping
        do {
            try await sendHex(K1GCodec.projectionStopHex)
            try await sendHex(K1GCodec.projectionOffHex)
            state = .authenticated
            log.append("Projection-off sequence sent", category: "projection")
        } catch {
            state = .failed(error.localizedDescription)
        }
        navEntered = false
    }

    func disconnect() {
        authTimeoutTask?.cancel()
        projectionHeartbeatTask?.cancel()
        routeHeartbeatTask?.cancel()
        authTimeoutTask = nil
        projectionHeartbeatTask = nil
        routeHeartbeatTask = nil
        transport.stop()
        navEntered = false
        authenticatedSession = nil
        modulus = nil
        exponent = nil
        state = .disconnected
    }

    // MARK: - RX

    private func handle(_ datagram: DashDatagram) {
        if datagram.direction == .inbound {
            log.append(
                "RX \(datagram.data.count)B \(HexCodec.string(datagram.data, maxBytes: 24))",
                category: "packet"
            )
        }

        for event in DashEventDecoder.events(from: datagram.data) {
            switch event {
            case .rsaModulus(let data):
                modulus = data
                log.append("RSA modulus received (\(data.count)B)", category: "auth")
                attemptSessionKeyIfReady()
            case .rsaExponent(let data):
                exponent = data
                log.append("RSA exponent received: \(HexCodec.string(data))", category: "auth")
                attemptSessionKeyIfReady()
            case .authAccepted:
                authTimeoutTask?.cancel()
                state = .authenticated
                log.append("Dash authentication accepted", category: "auth")
                onAuthenticated?()
            case .authRejected(let status):
                authenticatedSession = nil
                modulus = nil
                exponent = nil
                state = .requestingAuthentication
                log.append("Dash authentication rejected status=0x\(String(format: "%02X", status))", category: "auth", level: .error)
                Task { [weak self] in
                    guard let self else { return }
                    try? await self.sendHex(K1GCodec.requestAuthHex)
                    self.state = .awaitingPublicKey
                }
            case .button(let button):
                lastButton = button
                log.append("Dash input: \(String(describing: button))", category: "input")
                onButton?(button)
                if profile.respondToInput {
                    Task { [weak self] in
                        guard let self else { return }
                        if let ack = try? K1GCodec.buttonAck(button.rawValue) {
                            try? await self.sendRaw(ack)
                        }
                    }
                }
            case .segment(let segment):
                if segment.type != 0x05 && segment.type != 0x06 {
                    log.append("Unknown segment \(segment.hex.prefix(80))", category: "protocol")
                }
            }
        }
    }

    private func attemptSessionKeyIfReady() {
        guard authenticatedSession == nil,
              let modulus,
              let exponent,
              !ssid.isEmpty else { return }

        state = .sendingSessionKey
        Task { [weak self] in
            guard let self else { return }
            do {
                let aesKey = try DashAuthenticator.randomAES256Key()
                let ciphertext = try DashAuthenticator.encryptedSessionPayload(
                    ssid: self.ssid,
                    modulus: modulus,
                    exponent: exponent,
                    aesKey: aesKey
                )
                let packet = try K1GCodec.buildSessionKeyPacket(ciphertext: ciphertext)
                try await self.sendRaw(packet)
                self.authenticatedSession = DashAuthenticatedSession(aesKey: aesKey)
                self.log.append("Encrypted AES session key sent", category: "auth")
            } catch {
                self.state = .failed(error.localizedDescription)
                self.log.append(error.localizedDescription, category: "auth", level: .error)
            }
        }
    }

    // MARK: - TX

    private func sendInitialBurst() async throws {
        for entry in K1GCodec.initialBurst {
            let packet: Data
            if let entry {
                packet = try HexCodec.data(from: entry)
            } else {
                packet = K1GCodec.hostnameAnnounce(hostname)
            }
            try await sendRaw(packet)
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    private func sendHex(_ hex: String) async throws {
        try await sendRaw(HexCodec.data(from: hex))
    }

    private func sendRaw(_ packet: Data) async throws {
        let patched = try K1GCodec.patchSequence(packet, sequence: sequence)
        sequence &+= 1
        try await transport.sendControl(patched)
    }

    private func startRouteHeartbeat() {
        routeHeartbeatTask?.cancel()
        routeHeartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    try await self.sendRaw(K1GCodec.routeCard(title: self.routeTitle, projectionOn: true))
                } catch {
                    self.log.append(error.localizedDescription, category: "heartbeat", level: .error)
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

enum DashSessionError: LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Authenticate with the dash before entering navigation mode."
        }
    }
}
