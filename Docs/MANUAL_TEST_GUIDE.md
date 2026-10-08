# OpenMoto Manual Hardware Test Guide

This is the required validation path for the first physical iPhone + motorcycle-display beta. There is intentionally **no CI/CD pipeline** for this project. Do not skip directly to projection: each stage proves a narrower dependency and makes failures diagnosable.

## Safety prerequisites

- Perform initial protocol tests with the motorcycle stationary, parked securely and in a well-ventilated area.
- Use only a display/motorcycle you own or are authorized to test.
- Do not test unknown packet families while riding.
- OpenMoto contains no ECU, throttle, brake, ABS, traction-control, immobilizer or engine-control command path.
- Stop immediately if the normal speed/fuel/warning display does not recover after projection is stopped.

## Before building

Record these values in `Docs/HARDWARE_TEST_MATRIX.md` and in the app's Diagnostics screen:

- Motorcycle model
- Dash/display firmware version
- Dash Wi-Fi SSID pattern
- iPhone model
- iOS version
- Whether the official/default navigation flow currently works

Do **not** commit the Wi-Fi password, authentication session key, private key material, precise route history or other secrets.

## Xcode setup

1. Clone `DagerottDev/OpenMoto` and check out the default `main` branch.
2. Open `OpenMoto.xcodeproj` in Xcode 16 or newer.
3. Select your Apple Development team for the `OpenMoto` and `OpenMotoShare` targets.
4. Change bundle identifiers if your signing account requires it.
5. Confirm the main target has **Hotspot Configuration** enabled.
6. Confirm the app shows Local Network and Location permission strings.
7. Select a physical iPhone. Do not use Simulator for dash Wi-Fi/projection validation.
8. Build and install manually.

## Stage 0 — Baseline display/Wi-Fi

**Goal:** establish that the phone and dash can form the expected local network before OpenMoto sends anything.

1. Power on the motorcycle normally.
2. Enable the display's normal phone/navigation Wi-Fi mode.
3. Record the displayed SSID exactly.
4. Join that SSID manually from iPhone Settings once.
5. Confirm the iPhone remains associated even though the network may have no internet.
6. If possible, record the phone's local address/subnet. The public reference commonly uses a `192.168.1.x` client with the dash at `192.168.1.1`, but do not assume this if your firmware differs.
7. Disconnect and repeat after one ignition power-cycle.

**Pass:** iPhone can reliably join the display AP.

## Stage 1 — OpenMoto Wi-Fi + local network

**Goal:** validate only Apple's Wi-Fi/local-network layer.

1. Open OpenMoto → Settings → Diagnostics.
2. Enter the real SSID and password locally.
3. Tap **Request Wi-Fi Join**.
4. Accept the native iOS approval prompt if shown.
5. Grant Local Network permission.
6. Confirm Diagnostics reports a satisfied path using Wi-Fi.
7. Export a diagnostic log and verify it does not contain the Wi-Fi password.

**Pass:** user-approved join works and `NWPath` reports usable Wi-Fi.

## Stage 2 — UDP transport

**Goal:** prove control/input sockets can open using the configured endpoints.

Default research profile:

- Dash: `192.168.1.1`
- Broadcast/control: `192.168.1.255:2000`
- Input listener: UDP `2002`
- Video: `192.168.1.1:5000`

The control connection binds its local source port to the configured control port to match the public reference behavior.

1. Open Settings → Connection & Projection.
2. Verify host/broadcast/ports against your observed network.
3. Do not change several variables at once.
4. Start **Connect + Authenticate** only when the bike is stationary.
5. Watch RX/TX counters and Diagnostics logs.

**Pass:** control transport becomes ready and the input listener is bound without errors.

## Stage 3 — Authentication

**Goal:** complete a fresh session handshake without captured secrets.

Expected public-reference sequence:

1. OpenMoto sends the initial K1G burst including the authentication request.
2. Dash sends RSA modulus (`07 00`) and exponent (`07 03`) on the input/control response channel.
3. OpenMoto generates a new 32-byte AES-256 session key locally.
4. OpenMoto encrypts `SSID UTF-8 || AES key` using the dash-provided RSA public key with PKCS#1 v1.5.
5. OpenMoto sends the dynamic session-key packet.
6. Dash returns `07 01 01` for success.

Check Diagnostics for:

- RSA modulus received
- RSA exponent received
- Encrypted AES session key sent
- Dash authentication accepted

Do not publish the session key or raw hardware-specific secrets.

**Pass:** state reaches **Authenticated**.

Repeat this stage after three cold ignition cycles. A stale/captured ciphertext must never be required.

## Stage 4 — Enter navigation mode without video

**Goal:** prove the control plane before H.264/RTP is involved.

1. After authentication, tap **Enter Navigation Mode**.
2. OpenMoto sends navigation context, empty-list state, route-card bursts, projection-on flags and start-navigation.
3. It then starts independent keep-alives:
   - projection-frame heartbeat at the configured FPS when projection is active,
   - route card at ~1 Hz,
   - active nav-info at ~1 Hz,
   - metadata/status heartbeat at ~1 Hz.
4. Observe the dash transition.
5. Tap **Stop Projection** and verify the dash returns to its normal state.

**Pass:** navigation/projection mode can be entered and exited repeatedly without video.

If the display does not change state, stop here and export the diagnostic log before tuning packet ordering or firmware-specific constants.

## Stage 5 — Calibration H.264/RTP stream

**Goal:** display known iPhone-generated pixels before attempting live maps.

1. Set conservative defaults first:
   - 526 × 300
   - 4 fps
   - 250 kbps
2. Enable **Calibration grid**.
3. Enter navigation mode.
4. Tap **Start H.264/RTP Projection**.
5. Watch:
   - rendered-frame count,
   - RTP packet count,
   - encoded byte count,
   - dash image stability.
6. Run for 2 minutes first.
7. Stop projection and verify normal display recovery.

**Pass:** calibration grid is visible, correctly framed and stable.

Only after this passes should you try 8 fps or higher bitrate. Change one parameter per test.

## Stage 6 — Live route projection

**Goal:** validate the end-to-end product path.

1. Reconnect to an internet-capable network first if needed.
2. In OpenMoto → Navigate, calculate a route with MapKit **before** joining a display Wi-Fi network that has no internet.
3. Rejoin the display Wi-Fi.
4. Authenticate and enter navigation.
5. Disable Calibration grid.
6. Start projection.
7. Verify the projected frame shows:
   - destination,
   - current maneuver text,
   - distance to maneuver,
   - ETA,
   - remaining distance,
   - speed from CoreLocation,
   - degraded-GPS state when accuracy is poor.

The current native dash nav-info heartbeat intentionally uses a conservative generic continue/500 m value as a watchdog-compatible placeholder; the real turn instruction is rendered into the H.264 projection. Hardware results can later expand the native maneuver-code compatibility table.

**Pass:** live MapKit state visibly updates in the projected UI.

## Stage 7 — Handlebar/dash input

Known public-reference input codes:

- `0x13` → RIGHT
- `0x14` → LEFT
- `0x15` → DOWN
- `0x18` → CLICK

1. Keep the motorcycle stationary.
2. Press each relevant navigation control once.
3. Confirm OpenMoto displays the last input and logs it.
4. Confirm LEFT/RIGHT changes the selected route step in the app.
5. Confirm the corresponding acknowledgement is transmitted when `respondToInput` is enabled.
6. Record unknown codes but do not add speculative acknowledgements until understood.

**Pass:** known inputs are repeatable and do not affect safety-critical vehicle functions.

## Stage 8 — Recovery testing

Run these independently:

1. Projection stop/start without turning off the motorcycle.
2. Wi-Fi off/on on the iPhone.
3. App foreground → inactive → foreground.
4. Motorcycle ignition off/on.
5. Force-close and relaunch OpenMoto.

For each test, record whether manual reconnect is needed and whether the dash returns cleanly to normal mode.

**Pass:** no reinstall/re-pair is needed and normal dash mode is recoverable.

## Stage 9 — Screen lock/background feasibility

This is an iOS feasibility measurement, not an assumed feature.

Test separately:

1. App foreground, screen on.
2. Screen dimmed.
3. App temporarily inactive.
4. Device locked.

Record:

- time until projection freezes (if it does),
- whether CoreLocation continues,
- whether encoder packet counters continue,
- whether UDP traffic resumes after unlock,
- thermal state and battery impact.

Do not add silent-audio or other fake background-mode workarounds. If iOS suspends video/network work when locked, the supported product mode should remain foreground/low-brightness navigation.

## Stage 10 — Duration tests

Only after all earlier stages pass:

- 10 minutes stationary
- 30 minutes stationary/on-road as appropriate
- 60 minute ride
- 120 minute extended test later

Measure:

- disconnects/reconnects,
- projection freezes/blinks,
- encoder/RTP counters,
- iPhone battery drain,
- `ProcessInfo.processInfo.thermalState`,
- GPS accuracy gaps,
- dash recovery after stopping.

Start at 4 fps. Test 8 and 12 fps only after the conservative profile is stable.

## Failure reporting

When something fails, send/export:

- stage number,
- exact dash firmware,
- iPhone model + iOS version,
- configured host/broadcast/ports/FPS/bitrate,
- OpenMoto state shown in UI,
- sanitized Diagnostic Log,
- what appeared on the physical dash,
- whether normal dash mode recovered after Stop/Disconnect.

Do not send Wi-Fi passwords, private keys, session AES keys or personal route history.

## First recommended test

For the very first run, stop after **Stage 3 Authentication** and inspect the diagnostic log. If authentication is stable across three ignition cycles, proceed to Stage 4 and then the calibration stream. This gives the fastest useful feedback if the target firmware differs from the public reference.
