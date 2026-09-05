# RideDash iOS + Motorcycle Dash Projection

Complete hardware-in-the-loop implementation roadmap and current beta status.

**Primary hardware test target:** Guerrilla 450 with Tripper-style TFT dash owned by the project tester.

> Goal: Build a native iPhone app that can join a compatible motorcycle dash Wi-Fi network, establish an authenticated projection session, render navigation off-screen, encode frames as H.264, stream them over RTP/UDP, receive non-safety-critical dash input, recover from connection loss, and remain robust enough for real rides.

## 1. Current status

RideDash is **code-complete for the planned first hardware beta**. No CI/CD pipeline is used. The remaining work is physical Xcode build/sign/install plus real-device and motorcycle-dash validation.

### Implemented in code

- Native SwiftUI app targeting iOS 17+.
- SwiftData local-first persistence.
- Vehicles, Garage, Fuel, Expenses, Maintenance, Rides and Settings.
- Manual and automatic ride recording during projection sessions.
- Maintenance next-due km/date tracking and local notifications.
- MapKit route search, route preview and Apple Maps hand-off.
- CoreLocation live navigation state.
- Off-route detection with cooldown-protected automatic rerouting.
- Remaining distance, ETA, GPS quality and route recalculation state.
- Share Extension and `ridedash://` route deep links.
- User-approved compatible-display Wi-Fi join via `NEHotspotConfigurationManager`.
- App-managed persistent Wi-Fi configuration.
- Local-network monitoring with `NWPathMonitor`.
- UDP control, input and video channels using Network.framework.
- Configurable protocol host, broadcast address, control/input/video ports, FPS and bitrate.
- K1G/TLV framing and rolling sequence handling.
- Dynamic RSA modulus/exponent parsing from the display.
- Fresh ephemeral AES-256 session key per authentication attempt.
- RSA PKCS#1 v1.5 session authentication.
- Auth timeout/rejection handling.
- Bounded exponential automatic reconnect.
- Navigation-mode restoration after reconnect.
- Repeated UDP-send failure recovery.
- Navigation/projection enter/exit sequencing.
- Route-card, active-nav, status and projection-frame keep-alives.
- VideoToolbox low-latency H.264 Baseline encoder.
- SPS/PPS extraction.
- RTP PT=96 packetization and FU-A fragmentation.
- 526×300 off-screen renderer and calibration grid.
- Known RIGHT / LEFT / DOWN / CLICK decoding and acknowledgements.
- Input debounce for repeated handlebar events.
- Stream/session metrics and sanitized diagnostics export.
- Thermal state, battery state and Low Power Mode monitoring.
- In-app deterministic K1G/RTP/FU-A self-check that generates no network traffic.
- Privacy manifest and required-reason declaration for UserDefaults.
- Independent interoperability NOTICE and permanent safety boundary.

### Remaining validation only

- Xcode compile/sign/install on the target iPhone.
- Exact target-firmware IP/port confirmation.
- Repeated authentication on the physical dash.
- Navigation-mode transition validation.
- Calibration grid visible on the physical dash.
- H.264/RTP stability testing.
- Physical LEFT / RIGHT / DOWN / CLICK validation.
- Ignition-cycle reconnect validation.
- iPhone lock/background behavior measurement.
- 30/60/120-minute thermal, battery and network endurance testing.

## 2. Product principles

1. Verify every firmware-sensitive assumption against owned hardware.
2. Keep protocol bytes and networking out of SwiftUI views.
3. Keep safety-critical motorcycle control permanently out of scope.
4. Use public iOS APIs only.
5. Keep manufacturer branding/assets/private keys out of the app unless separately authorized.
6. Never persist ephemeral authentication/session secrets.
7. Treat lock-screen/background projection behavior as a hardware/iOS feasibility measurement, not an assumption.
8. Do not use fake audio or other background-execution workarounds.

## 3. Scope

### In scope

- Native Swift/SwiftUI application.
- Compatible-display Wi-Fi joining and local-network monitoring.
- UDP session transport.
- K1G/TLV-compatible interoperability layer.
- Session authentication using dynamically supplied public-key material.
- H.264/RTP projection.
- 526×300 reference viewport, runtime-tunable where needed.
- CoreLocation + MapKit navigation.
- Route deviation and rerouting.
- Non-safety-critical dash button/joystick input.
- Automatic reconnect/session restoration.
- Vehicles, garage, expenses, fuel, maintenance, rides and reminders.
- Share Extension for route hand-off.
- Diagnostics, telemetry and compatibility records.

### Explicitly out of scope

- ECU, throttle, ABS, traction control, brakes, immobilizer, engine commands or other safety-critical vehicle control.
- Firmware modification, secure-boot bypass, firmware-signing bypass or exploitation.
- Extraction or redistribution of manufacturer private keys/certificates/confidential assets.
- Any feature that suppresses required speed/fuel/warning information.
- Policy-violating background execution techniques.

## 4. Definition of done

| Area | Acceptance criterion | Code status | Hardware status |
|---|---|---|---|
| Connectivity | App joins the compatible display AP and sees a valid local-network path. | ✅ | ⏳ |
| Transport | UDP control/input/video channels operate reliably. | ✅ | ⏳ |
| Authentication | Session handshake succeeds repeatedly without replayed secrets. | ✅ implementation | ⏳ |
| Projection control | Display enters/leaves navigation/projection mode cleanly. | ✅ implementation | ⏳ |
| Video | Stable iPhone-generated H.264 calibration stream for ≥30 min. | ✅ implementation | ⏳ |
| Input | Known button events decode, debounce and acknowledge correctly. | ✅ implementation | ⏳ |
| Navigation | Live route, maneuver, ETA, remaining distance and reroute state project correctly. | ✅ | ⏳ road test |
| Recovery | Connection/session loss triggers bounded reconnect and navigation restoration. | ✅ | ⏳ ignition test |
| Product | Vehicles/garage/expenses/fuel/rides/reminders operate locally. | ✅ | ⏳ device smoke test |
| Thermals | 60-minute ride remains stable with acceptable battery/thermal behavior. | ✅ telemetry | ⏳ |
| Background | Lock/background behavior is measured and documented per device/iOS. | ✅ location support | ⏳ |
| Safety | No safety-critical control path exists. | ✅ | ✅ design boundary |

## 5. Current architecture

```text
RideDashApp
├── App
│   ├── RideDashApp
│   ├── RootView
│   └── DashSessionCoordinator
├── Features
│   ├── Dashboard
│   ├── Navigation
│   ├── Display Connection / Projection
│   ├── Diagnostics
│   ├── Vehicles
│   ├── Garage / Maintenance / Fuel
│   ├── Expenses
│   ├── Rides
│   └── Settings
├── DashConnectivity
│   ├── TripperWiFiManager
│   ├── LocalNetworkMonitor
│   └── DashTransport
├── DashProtocol
│   └── DashProtocol.swift
│       ├── HexCodec
│       ├── K1GCodec
│       ├── DashEventDecoder
│       ├── DashAuthenticator
│       └── DashButton mapping
├── ProjectionCore
│   └── ProjectionCore.swift
│       ├── DashFrameRenderer
│       ├── H264Encoder
│       ├── H264NALUnit
│       ├── H264RTPPacketizer
│       └── ProjectionStreamer
├── NavigationCore
│   └── NavigationCore.swift
│       ├── NavigationLocationService
│       ├── RouteResolver
│       └── NavigationViewModel
├── Diagnostics
│   ├── DiagnosticLog
│   ├── DeviceHealthMonitor
│   └── deterministic protocol/RTP self-check
├── SwiftData models
│   ├── Vehicle
│   ├── Expense
│   ├── FuelLog
│   ├── MaintenanceRecord
│   └── RideRecord
└── RideDashShare
    └── URL/text Share Extension
```

## 6. Session lifecycle

```text
Disconnected
   ↓
Wi-Fi joined
   ↓
UDP transport ready
   ↓
Initial K1G burst
   ↓
RSA modulus + exponent received
   ↓
Generate fresh AES-256 key
   ↓
RSA PKCS#1 v1.5 encrypted session payload
   ↓
Authenticated
   ↓
Navigation-mode control sequence
   ↓
Route/nav/status keep-alives
   ↓
H.264 renderer → encoder → RTP → UDP
   ↓
Projecting
```

Failure handling:

```text
Transport/Auth/Repeated-send failure
   ↓
Bounded exponential reconnect
1s → 2s → 4s → 8s → 16s
   ↓
Re-authenticate
   ↓
Restore navigation mode when applicable
```

Manual Disconnect always cancels automatic reconnect.

## 7. Protocol / projection defaults to validate

These are **research defaults**, not guaranteed firmware constants:

| Setting | Current default |
|---|---:|
| Display host | `192.168.1.1` |
| Broadcast/control host | `192.168.1.255` |
| Control UDP | `2000` |
| Input UDP | `2002` |
| Video RTP UDP | `5000` |
| Viewport | `526×300` |
| Initial FPS | `4` |
| Initial bitrate | `250 kbps` |
| RTP payload type | `96` |

All firmware-sensitive network values remain configurable in the app.

## 8. Navigation implementation

Implemented navigation behavior:

- Destination text, coordinates or shared URL input.
- `MKLocalSearch` resolution.
- `MKDirections` automobile routing.
- Current location and heading tracking.
- Active maneuver/step tracking.
- ETA and remaining-distance updates.
- GPS degraded-state reporting.
- Off-route distance measurement against route polyline.
- Cooldown-protected route recalculation to avoid reroute loops.
- Recalculation count available for diagnostics.
- Handlebar input can move through projected navigation state without touching vehicle systems.

## 9. Product features

### Vehicles

- Multiple vehicle profiles.
- Active vehicle selection.
- Registration and odometer.
- Insurance expiry.
- PUC expiry.
- Last-service date.

### Garage / maintenance

- Fuel logs.
- Full-tank mileage calculation.
- Maintenance records.
- Next-due odometer.
- Next-due date.
- Local due-date notifications.

### Expenses

- Fuel/service/repair/accessory/gear/food/stay/transport/other categories.
- Local persistence.
- Currency preferences.
- CSV export.

### Rides

- Manual ride entries.
- Automatic ride session around projection usage.
- GPS distance accumulation.
- Start/end timestamps.
- Destination association.

## 10. Diagnostics and privacy

Diagnostics include:

- Wi-Fi join/remove events.
- Network path and interface state.
- Session state transitions.
- UDP RX/TX counts.
- Sanitized packet prefixes.
- Authentication/reconnect events.
- Encoder/RTP counters.
- Route recalculation state.
- Thermal state.
- Battery level/state.
- Low Power Mode.

The deterministic self-check validates K1G sequencing and RTP/FU-A behavior **without opening a network connection**.

Diagnostic export excludes by default:

- Wi-Fi passwords.
- AES session keys.
- RSA/private key material.
- Detailed route/location history.

Release hygiene currently includes:

- Privacy manifest.
- UserDefaults required-reason declaration (`CA92.1`).
- Local Network permission copy.
- Location permission copy.
- Hotspot Configuration entitlement.
- Independent interoperability NOTICE.

## 11. Recovery behavior

Implemented recovery paths:

- Authentication timeout.
- Authentication rejection limit.
- Transport failure detection.
- Repeated control-send failure detection.
- Bounded exponential reconnect.
- Re-authentication after reconnect.
- Navigation-mode restoration.
- User-visible reconnect attempt/reason.
- Input-event debounce.
- Manual stop/disconnect cancellation.

Still to verify physically:

- AP disappearance when ignition turns off.
- Rejoin timing after ignition turns on.
- Whether the display requires extra firmware-specific restart packets.
- Whether H.264 projection itself must be manually restarted after a recovered session.

## 12. Hardware validation plan

Run tests in this order. Do not jump directly to video on the first session.

### Stage A — Xcode/device baseline

1. Open `RideDash.xcodeproj`.
2. Select the developer team for RideDash and RideDashShare.
3. Compile/sign/install on the physical iPhone.
4. Fix any Xcode/compiler/signing issues found by the real SDK.
5. Open Diagnostics and run the local deterministic self-check.

### Stage B — network

1. Record dash firmware and iPhone/iOS version.
2. Enable the display Wi-Fi/AP through the normal motorcycle UI.
3. Record the SSID.
4. Confirm manual iOS join once.
5. Use RideDash to join the compatible display Wi-Fi.
6. Confirm `NWPath` reports Wi-Fi/local networking.
7. Confirm control transport can become ready.

### Stage C — authentication

1. Press **Connect + Authenticate**.
2. Confirm modulus and exponent arrive.
3. Confirm session-key packet is sent.
4. Confirm authentication accepted.
5. Repeat across at least three cold ignition cycles; target eventually 10/10.

### Stage D — navigation control plane

1. Enter navigation mode without starting H.264.
2. Confirm display changes to the expected navigation/projection state.
3. Verify keep-alive stability.
4. Stop and confirm clean return.

### Stage E — first pixels

1. Enable calibration grid.
2. Start H.264/RTP projection at 526×300, 4 fps, 250 kbps.
3. Confirm framing and orientation.
4. Run for 30 minutes.
5. Adjust packet size/FPS/bitrate only if hardware requires it.

### Stage F — controls

Verify:

- LEFT
- RIGHT
- DOWN
- CLICK
- acknowledgements
- debounce behavior

### Stage G — recovery/background/endurance

- Ignition off/on reconnect.
- Wi-Fi interruption.
- Screen dim/inactive.
- Phone locked.
- 30-minute session.
- 60-minute session.
- Optional 120-minute endurance session.
- Observe thermal and battery telemetry.

## 13. Hardware test matrix

| Test | Pass condition | Result |
|---|---|---|
| Xcode build/install | App launches on target iPhone | |
| Local self-check | K1G/RTP/FU-A checks pass | |
| Manual Wi-Fi join | iPhone joins expected local subnet | |
| In-app join | User-approved join succeeds | |
| Local Network permission | App initializes local networking | |
| UDP transport | Socket state reaches ready | |
| Authentication | Repeated cold attempts succeed | |
| Enter navigation | Physical display transitions correctly | |
| Projection off | Physical display returns cleanly | |
| Calibration grid | Correct framing/orientation | |
| 4 fps | 30 min stable | |
| 8 fps | Stable or documented unsupported | |
| 12 fps | Stable or documented unsupported | |
| Dash buttons | Known navigation inputs decoded/acked | |
| Ignition cycle | Automatic reconnect succeeds | |
| Reconnect restore | Navigation mode returns automatically | |
| Phone lock | Behavior measured/documented | |
| 60-minute ride | Thermal/battery/network acceptable | |

## 14. Release decision

Do not treat the current branch as production-ready until hardware validation is complete.

Before public distribution:

- Complete physical compatibility testing.
- Document supported dash firmware/device combinations.
- Confirm background operating mode.
- Perform App Store/privacy review.
- Perform trademark/IP/interoperability review.
- Keep public branding generic unless explicit authorization exists.
- Retain the permanent safety boundary.

## 15. Current repository workflow

- Implementation branch: `phase-1-connectivity-diagnostics`
- Draft PR: RideDash iOS complete first hardware-beta implementation
- CI/CD: intentionally not used
- Validation: manual Xcode + physical iPhone + owned motorcycle dash

Supporting documents:

- `Docs/IMPLEMENTATION_STATUS.md` — exact code-completion checklist.
- `Docs/MANUAL_TEST_GUIDE.md` — step-by-step device/bike validation procedure.
- `Docs/HARDWARE_TEST_MATRIX.md` — test result record.
- `Docs/PROTOCOL_NOTES.md` — interoperability research notes.
- `Docs/SAFETY_SCOPE.md` — permanent safety exclusions.

## 16. Immediate next action

The next step is no longer additional feature coding. It is:

1. Build/sign/install the branch on the physical iPhone.
2. Run the local self-check.
3. Connect to the compatible dash Wi-Fi.
4. Stop after the first successful authentication attempt and export the sanitized diagnostic log.
5. Use that hardware result to tune only firmware-specific values if needed.

Do **not** commit real Wi-Fi credentials, authentication/session keys, private device secrets or precise personal route history to the repository.
