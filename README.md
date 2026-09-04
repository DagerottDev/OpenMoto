# RideDash

RideDash is a native iOS motorcycle navigation and ride companion with an experimental interoperability layer for compatible Wi-Fi motorcycle displays.

The app is intentionally brand-neutral and limits display integration to infotainment/navigation. It does **not** implement ECU, throttle, brakes, ABS, traction control, immobilizer, firmware modification, or other safety-critical vehicle control.

## Implemented

### iOS product
- SwiftUI app targeting iOS 17+
- SwiftData local-first persistence
- Vehicle profiles and active-vehicle selection
- Garage / maintenance history
- Fuel logs and full-tank mileage calculation
- Expense tracking and CSV export
- Ride history
- MapKit route search/preview
- CoreLocation live navigation state
- Apple Maps hand-off
- `ridedash://route?url=...` deep-link route intake
- Share Extension for URL/text hand-off from Maps and other apps
- Currency and distance preferences

### Compatible display stack
- User-approved Wi-Fi joining with `NEHotspotConfigurationManager`
- Local-network monitoring
- UDP control transport plus input listener
- K1G/TLV framing and sequence handling
- Dash-provided RSA public-key parsing
- Ephemeral 32-byte AES session generation
- RSA PKCS#1 v1.5 session authentication flow
- Projection/navigation-mode on/off sequencing
- 526×300 off-screen renderer
- VideoToolbox low-latency H.264 Baseline encoding
- RTP payload type 96, single-NAL and FU-A packetization
- SPS/PPS + IDR bundling matching the public interoperability reference
- UDP video streaming to a configurable endpoint
- Known non-safety-critical dash input decoding (LEFT/RIGHT/DOWN/CLICK reference values)
- Input acknowledgements
- Session/projection keep-alives
- Sanitized diagnostics and manual hardware profile logging

## Status

The implementation is **code-complete for the planned first hardware beta, but not hardware-validated yet**. No CI/CD pipeline is used for this project by design. The final validation step is a manual build/run on a physical iPhone and a user-owned motorcycle display.

Protocol defaults in the app are research defaults and remain editable:

- dash host: `192.168.1.1`
- control broadcast: `192.168.1.255`
- control UDP: `2000`
- input UDP: `2002`
- RTP/H.264 UDP: `5000`
- initial display viewport: `526×300`
- initial projection profile: `4 fps`, `250 kbps`

Do not assume these values apply to every firmware. Record the exact firmware in Diagnostics before changing protocol behavior.

## Manual test

Read [`Docs/MANUAL_TEST_GUIDE.md`](Docs/MANUAL_TEST_GUIDE.md) before the first physical-device test. Start with the motorcycle stationary and the display in its normal user mode.

## Documentation

- [`Docs/PROJECT_PLAN.md`](Docs/PROJECT_PLAN.md) — complete architecture/roadmap
- [`Docs/PROTOCOL_NOTES.md`](Docs/PROTOCOL_NOTES.md) — protocol assumptions and public-reference mapping
- [`Docs/MANUAL_TEST_GUIDE.md`](Docs/MANUAL_TEST_GUIDE.md) — first end-to-end hardware test
- [`Docs/HARDWARE_TEST_MATRIX.md`](Docs/HARDWARE_TEST_MATRIX.md) — results matrix
- [`Docs/SAFETY_SCOPE.md`](Docs/SAFETY_SCOPE.md) — permanent safety boundary

## Build

1. Clone the repository.
2. Open `RideDash.xcodeproj` in Xcode 16 or newer.
3. Select your Apple Development team for both **RideDash** and **RideDashShare**.
4. Change bundle identifiers if your developer account requires different identifiers.
5. Confirm the **Hotspot Configuration** capability is available for the RideDash target.
6. Run on a physical iPhone. Wi-Fi accessory behavior and actual projection cannot be validated in Simulator.

## Important limitations

- iOS background location is enabled only for legitimate active navigation. It does not guarantee that VideoToolbox/UDP projection will keep running indefinitely after the device is locked; this must be measured on the target iPhone/iOS version.
- MapKit route calculation generally needs internet access. Calculate/cache the route before switching to a display Wi-Fi network that has no internet.
- The display protocol can vary with firmware. Keep unknown packet families read-only until understood.
- Do not test new protocol behavior while the motorcycle is moving.
