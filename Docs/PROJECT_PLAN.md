# RideDash iOS + Motorcycle Dash Projection

Complete hardware-in-the-loop implementation roadmap

**Primary hardware test target:** Guerrilla 450 with Tripper-style TFT dash owned by the project tester.

> Goal: Build a native iPhone app that can join a compatible motorcycle dash Wi-Fi network, establish a projection session, render navigation off-screen, encode frames as H.264, stream them over RTP/UDP, receive non-safety-critical dash input, and remain robust enough for real rides.

## 1. Product principles

1. Build bottom-up: connectivity before UI polish.
2. Verify every protocol assumption against owned hardware and exact firmware.
3. Keep protocol bytes and networking out of SwiftUI views.
4. Keep safety-critical motorcycle control permanently out of scope.
5. Use public iOS APIs only.
6. Keep manufacturer branding/assets/keys out of the app unless separately authorized.
7. Treat iOS lock-screen/background behavior as an early feasibility gate.

## 2. Scope

### In scope

- Native Swift/SwiftUI application, initially iOS 17+.
- User-approved Wi-Fi joining with `NEHotspotConfigurationManager`.
- Local-network state monitoring using `Network.framework`.
- UDP control/diagnostic transport.
- Typed protocol codec and session state machine.
- Compatible session authentication based on lawful/public interoperability research.
- H.264 encoding using VideoToolbox.
- RTP/H.264 packetization and UDP projection.
- 526×300 off-screen dash renderer as the initial reference viewport.
- CoreLocation + MapKit navigation state.
- Non-safety-critical dash button/joystick input.
- Diagnostics, sanitized packet/session logs and hardware compatibility records.
- Vehicle, garage, expenses, ride history and settings product features.
- Share Extension for route hand-off from map apps.

### Explicitly out of scope

- ECU, throttle, ABS, traction control, brakes, immobilizer, engine commands, or other safety-critical vehicle control.
- Firmware modification, secure-boot bypass, firmware-signing bypass, or exploitation.
- Extraction/redistribution of private manufacturer keys, certificates, proprietary assets or confidential material.
- Any design that hides required speed/fuel/warning information.
- Fake audio or other policy-violating background-execution tricks.

## 3. Definition of done

| Area | Acceptance criterion |
|---|---|
| Connectivity | Cold-start app can guide user to join the dash AP and establish a valid local-network path. |
| Transport | UDP channels open reliably and datagrams can be logged without UI coupling. |
| Authentication | Session handshake succeeds repeatedly without replaying another device's secrets. |
| Projection control | Dash enters/leaves projection mode cleanly. |
| Video | A stable iPhone-generated H.264 calibration stream displays for at least 30 minutes. |
| Input | Known non-safety-critical button events are decoded and mapped to app actions. |
| Navigation | Live route state is projected with position, maneuver, ETA and remaining distance. |
| Recovery | Wi-Fi loss, ignition cycle and session interruption recover cleanly. |
| Thermals | 60-minute ride has acceptable battery/thermal behavior. |
| Background | Supported screen-lock/background behavior is measured and documented per iOS/device. |
| Safety | No safety-critical vehicle command path exists. |

## 4. Architecture

```text
RideDashApp
├── App / SwiftUI
│   ├── Pairing
│   ├── Diagnostics
│   ├── Navigation
│   ├── Projection
│   ├── Vehicles / Garage / Expenses / Rides
│   └── Developer Tools
├── DashConnectivity
│   ├── TripperWiFiManager
│   ├── LocalNetworkMonitor
│   ├── DashEndpointResolver
│   └── DashTransport
├── DashProtocol
│   ├── K1GCodec
│   ├── TLVCodec
│   ├── DashAuthenticator
│   ├── DashSessionStateMachine
│   └── DashInputDecoder
├── ProjectionCore
│   ├── FrameRenderer
│   ├── H264Encoder
│   ├── NALUnitParser
│   ├── RTPPacketizer
│   └── ProjectionStreamer
├── NavigationCore
│   ├── RouteService
│   ├── NavigationState
│   ├── ManeuverMapper
│   └── OfflineRouteCache (later)
├── Diagnostics
│   ├── DiagnosticLog
│   ├── PacketTrace
│   ├── SessionTimeline
│   └── Metrics
└── Persistence / Tests
    ├── SwiftData
    ├── Protocol fixtures
    ├── Golden packet tests
    └── Hardware compatibility matrix
```

## 5. Core boundaries

```swift
protocol DashWiFiJoining {
    func join(ssid: String, passphrase: String) async throws
    func removeConfiguration(forSSID ssid: String) async
}

protocol DashDatagramTransport {
    func start() async throws
    func stop()
    func send(_ data: Data, to port: UInt16) async throws
    var incomingPackets: AsyncStream<DashDatagram> { get }
}

protocol DashAuthenticating {
    func authenticate(session: DashSessionContext) async throws -> AuthenticatedSession
}

protocol FrameRendering {
    var size: CGSize { get }
    func render(_ state: ProjectionUIState) throws -> CVPixelBuffer
}

protocol VideoEncoding {
    func encode(_ pixelBuffer: CVPixelBuffer, pts: CMTime) throws -> [H264NALUnit]
}

protocol RTPPacketizing {
    func packetize(_ nalUnits: [H264NALUnit], timestamp: UInt32) -> [Data]
}
```

## 6. Phase plan

### Phase 0 — Baseline & hardware inventory

- Record bike model, dash firmware, SSID format, iPhone model and iOS version.
- Verify iPhone can manually join the dash Wi-Fi.
- Create `DashTestProfile` so every exported test log contains hardware/firmware metadata.
- Record official-app behavior only on hardware/accounts the tester owns or is authorized to test.

**Gate:** Exact firmware/device metadata captured and manual Wi-Fi join succeeds.

### Phase 1 — iOS Wi-Fi join & local-network diagnostics

- Add Hotspot Configuration capability.
- Implement `TripperWiFiManager` using `NEHotspotConfigurationManager`.
- Add pairing UI for SSID/passphrase and explicit user consent.
- Implement `LocalNetworkMonitor` with `NWPathMonitor`.
- Add configurable dash host (initial hypothesis `192.168.1.1`).
- Add a non-destructive route/socket readiness check.
- Add structured diagnostic timeline and export.

**Gate:** App can request the dash network, observe a viable local path and initialize the diagnostic network stack on the physical iPhone.

### Phase 2 — UDP transport & packet diagnostics

- Implement `DashTransport` with Network.framework UDP.
- Support multiple protocol ports and independent receive paths.
- Hex/structured packet logging with timestamp, direction, endpoint and byte count.
- Sanitized session trace export.
- Deterministic fixture replay for tests.

**Gate:** Bidirectional datagrams can be observed/reproduced without SwiftUI depending on raw protocol bytes.

### Phase 3 — protocol codec & session state machine

- Typed K1G/TLV framing.
- Decode known auth/control/input families.
- State machine: disconnected → Wi-Fi joined → transport ready → authenticating → authenticated → nav-ready → projecting.
- Strict malformed-length/type handling.
- Golden packet tests.

**Gate:** Reference/captured packets decode into typed events and transitions are unit-tested.

### Phase 4 — session authentication

- Parse public-key material exposed by the session handshake where applicable.
- Generate ephemeral session material locally.
- Isolate cryptographic/padding details behind `DashAuthenticator`.
- Explicit auth timeout/retry/failure states.
- Never persist ephemeral secrets.

**Gate:** Ten consecutive cold authentication attempts succeed on the target dash.

### Phase 5 — projection control plane

- Projection-on/off sequencing.
- Required navigation/session metadata.
- Keep-alive/tick handling.
- Firmware capability flags instead of global assumptions.
- Best-effort projection-off cleanup on user stop/disconnect paths.

**Gate:** Dash transitions between normal and projection/navigation modes repeatedly without video.

### Phase 6 — H.264 encoder proof

- Create a 526×300 `CVPixelBuffer` target.
- Low-latency `VTCompressionSession`.
- Start around 4 fps and ~200–250 kbps; keep profile runtime-tunable.
- Extract SPS/PPS and NAL units.
- Local encoder harness before bike transmission.

**Gate:** Stable H.264 elementary stream at target dimensions.

### Phase 7 — RTP/H.264 & first pixels

- RTP sequence/timestamps.
- Single-NAL packets and FU-A fragmentation.
- Send to firmware-validated video endpoint (public references use UDP/5000 as an initial hypothesis).
- First render calibration grid/animation, not maps.
- Capture packets/sec, bitrate, sequence gaps and encode latency.

**Gate:** Physical dash displays iPhone-generated calibration pixels reliably.

### Phase 8 — dash-safe renderer

- Exact target render size.
- Circular-safe-area calibration screen.
- Large glanceable typography/icons/cards/route geometry.
- Same renderer for local preview and projection.
- Snapshot tests.

**Gate:** UI is readable on the actual dash, not merely in Simulator.

### Phase 9 — navigation engine

- CoreLocation live position/heading.
- MapKit route generation initially.
- `NavigationState` independent of MapKit UI.
- Maneuver, distance-to-turn, ETA, remaining distance and route progress.
- Route deviation/recalculation and degraded-GPS state.

**Gate:** On-road projected instructions track the route correctly.

### Phase 10 — dash input

- Listen on firmware-validated input channel (public references use UDP/2002 as an initial hypothesis).
- Decode known LEFT/RIGHT/DOWN/CLICK-style events into semantic `DashInputAction` values.
- Ack where required.
- Debounce repeats and log unknown codes.
- Restrict actions to infotainment/navigation UI.

**Gate:** Known buttons reliably drive projected UI.

### Phase 11 — recovery & ignition cycles

- Detect AP loss, socket failure and session expiry.
- Bounded reconnect with visible state.
- Handle ignition off/on and phone Wi-Fi changes.
- Persist compatibility metadata only, not session secrets.

**Gate:** Repeated ignition cycles recover without reinstall/re-pair.

### Phase 12 — lock-screen/background feasibility

- Test foreground, inactive, dim screen and locked device.
- Measure networking/encoding duration after lock on physical hardware.
- No fake audio/background tricks.
- If full lock streaming is not viable, define a supported foreground/low-brightness operating mode.

**Gate:** Supported operating mode is reproducible and documented by iPhone/iOS version.

### Phase 13 — thermal/battery/network tuning

- 30/60/120-minute tests.
- Measure thermal state and battery drain.
- Cache static frames/regions.
- Tune 4/8/12 fps profiles and bitrate.
- Correlate freezes/blinks/latency with network and encoder metrics.

**Gate:** 60-minute ride completes without sustained thermal warning or projection instability.

### Phase 14 — product integration

- Vehicles, Garage, Expenses, Ride History, Settings.
- Connect/Start Projection product flows.
- Apple Maps/Google Maps Share Extension.
- Ride logging around projection session.
- Maintenance notifications as a separate product module.

**Gate:** Product feels cohesive rather than a protocol demo.

### Phase 15 — compatibility & release hardening

- Firmware/device capability records.
- Unit tests, renderer tests and hardware smoke checklist.
- Privacy manifest/permission text.
- License/NOTICE and trademark review.
- Distribution decision only after policy/legal/stability review.

**Gate:** Tagged beta with reproducible hardware results and no safety-critical coupling.

## 7. First hardware session

The first bike session intentionally stops before authentication/video.

1. Record dash firmware and iPhone/iOS version.
2. Enable the dash Wi-Fi/AP using the bike's normal user flow.
3. Record the displayed SSID; do not assume another bike's SSID.
4. Join manually in iOS Settings once.
5. Launch RideDash and grant Local Network permission when prompted.
6. Use the Diagnostics screen to request the Wi-Fi join configuration.
7. Observe path/interface changes.
8. Initialize the UDP diagnostic stack only after the bike is stationary.
9. Record state transitions/errors.
10. Power-cycle the bike and repeat three times.
11. Export a sanitized diagnostic log.

## 8. Hardware test matrix

| Test | Pass condition | Result |
|---|---|---|
| Manual Wi-Fi join | iPhone joins expected local subnet | |
| In-app join | User-approved join succeeds | |
| Local Network permission | App can initialize local networking | |
| UDP transport | Socket state reaches ready | |
| Dash datagram | At least one expected dash-originated datagram is captured once Phase 2 probes are defined | |
| Authentication | 10/10 cold attempts | |
| Enter projection | Dash transitions to navigation/projection | |
| Projection off | Dash returns cleanly | |
| Calibration grid | Correctly framed on physical dash | |
| 4 fps | 30 min stable | |
| 8 fps | Stable or documented unsupported | |
| 12 fps | Stable or documented unsupported | |
| Dash buttons | Known navigation inputs decoded | |
| Ignition cycle | Reconnect succeeds | |
| Phone lock | Behavior measured/documented | |
| 60-minute ride | Thermal/battery/network acceptable | |

## 9. Diagnostics requirements

Before UI polish, log:

- Wi-Fi request/join/remove events.
- `NWPath` status and active interfaces.
- Transport state transitions.
- Packet timestamp, direction, endpoint and byte count.
- Sanitized hex prefix for protocol debugging.
- Session-state transitions.
- Encoder FPS, bytes/sec, keyframes and latency.
- RTP sequence/packets/sec/fragmentation/send errors.
- Thermal state and battery level/state.
- GPS accuracy/heading accuracy/recalculation count.

Diagnostic export must exclude private keys and detailed location history by default.

## 10. Suggested repository structure

```text
RideDash/
├── RideDash.xcodeproj/
├── RideDash/
│   ├── App/
│   ├── Features/
│   │   ├── Pairing/
│   │   ├── Diagnostics/
│   │   ├── Projection/
│   │   ├── Navigation/
│   │   ├── Vehicles/
│   │   ├── Garage/
│   │   ├── Expenses/
│   │   └── Rides/
│   ├── DashConnectivity/
│   ├── DashProtocol/
│   ├── ProjectionCore/
│   ├── NavigationCore/
│   ├── Diagnostics/
│   ├── Models/
│   ├── Services/
│   └── Resources/
├── RideDashTests/
├── Docs/
│   ├── PROJECT_PLAN.md
│   ├── HARDWARE_TEST_MATRIX.md
│   ├── PROTOCOL_NOTES.md
│   └── SAFETY_SCOPE.md
└── NOTICE
```

## 11. Build order

1. Wi-Fi join
2. Local-network monitor
3. UDP transport
4. Packet logger
5. Protocol codec
6. Authentication
7. Projection control plane
8. H.264 encoder
9. RTP packetizer
10. Calibration stream on physical dash
11. Renderer
12. Live navigation
13. Dash input
14. Session recovery
15. Lock/background feasibility
16. Thermal/battery tuning
17. Product integration
18. Compatibility/beta hardening

## 12. Phase 1 acceptance checklist

- [ ] Project builds on a physical iPhone.
- [ ] Diagnostics screen displays current `DashTestProfile`.
- [ ] User can request joining an entered dash SSID/passphrase.
- [ ] Native iOS approval/error is surfaced clearly.
- [ ] App reports current `NWPath` status/interfaces.
- [ ] Configurable dash host defaults to the current research hypothesis but is editable.
- [ ] UDP diagnostic connection can be initialized/stopped without crash.
- [ ] Structured state transitions appear in the diagnostic log.
- [ ] Diagnostic log can be exported through the share sheet.
- [ ] Three bike power-cycle attempts are recorded.
- [ ] Authentication/projection/video remains disabled until Phase 1 hardware gate passes.

## 13. Immediate next test information needed

To close Phase 0 and validate Phase 1 on the physical bike, record:

- Dash firmware version
- Dash Wi-Fi SSID shown by the bike
- Whether the AP requires a password, and how the user obtains it
- iPhone model
- iOS version
- Whether manual iPhone join succeeds
- IP/subnet observed after manual join, if visible

Do **not** commit real Wi-Fi credentials or private device/session secrets to the repository.
