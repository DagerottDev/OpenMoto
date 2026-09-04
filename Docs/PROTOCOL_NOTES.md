# RideDash protocol notes

This document records the interoperability assumptions currently encoded in RideDash. These are **not manufacturer specifications**. They are implementation notes based on publicly available independent interoperability work and must be verified against hardware you own/control.

## Default network profile

| Item | Current default |
|---|---:|
| Dash host | `192.168.1.1` |
| Broadcast target | `192.168.1.255` |
| Control UDP | `2000` |
| Input UDP | `2002` |
| H.264/RTP UDP | `5000` |
| Viewport | `526 × 300` |
| RTP payload type | `96` |
| RTP clock | `90000 Hz` |
| Initial FPS | `4` |
| Initial bitrate | `250 kbps` |

All network values are represented by `DashProtocolProfile` and are editable from the developer-facing Display screen.

## K1G envelope

The current codec treats packets as:

```text
0..1   outer packet length, big endian
2..3   segment count, big endian
4..7   reserved/header bytes
8..    TLV-like segments
```

Each segment begins with:

```text
type:1 | subtype:1 | length:2 big endian | payload:length
```

Outbound reference packets contain the ASCII marker `K1G ` followed by a rolling sequence byte. `K1GCodec.patchSequence` changes only that byte.

Unknown message families are logged; they should not become write commands until their role is understood.

## Session authentication

Current public-reference behavior implemented by `DashAuthenticator`:

1. App sends the request-auth control packet.
2. Display supplies RSA public material as K1G segments:
   - `07 00` — modulus
   - `07 03` — exponent
3. RideDash creates a cryptographically random 32-byte AES key using `SecRandomCopyBytes`.
4. Plaintext is `UTF8(display Wi-Fi SSID) || AES-256 session key`.
5. Plaintext is encrypted with the display-provided RSA key using PKCS#1 v1.5 (`SecKeyAlgorithm.rsaEncryptionPKCS1`).
6. Ciphertext is inserted in the reference session-key K1G packet.
7. `07 01 01` is treated as explicit authentication success.

The AES key is ephemeral and is never written to SwiftData, UserDefaults, diagnostics, or exported logs.

## Navigation / projection control

`DashSessionCoordinator` follows the public reference ordering:

1. navigation context
2. empty list state
3. repeated route-card packets
4. projection frame/on state
5. start-navigation control
6. route-card heartbeat
7. projection frame heartbeat while video is active

Stopping projection sends the reference stop/off pair and cancels both heartbeats.

## Known input mapping

The current reference input decoder maps `09 00` one-byte payloads:

| Value | Semantic action |
|---:|---|
| `0x13` | RIGHT |
| `0x14` | LEFT |
| `0x15` | DOWN |
| `0x18` | CLICK |

RideDash maps these only to navigation UI actions. The corresponding acknowledgement uses the public `06 80 0001 XX` pattern.

## H.264 / RTP

Video is generated natively with VideoToolbox:

- H.264 Baseline profile
- real-time mode
- frame reordering disabled
- default 526×300
- low initial FPS/bitrate for decoder stability

VideoToolbox produces AVCC length-prefixed NAL units. RideDash extracts them and captures the encoder's own SPS/PPS.

The embedded-display compatibility behavior follows the public working packetizer:

- SEI and AUD NALs are not sent.
- Ordinary small NALs are carried in one RTP packet.
- Large NALs use H.264 FU-A fragmentation.
- STAP-A is not used.
- Before an IDR is packetized, current SPS and PPS are bundled with the IDR using embedded Annex-B `00 00 00 01` separators.
- The bundle is then sent as a normal/FU-A RTP payload plan.
- RTP marker is set only on the final payload of the access unit.

Initial max RTP payload is 1380 bytes. If first-pixel testing shows fragmentation/MTU problems, lower this value before changing encoder semantics.

## Hardware-validation order

1. Wi-Fi join
2. UDP transport ready
3. RSA material received
4. auth success
5. navigation-mode transition
6. calibration grid only
7. stable low-FPS stream
8. button input
9. live MapKit navigation
10. ignition/reconnect tests
11. phone lock/background measurement

## References used during implementation

- `OpenMotoDash/better-dash` — public independent interoperability implementation and protocol notes.
- `subtlesayak/open-dash` — public product reference and historical interoperability context.
- Apple NetworkExtension documentation — `NEHotspotConfigurationManager`.
- Apple Network.framework documentation — UDP transport/listening.
- Apple VideoToolbox documentation — H.264 hardware encoding.

If behavior differs on the test firmware, preserve existing behavior behind a compatibility profile rather than replacing it globally.
