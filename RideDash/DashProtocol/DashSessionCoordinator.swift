import Combine
import Foundation

@MainActor
final class DashSessionCoordinator: ObservableObject {
    @Published private(set) var state: DashSessionState = .disconnected
    @Published private(set) var timeline: [DashSessionTimelineEntry] = []
    @Published private(set) var lastError: String?
    @Published private(set) var lastInput: DashInputAction?
    @Published private(set) var metrics = DashSessionMetrics()

    let transport: DashDatagramTransport
    let configuration: DashProtocolConfiguration
    let streamer: ProjectionStreamer

    private let policy: DashSessionPolicy
    private let authenticator: DashAuthenticator
    private var inputTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var routeCard = RouteCard(title: "RideDash")
    private var navigationInstruction = DashNavigationInstruction(
        maneuver: .continueStraight,
        distanceToTurnMeters: 0,
        remainingDistanceMeters: 0,
        roadName: "Ready"
    )

    init(
        configuration: DashProtocolConfiguration = .default,
        policy: DashSessionPolicy = .init()
    ) {
        self.configuration = configuration
        self.policy = policy
        transport = DashDatagramTransport()
        authenticator = DashAuthenticator(timeout: policy.authenticationTimeout)
        streamer = ProjectionStreamer(transport: transport, configuration: configuration)
    }

    func connect(ssid: String) async {
        await disconnect()
        do {
            transition(.transportReady, "Starting UDP control/input transport")
            try transport.start(configuration: configuration)
            metrics.connectedAt = .now

            transition(.authenticating, "Requesting dash session authentication")
            _ = try await authenticator.authenticate(ssid: ssid, transport: transport)
            metrics.authenticatedAt = .now
            transition(.authenticated, "Session authentication accepted")

            startInputLoop()
            try await enterNavigationMode()
            transition(.navigationReady, "Dash navigation control plane initialized")
        } catch {
            fail(error)
        }
    }

    func startProjection(stateProvider: @escaping () -> ProjectionUIState) async {
        guard state == .navigationReady || state == .projecting else {
            fail(DashProtocolError.projectionNotReady)
            return
        }
        do {
            try await sendProjectionOnSequence()
            try streamer.start(stateProvider: stateProvider)
            metrics.projectionStartedAt = .now
            transition(.projecting, "H.264/RTP projection started")
            startHeartbeatLoop()
        } catch {
            fail(error)
        }
    }

    func updateNavigation(_ state: ProjectionUIState) {
        routeCard = RouteCard(
            title: state.roadName.isEmpty ? configuration.routeTitle : state.roadName,
            remainingDistanceMeters: state.remainingDistanceMeters,
            projectionOn: true
        )
        navigationInstruction = DashNavigationInstruction(
            maneuver: state.maneuver,
            distanceToTurnMeters: state.distanceToTurnMeters,
            remainingDistanceMeters: state.remainingDistanceMeters,
            roadName: state.roadName
        )
    }

    func stopProjection() async {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        streamer.stop()
        do {
            try await transport.sendControl(ProjectionControlPackets.projectionStop())
            try await transport.sendControl(ProjectionControlPackets.projectionOff())
        } catch {
            lastError = error.localizedDescription
        }
        if state == .projecting { transition(.navigationReady, "Projection stopped") }
    }

    func disconnect() async {
        if state == .projecting || state == .navigationReady {
            await stopProjection()
        }
        inputTask?.cancel()
        inputTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        transport.stop()
        metrics = DashSessionMetrics()
        transition(.disconnected, "Session disconnected")
    }

    private func enterNavigationMode() async throws {
        try await transport.sendControl(ProjectionControlPackets.navigationContext())
        try await transport.sendControl(ProjectionControlPackets.emptyNavigationLists())
        // Route/nav payload builders are intentionally isolated because their inner layout
        // is the most firmware-sensitive part of the public interoperability research.
        try await transport.sendControl(DashPacketBuilder.routeCard(routeCard))
        try await transport.sendControl(ProjectionControlPackets.projectionFrame())
        try await transport.sendControl(ProjectionControlPackets.projectionOn())
        try await transport.sendControl(ProjectionControlPackets.startNavigation())
    }

    private func sendProjectionOnSequence() async throws {
        try await transport.sendControl(ProjectionControlPackets.projectionFrame())
        try await transport.sendControl(ProjectionControlPackets.projectionOn())
        try await transport.sendControl(ProjectionControlPackets.startNavigation())
    }

    private func startInputLoop() {
        inputTask?.cancel()
        inputTask = Task { [weak self] in
            guard let self else { return }
            for await datagram in self.transport.incomingPackets {
                guard !Task.isCancelled else { break }
                self.metrics.inboundPackets += datagram.direction == .inbound ? 1 : 0
                self.metrics.outboundPackets += datagram.direction == .outbound ? 1 : 0
                guard datagram.direction == .inbound,
                      let event = DashInputDecoder.decode(datagram.payload) else { continue }
                self.lastInput = event.action
                self.timeline.append(
                    DashSessionTimelineEntry(state: self.state, message: "Dash input: \(event.action.rawValue)")
                )
                if let ack = try? DashInputDecoder.acknowledgement(for: event) {
                    try? await self.transport.sendControl(ack)
                }
            }
        }
    }

    private func startHeartbeatLoop() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            guard let self else { return }
            var projectionTick = 0
            while !Task.isCancelled, self.state == .projecting {
                do {
                    try await self.transport.sendControl(ProjectionControlPackets.projectionFrame())
                    projectionTick += 1

                    let ticksPerSecond = max(1, Int(self.policy.projectionHeartbeatHz.rounded()))
                    if projectionTick.isMultiple(of: ticksPerSecond) {
                        try await self.transport.sendControl(DashPacketBuilder.routeCard(self.routeCard))
                        try await self.transport.sendControl(DashPacketBuilder.navigationInfo(self.navigationInstruction))
                    }
                } catch {
                    self.lastError = error.localizedDescription
                }

                let hz = max(1, self.policy.projectionHeartbeatHz)
                try? await Task.sleep(for: .seconds(1.0 / hz))
            }
        }
    }

    private func transition(_ newState: DashSessionState, _ message: String) {
        state = newState
        timeline.append(DashSessionTimelineEntry(state: newState, message: message))
        if timeline.count > 200 { timeline.removeFirst(timeline.count - 200) }
    }

    private func fail(_ error: Error) {
        lastError = error.localizedDescription
        transition(.failed, error.localizedDescription)
    }
}
