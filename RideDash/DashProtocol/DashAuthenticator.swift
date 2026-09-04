import Foundation

struct AuthenticatedDashSession: Sendable {
    let establishedAt: Date
    let sessionKey: Data
}

struct DashAuthenticator: Sendable {
    let timeout: TimeInterval

    init(timeout: TimeInterval = 8) {
        self.timeout = timeout
    }

    func authenticate(
        ssid: String,
        transport: DashDatagramTransport
    ) async throws -> AuthenticatedDashSession {
        try await withThrowingTaskGroup(of: AuthenticatedDashSession.self) { group in
            group.addTask {
                try await authenticateFlow(ssid: ssid, transport: transport)
            }
            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
                throw DashProtocolError.authenticationTimeout
            }

            guard let first = try await group.next() else {
                throw DashProtocolError.authenticationTimeout
            }
            group.cancelAll()
            return first
        }
    }

    private func authenticateFlow(
        ssid: String,
        transport: DashDatagramTransport
    ) async throws -> AuthenticatedDashSession {
        let sessionKey = try RandomSessionKey.generate()
        try await transport.sendControl(ProjectionControlPackets.authenticationRequest())

        var keyMaterial = DashPublicKeyMaterial()
        var encryptedKeySent = false

        for await datagram in transport.incomingPackets {
            guard datagram.direction == .inbound,
                  let event = DashAuthenticationResponseParser.parse(datagram.payload) else {
                continue
            }

            switch event {
            case .modulus(let modulus):
                keyMaterial.modulus = modulus
            case .exponent(let exponent):
                keyMaterial.exponent = exponent
            case .authenticated:
                return AuthenticatedDashSession(establishedAt: .now, sessionKey: sessionKey)
            case .rejected:
                throw DashProtocolError.authenticationRejected
            }

            if keyMaterial.isComplete,
               !encryptedKeySent,
               let modulus = keyMaterial.modulus,
               let exponent = keyMaterial.exponent {
                let packet = try DashAuthenticationPacketBuilder.makeEncryptedSessionPacket(
                    ssid: ssid,
                    sessionKey: sessionKey,
                    modulus: modulus,
                    exponent: exponent
                )
                try await transport.sendControl(packet)
                encryptedKeySent = true
            }
        }

        throw DashProtocolError.authenticationTimeout
    }
}
