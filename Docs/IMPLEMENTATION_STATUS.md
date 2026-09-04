# RideDash Implementation Status

RideDash is **code-complete for the planned first hardware beta**. Final validation is intentionally manual on a physical iPhone and the user's owned motorcycle display; there is no CI/CD workflow in this repository.

## iOS product

- [x] Native SwiftUI application targeting iOS 17+
- [x] SwiftData local-first persistence
- [x] Vehicle profiles and active vehicle
- [x] Garage / maintenance history
- [x] Fuel logs and full-tank mileage calculation
- [x] Expense tracking and CSV export
- [x] Ride history
- [x] MapKit route calculation and preview
- [x] CoreLocation live navigation state
- [x] Apple Maps hand-off
- [x] `ridedash://` route deep links
- [x] Share Extension for shared map URLs/text
- [x] Currency / distance preferences

## Display interoperability stack

- [x] Hotspot Configuration entitlement
- [x] User-approved in-app Wi-Fi join request
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
- [x] Manual stop/disconnect recovery paths
- [x] Configurable host/broadcast/ports/FPS/bitrate

## Hardware validation still required

The code intentionally keeps firmware-sensitive assumptions configurable. The following cannot be truthfully marked complete until the physical test:

- [ ] Exact target-firmware endpoint/port validation
- [ ] Authentication success across three cold ignition cycles
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
