# Safety Scope

RideDash is an infotainment/navigation interoperability project.

## Allowed scope

- Dash Wi-Fi connectivity
- Navigation/session interoperability
- Projection rendering and video transport
- Route/navigation display
- Non-safety-critical dash buttons used to control RideDash UI
- Diagnostics and compatibility testing on hardware the tester owns or is authorized to test

## Permanently excluded

RideDash must not implement or experiment with commands affecting:

- ECU/engine management
- Throttle
- Brakes
- ABS
- Traction control
- Immobilizer/security systems
- Safety warnings or mandatory instrumentation
- Firmware flashing, secure boot, or firmware-signing bypass

## Test rules

1. Run first-time networking/protocol experiments while the motorcycle is stationary.
2. Treat unknown packet families as read-only until their purpose is understood.
3. Keep a first-class, best-effort projection-stop path.
4. Do not commit passwords, private keys, private certificates, or secret session material.
5. Do not use fake background modes to bypass iOS execution policy.
6. Do not present RideDash as manufacturer-affiliated or endorsed without authorization.
