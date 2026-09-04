# Protocol Notes

RideDash keeps hardware/protocol assumptions isolated from product UI. The constants below are starting points from public interoperability references and must be validated against the user's owned dash firmware.

## Reference endpoints

- Dash host hypothesis: `192.168.1.1`
- Control send port hypothesis: UDP `2000`
- Input/listen port hypothesis: UDP `2002`
- H.264/RTP video port hypothesis: UDP `5000`
- Broadcast hypothesis: `192.168.1.255`
- Initial renderer size hypothesis: `526×300`

## Known public control messages

The public better-dash reference describes:

- RSA/AES session authentication before navigation projection.
- Navigation context and route-card messages.
- Projection-on / projection-off TLVs.
- Start-navigation command.
- Periodic projection, route, nav-info and status heartbeats.
- Button/input events received on the control listener.

## Safety rule

Unknown message families stay read-only until their meaning is understood. The app never sends commands to ECU, throttle, ABS, traction control, brakes, immobilizer, engine-management or other safety-critical services.

## Compatibility strategy

All endpoint/packet assumptions live in `DashProtocolConfiguration` and `DashProtocolConstants`. If manual testing shows firmware variation, add a capability profile rather than scattering conditional literals throughout UI/network code.
