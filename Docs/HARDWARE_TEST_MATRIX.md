# Hardware Test Matrix

Update this file only with sanitized, non-secret results. Never commit Wi-Fi passwords, cryptographic keys, private certificates, or precise personal route history.

## Test target

| Field | Value |
|---|---|
| Bike | Guerrilla 450 |
| Dash firmware | TBD |
| Dash SSID pattern | TBD / sanitize before commit |
| iPhone | TBD |
| iOS | TBD |
| Date | TBD |

## Phase gates

| Test | Pass condition | Result | Notes |
|---|---|---|---|
| Manual Wi-Fi join | iPhone joins dash AP | ⬜ | |
| In-app Wi-Fi join | User-approved join succeeds | ⬜ | |
| Local path | `NWPath` is satisfied on Wi-Fi | ⬜ | |
| UDP route | Network.framework state reaches ready | ⬜ | Ready does **not** prove remote response |
| Dash datagram | Expected response/event captured | ⬜ | Phase 2 |
| Authentication | 10/10 cold attempts | ⬜ | Phase 4 |
| Projection mode | Dash enters/leaves cleanly | ⬜ | Phase 5 |
| Calibration stream | iPhone pixels visible | ⬜ | Phase 7 |
| 30-minute stream | Stable at baseline profile | ⬜ | |
| Input | Known nav controls decoded | ⬜ | Phase 10 |
| Ignition cycle | Reconnect succeeds | ⬜ | Phase 11 |
| Phone lock | Behavior measured/documented | ⬜ | Phase 12 |
| 60-minute ride | Thermal/battery/network acceptable | ⬜ | Phase 13 |
