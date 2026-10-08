# RideDash Implementation Status

RideDash is **code-complete for the planned first hardware beta**. Final validation is intentionally manual on a physical iPhone and the user's owned motorcycle display; there is no CI/CD workflow in this repository.

## iOS product

- [x] Native SwiftUI application targeting iOS 17+
- [x] SwiftData local-first persistence
- [x] Vehicle profiles and active vehicle
- [x] Garage / maintenance history
- [x] Fuel logs and full-tank mileage calculation
- [x] Expense tracking and CSV export
- [x] Manual ride history
- [x] Automatic ride recording during projection sessions
- [x] Maintenance next-due km/date tracking
- [x] Local maintenance due-date notifications
- [x] MapKit route calculation and preview
- [x] CoreLocation live navigation state
- [x] Off-route detection and cooldown-protected route recalculation
- [x] Remaining-distance / ETA updates
- [x] Apple Maps hand-off
- [x] `ridedash://` route deep links
- [x] Share Extension for shared map URLs/text
- [x] Currency / distance preferences
- [x] Persisted background-navigation behavior

## Display interoperability stack

- [x] Hotspot Configuration entitlement
- [x] User-approved in-app Wi-Fi join request
- [x] App-managed Wi-Fi configuration
- [x] Local network path monitoring
- [x] UDP control channel bound to the configured control source port
- [x] UDP input listener
- [x] UDP video channel
- [x] Sanitized packet/session diagnostic logging
- [x] Hardware test profile
- [x] K1G/TLV framing and rolling sequence patching
- [x] Dynamic dash-provided RSA public-key parsing
- [x] New ephemeral 32-byte AES-256 session key per authentication attempt
- [x] RSA PKCS#1 v1.5 session authentication
- [x] Auth timeout and rejection handling
- [x] Bounded exponential automatic reconnect
- [x] Navigation-mode restoration after reconnect
- [x] Repeated UDP-send failure recovery
- [x] Projection/navigation-mode enter/exit sequencing
- [x] Route-card keep-alive
- [x] Active nav-info keep-alive
- [x] 1 Hz metadata/status heartbeat
- [x] Projection frame heartbeat
- [x] 526×300 off-screen renderer
- [x] Calibration grid mode
- [x] VideoToolbox low-latency H.264 Baseline encoder
- [x] SPS/PPS extraction
- [x] RTP payload type 96 packetization
- [x] FU-A fragmentation for oversized NAL units
- [x] UDP H.264/RTP streaming
- [x] Known RIGHT / LEFT / DOWN / CLICK input decoding
- [x] Input acknowledgement flow
- [x] Input debounce for repeated events
- [x] Manual stop/disconnect recovery paths
- [x] Configurable host/broadcast/ports/FPS/bitrate

## Diagnostics / release hygiene

- [x] Thermal-state monitoring
- [x] Battery level/state monitoring
- [x] Low Power Mode monitoring
- [x] In-app deterministic K1G/RTP/FU-A self-check (no network traffic)
- [x] Sanitized diagnostics export
- [x] Privacy manifest bundled in the app target
- [x] UserDefaults required-reason declaration (`CA92.1`)
- [x] Independent-project / interoperability NOTICE
- [x] Safety boundary documented in code and docs

## Open-source testing preview — 8 October 2026

- [x] Apache-2.0 license and preserved interoperability attribution
- [x] Tester guide and GitHub bug/test-result/feature issue forms
- [x] Unsigned Simulator Debug and iPhone Release compile on Xcode 27
- [x] Optional, off-by-default TelemetryDeck screen analytics and privacy disclosure
- [x] Standalone analytics contract checks (no external traffic)
- [x] Synthetic test-mode ingestion accepted with HTTP 200
- [ ] Physical-device analytics/consent verification

See [validation details](VALIDATION.md). This remains build-from-source only; no packaged release is produced.

## Hardware validation still required

The code intentionally keeps firmware-sensitive assumptions configurable. The following cannot be truthfully marked complete until the physical test:

- [ ] Xcode compile/sign/install on the target iPhone
- [ ] Exact target-firmware endpoint/port validation
- [ ] Authentication success across cold ignition cycles
- [ ] Navigation-mode transition on the physical dash
- [ ] Calibration grid visible on the physical dash
- [ ] Stable 4 fps H.264/RTP stream for 30 minutes
- [ ] LEFT / RIGHT / DOWN / CLICK verified on the target controls
- [ ] Ignition-cycle reconnect behavior measured
- [ ] Locked-screen/background behavior measured on the target iPhone/iOS version
- [ ] 60-minute thermal/battery/network ride test

Follow [`MANUAL_TEST_GUIDE.md`](MANUAL_TEST_GUIDE.md) in order. Do not skip directly to video projection on the first hardware session.

## Validation policy

No GitHub Actions or CI/CD workflow is used. The first final integration build is compiled, signed and installed manually in Xcode. Unknown protocol families remain read-only, and RideDash permanently excludes ECU, throttle, brakes, ABS, traction control, immobilizer, engine control and other safety-critical vehicle commands.
