<a id="readme-top"></a>

![Swift][swift-shield]
![iOS 17+][ios-shield]
![Xcode 16+][xcode-shield]
![Testing phase](https://img.shields.io/badge/status-testing%20phase-orange?style=for-the-badge)
![Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue?style=for-the-badge)

<div align="center">
  <h1>OpenMoto</h1>
  <p>Formerly RideDash.</p>
  <p>A native iOS motorcycle navigation and ride companion with experimental Wi-Fi display projection.</p>
  <p><strong>Testing phase — looking for iPhone testers and authorized display owners.</strong></p>
  <p>
    <a href="Docs/TESTING.md">Start Testing</a>
    &middot;
    <a href="Docs/IMPLEMENTATION_STATUS.md">Implementation Status</a>
    &middot;
    <a href="Docs/MANUAL_TEST_GUIDE.md">Hardware Test Guide</a>
    &middot;
    <a href="https://github.com/DagerottDev/OpenMoto/issues/new/choose">Report Bug or Request Feature</a>
  </p>
</div>

<details>
  <summary>Table of Contents</summary>
  <ul>
    <li><a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#current-status">Current Status</a></li>
        <li><a href="#built-with">Built With</a></li>
      </ul>
    </li>
    <li><a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#testers-wanted">Testers Wanted</a></li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#display-compatibility-and-limitations">Display Compatibility and Limitations</a></li>
    <li><a href="#development-and-validation">Development and Validation</a></li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
  </ul>
</details>

## About The Project

OpenMoto brings navigation, motorcycle records, and ride expenses into one iPhone app. Its local data uses SwiftData, while an experimental interoperability layer projects navigation onto compatible Wi-Fi motorcycle displays.

Implemented capabilities include:

- **Navigation:** MapKit destination search and route preview, CoreLocation maneuver tracking, remaining distance and ETA, off-route detection with automatic rerouting, and Apple Maps hand-off.
- **Route intake:** destination text, coordinates, shared map URLs/text through a Share Extension, and `openmoto://route?url=...` deep links.
- **Vehicle and garage records:** multiple vehicles with active selection, document expiry dates, fuel logs with full-tank mileage calculation, maintenance history, next-due distance/date, and local due-date reminders.
- **Expenses and rides:** categorized expenses with CSV export, manual ride entries, automatic recording during projection sessions, and currency/distance preferences.
- **Display integration:** user-approved Wi-Fi joining, UDP control/input/video channels, K1G/TLV framing, dynamic RSA session authentication with a fresh ephemeral AES-256 key, and navigation/projection keep-alives.
- **Projection and recovery:** a 526 × 300 renderer, calibration grid, VideoToolbox H.264 Baseline encoding, RTP/FU-A packetization, known LEFT/RIGHT/DOWN/CLICK inputs and acknowledgments, and bounded automatic reconnect.
- **Diagnostics:** hardware profiles, network/session/stream counters, thermal and battery telemetry, Low Power Mode monitoring, sanitized log export, and a local protocol/RTP self-check.

OpenMoto is independent and brand-neutral. Display integration is limited to navigation and infotainment. ECU, throttle, brakes, ABS, traction control, immobilizer, engine control, firmware modification, and other safety-critical vehicle commands are permanently excluded. See [Safety Scope](Docs/SAFETY_SCOPE.md) and [NOTICE](NOTICE).

### Current Status

The [implementation checklist](Docs/IMPLEMENTATION_STATUS.md) records the planned first hardware beta as **code-complete, with hardware validation still pending**. Unsigned Simulator Debug and iPhone Release compiles have passed on Xcode 27; signing/install on a physical iPhone, display authentication, projection, controls, reconnect, and endurance behavior remain unverified in the [hardware test matrix](Docs/HARDWARE_TEST_MATRIX.md).

There are no published GitHub releases or packaged downloads (DMG/IPA). The maintainer does not currently have an Apple Developer Program account. Build from source; do not treat the current implementation as production-ready or assume compatibility with a particular display firmware. CI/CD is intentionally not used: final integration validation is manual on a physical iPhone and a display you own or are authorized to test.

### Built With

| Technology | Role |
|---|---|
| Swift and SwiftUI | Native iOS application and screens |
| SwiftData | Local vehicle, fuel, maintenance, expense, and ride storage |
| MapKit and CoreLocation | Route calculation, preview, and live navigation |
| NetworkExtension and Network.framework | Wi-Fi configuration, local-network monitoring, and UDP transport |
| Security.framework | Session-key generation and RSA authentication |
| CoreGraphics and VideoToolbox | Off-screen rendering and H.264 encoding |
| UIKit and UniformTypeIdentifiers | URL/text Share Extension |
| UserNotifications | Maintenance due-date reminders |

The project uses Apple frameworks without third-party package dependencies.

<p align="right"><a href="#readme-top">Back to top</a></p>

## Getting Started

### Prerequisites

- A Mac with **Xcode 16 or newer** and its iOS SDK. The project uses Swift 5 language mode and targets **iOS 17.0+**.
- An Apple Development signing team for installing on a physical iPhone.
- A physical iPhone running iOS 17 or newer for display integration. Simulator cannot validate accessory Wi-Fi or actual display projection.
- Internet access for MapKit destination search and route calculation.
- For display testing: an authorized compatible Wi-Fi motorcycle display, its SSID/password, and its exact firmware version. Compatibility must be established through the hardware test guide.

### Installation

1. Clone the default branch (`main`) and open the Xcode project:

   ```sh
   git clone https://github.com/DagerottDev/OpenMoto.git
   cd OpenMoto
   open OpenMoto.xcodeproj
   ```

   If you already have a checkout, open its existing `OpenMoto.xcodeproj`. No package-manager installation or environment-variable configuration is required. Optional TelemetryDeck screen analytics is off by default and disabled in Debug/Simulator; see [PRIVACY.md](PRIVACY.md) for the public release configuration and fork setup.

2. In **Signing & Capabilities**, select your Apple Development team for both **OpenMoto** and **OpenMotoShare**. Change bundle identifiers if required by your signing account; keep the extension identifier under the app identifier.
3. Confirm the **Hotspot Configuration** capability is enabled for the OpenMoto target. The committed app configuration includes Local Network and Location usage descriptions and the location background mode.
4. Select the **OpenMoto** scheme and your physical iPhone, then use **Product → Run** to build, sign, and install.
5. Grant Location permission for routing and Local Network permission when testing the display connection. Notification permission is used for maintenance reminders.

Before connecting hardware, read the [Tester Guide](Docs/TESTING.md) and [Manual Hardware Test Guide](Docs/MANUAL_TEST_GUIDE.md).

<p align="right"><a href="#readme-top">Back to top</a></p>

## Testers Wanted

**OpenMoto is currently in testing, and we need testers.** This is an experimental source-build preview; hardware compatibility and reliable projection are not yet established. There is no App Store or TestFlight download.

- **iPhone app testers:** check installation, navigation, garage/fuel/maintenance records, expense CSV export, ride records, and permissions.
- **Authorized display owners:** follow the staged hardware guide, beginning with stationary Wi-Fi and authentication tests. Record both passes and failures, including firmware and normal-display recovery.
- **Swift contributors:** help reproduce bugs, improve accessibility, and review the existing navigation and interoperability implementation.

Start with [Docs/TESTING.md](Docs/TESTING.md), then submit a [test result, bug, or feature request](https://github.com/DagerottDev/OpenMoto/issues/new/choose). Remove personal information from logs and screenshots before posting.

<p align="right"><a href="#readme-top">Back to top</a></p>

## Usage

### Add a Motorcycle and Calculate a Route

1. Open **Settings → Vehicles**, tap **+**, enter a vehicle name, registration, and odometer, then tap **Save**. The first vehicle becomes active automatically; use the leading swipe action **Active** to select another vehicle.
2. Open **Garage** to log fuel or maintenance. Use **Expenses** for categorized spending and CSV export, or **Rides** for manual ride records.
3. Open **Navigate**, allow Location access, and enter a destination name, coordinates, or a map URL.
4. Tap the route arrow beside the destination field. Review the map, maneuver, distance, and ETA. Use **Apple Maps** to hand the destination to Apple's navigation app.

The app retains its original bundle identifiers and Swift module name to preserve installed-app and SwiftData identity. Existing `ridedash://` route links remain supported; new links use `openmoto://`. Keep your existing signing identifiers when updating an installed build. Physical-device upgrade and data-retention validation is still pending.

The Share Extension accepts a URL or text from another app's share sheet and forwards it to OpenMoto's route intake. Deep links use `openmoto://route?url=<percent-encoded destination or map URL>`; the hand-off still needs validation on the target device.

### Test a Display Connection

Keep the motorcycle stationary for initial networking and protocol tests. Follow the [manual guide](Docs/MANUAL_TEST_GUIDE.md) in order:

1. Record the motorcycle, display firmware, iPhone, and iOS version in **Settings → Diagnostics**. Run **Run Protocol + RTP Self-Check** before sending network traffic.
2. Confirm the display's normal Wi-Fi mode and a manual iPhone Wi-Fi join. In Diagnostics, enter credentials locally and tap **Request Wi-Fi Join**.
3. Open **Settings → Connection & Projection**, verify the SSID and protocol profile, then tap **Connect + Authenticate**. For the first session, stop after successful authentication and inspect the sanitized log before continuing.
4. After authentication has been verified, use **Enter Navigation Mode** and confirm **Stop Projection** restores the normal display before testing video.
5. Enable **Calibration grid**, then use **Start H.264/RTP Projection** at the conservative defaults. Test live route projection only after calibration passes; calculate the route before switching to display Wi-Fi without internet.
6. Use **Stop Projection** to end projection and **Disconnect** to end the session and cancel automatic reconnect.

Diagnostics' **Open UDP Route** is a transport-only probe. A ready UDP connection does **not** prove that the display responded or authenticated; authentication and video controls are in **Connection & Projection**.

<p align="right"><a href="#readme-top">Back to top</a></p>

## Display Compatibility and Limitations

These are research defaults from the implemented public-reference profile, **not manufacturer specifications or guaranteed firmware values**:

| Setting | Default |
|---|---|
| Display host | `192.168.1.1` |
| Broadcast/control host | `192.168.1.255` |
| Control UDP port | `2000` |
| Input UDP port | `2002` |
| H.264/RTP UDP port | `5000` |
| Render viewport | `526 × 300` |
| Initial projection rate | `4 fps` |
| Initial bitrate | `250 kbps` |
| RTP payload type / clock | `96` / `90,000 Hz` |

Host, broadcast, ports, frame rate, and bitrate are editable in **Connection & Projection**. Record the exact firmware, then change one parameter per test. See [Protocol Notes](Docs/PROTOCOL_NOTES.md) for authentication, framing, input mappings, and packetization details.

- **Internet and routing:** MapKit route calculation generally requires internet. Calculate the route before joining a display access point without internet; rerouting may also be unavailable on that network.
- **Locked phone:** background location supports active navigation, but does not guarantee indefinite VideoToolbox encoding or UDP projection after lock. Measure behavior on the target iPhone/iOS version; do not use fake background modes.
- **Native display maneuver metadata:** the nav-info heartbeat currently uses a generic continue/500 m placeholder. Actual turn instructions are rendered into the H.264 projection.
- **Firmware and controls:** known inputs and packet sequencing still require physical validation. Keep unknown packet families read-only until understood.
- **Safety:** do not test new protocol behavior while moving. Stop testing if the normal speed/fuel/warning display does not recover after projection stops.
- **Privacy:** see [PRIVACY.md](PRIVACY.md) for local storage and optional screen analytics. Enter Wi-Fi credentials only on the device. Never commit passwords, session keys, private key material, raw secret-bearing captures, or precise personal route history. Review diagnostic exports before sharing.

<p align="right"><a href="#readme-top">Back to top</a></p>

## Development and Validation

Build and run manually in Xcode as described above. There is no CI workflow or Xcode test target in this checkout. Deterministic analytics checks are documented in [CONTRIBUTING.md](CONTRIBUTING.md). The in-app **Settings → Diagnostics → Run Protocol + RTP Self-Check** checks K1G decoding, sequence patching, route-card generation, and RTP/FU-A packet construction without network traffic; it does not establish hardware compatibility.

| Source area | Responsibility |
|---|---|
| [`OpenMoto/App/`](OpenMoto/App/) | App entry, tab navigation, session coordination, and automatic ride recording |
| [`OpenMoto/Features/`](OpenMoto/Features/) | Product screens, SwiftData models, settings, and diagnostics UI |
| [`OpenMoto/NavigationCore/`](OpenMoto/NavigationCore/) | Destination resolution, location, route state, and rerouting |
| [`OpenMoto/DashConnectivity/`](OpenMoto/DashConnectivity/) | Wi-Fi, local-network state, and UDP channels |
| [`OpenMoto/DashProtocol/`](OpenMoto/DashProtocol/) | K1G framing, authentication, and input decoding |
| [`OpenMoto/ProjectionCore/`](OpenMoto/ProjectionCore/) | Renderer, H.264 encoder, RTP packetizer, and streamer |
| [`OpenMotoShare/`](OpenMotoShare/) | URL/text Share Extension |

Use the existing documentation for the full validation record:

- [Implementation Status](Docs/IMPLEMENTATION_STATUS.md) — implemented code and open hardware gates.
- [Project Plan](Docs/PROJECT_PLAN.md) — architecture, session lifecycle, acceptance criteria, and release decision.
- [Manual Hardware Test Guide](Docs/MANUAL_TEST_GUIDE.md) — ordered physical-device tests and failure reporting.
- [Hardware Test Matrix](Docs/HARDWARE_TEST_MATRIX.md) — firmware/device details and sanitized results.
- [Protocol Notes](Docs/PROTOCOL_NOTES.md) — interoperability assumptions and public-reference mapping.
- [Safety Scope](Docs/SAFETY_SCOPE.md) — permanent exclusions and test boundaries.

<p align="right"><a href="#readme-top">Back to top</a></p>

## Roadmap

The documented next work is validation of the existing implementation:

- [x] Compile an unsigned Simulator build on Xcode 27.
- [ ] Sign and install on the target iPhone; run the local self-check.
- [ ] Verify firmware-specific endpoints, authentication across cold ignition cycles, and clean navigation-mode entry/exit.
- [ ] Validate the calibration stream, live route projection, and physical LEFT/RIGHT/DOWN/CLICK inputs.
- [ ] Measure reconnect, phone-lock/background behavior, and 30/60-minute thermal, battery, and network stability.
- [ ] Complete the documented compatibility, privacy, and interoperability reviews before public distribution.

See the [Project Plan](Docs/PROJECT_PLAN.md) for detailed acceptance criteria and extended endurance tests.

<p align="right"><a href="#readme-top">Back to top</a></p>

## Contributing

Contributions and tester feedback are welcome through the [issue forms](https://github.com/DagerottDev/OpenMoto/issues/new/choose) and pull requests. See [CONTRIBUTING.md](CONTRIBUTING.md). Build/run relevant changes in Xcode, run the local protocol/RTP self-check for interoperability changes, and record hardware results when applicable. Preserve the safety boundary and keep credentials, keys, and personal route history out of contributions.

For hardware failures, include the test stage, display firmware, iPhone/iOS version, protocol settings, observed state, sanitized logs, and whether the normal display recovered after stopping. Use the [failure-reporting guide](Docs/MANUAL_TEST_GUIDE.md#failure-reporting).

<p align="right"><a href="#readme-top">Back to top</a></p>

## License

Licensed under the [Apache License, Version 2.0](LICENSE). Preserve [NOTICE](NOTICE), which records copyright, interoperability references, trademark acknowledgments, and the project safety scope. The safety scope describes what maintainers accept into this project; it does not add restrictions to the license.

<p align="right"><a href="#readme-top">Back to top</a></p>

## Contact

Project support and feature discussions: [OpenMoto issues][issues-url].

<p align="right"><a href="#readme-top">Back to top</a></p>

## Acknowledgments

- Public independent interoperability work from `OpenMotoDash/better-dash` and `subtlesayak/open-dash`, as recorded in [Protocol Notes](Docs/PROTOCOL_NOTES.md) and [NOTICE](NOTICE).
- Apple public frameworks for networking, navigation, rendering, and encoding.
- README layout inspired by [Best-README-Template](https://github.com/othneildrew/Best-README-Template).

Third-party names and trademarks belong to their respective owners. OpenMoto is not affiliated with, endorsed by, or sponsored by those owners.

<p align="right"><a href="#readme-top">Back to top</a></p>

[swift-shield]: https://img.shields.io/badge/Swift-F05138?style=for-the-badge&logo=swift&logoColor=white
[ios-shield]: https://img.shields.io/badge/iOS-17%2B-000000?style=for-the-badge&logo=apple&logoColor=white
[xcode-shield]: https://img.shields.io/badge/Xcode-16%2B-147EFB?style=for-the-badge&logo=xcode&logoColor=white
[issues-url]: https://github.com/DagerottDev/OpenMoto/issues
