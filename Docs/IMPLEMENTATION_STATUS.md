# RideDash Implementation Status

This file tracks code completion independent of CI/CD. Final validation is manual on a physical iPhone and compatible motorcycle dash.

## Implemented

- [x] Project skeleton
- [x] Hotspot Configuration entitlement
- [x] In-app Wi-Fi join request
- [x] Local network path monitoring
- [x] UDP route scaffold
- [x] Diagnostic logging/export
- [x] Hardware test profile

## In progress

- [ ] Multi-port UDP transport and packet receive stream
- [ ] Protocol framing / K1G-TLV helpers
- [ ] Session state machine
- [ ] Authentication handshake
- [ ] Projection control plane
- [ ] H.264 encoder
- [ ] RTP packetization
- [ ] Projection streamer
- [ ] Dash renderer
- [ ] Navigation state engine
- [ ] Dash input decoder
- [ ] Recovery/reconnect
- [ ] Product UI

## Validation policy

No GitHub Actions or CI/CD workflow is used. The final integration test is performed manually on the user's owned Guerrilla 450 dash and iPhone. Firmware-specific constants remain configurable until that test is complete.
