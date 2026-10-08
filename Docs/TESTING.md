# OpenMoto testing phase — testers wanted

OpenMoto is an experimental iOS 17+ motorcycle navigation and ride companion. We need reproducible feedback from iPhone testers, Swift contributors, and owners authorized to test compatible Wi-Fi motorcycle displays. Physical hardware validation is still pending. No firmware compatibility is promised. This stays a build-from-source preview: no DMG, IPA, App Store or TestFlight release is being produced. The maintainer does not currently have an Apple Developer Program account; physical-device testers need their own appropriate signing setup.

## Get started

1. Follow the [README installation steps](../README.md#installation) using Xcode 16+ and the default `main` branch. There is no App Store/TestFlight build; an Apple Development signing team is needed for physical-device installation.
2. Record your commit SHA (`git rev-parse --short HEAD`), Xcode version, iPhone model, and iOS version.
3. Use sample vehicle names, notes, expenses, and destinations so screenshots do not expose personal records. Do not rely on this preview as your only copy of important data.
4. Submit [a test result or bug](https://github.com/DagerottDev/OpenMoto/issues/new/choose). Passing results are useful too. No signup or direct message is required.

## App-only testing

A motorcycle display is not needed to test the app. Simulator can help check basic screens, but real location, permissions, signing, share-extension hand-off and background behavior need a physical iPhone.

- Install and launch; check permission denial and subsequent recovery.
- Add/select a vehicle; log fuel and maintenance, including a local reminder.
- Add an expense, filter it, and export CSV using sample values.
- Add a manual ride, relaunch, and check local records persist.
- Search a sample destination, preview a route, and try the Apple Maps hand-off.
- Try map URL/text sharing and `openmoto://route` intake.
- Check Dynamic Type, VoiceOver labels, and text clipping.
- Leave analytics off to verify all product functions remain available. See [privacy details](../PRIVACY.md).

## Display testing

Read [Safety Scope](SAFETY_SCOPE.md) and follow [Manual Hardware Test Guide](MANUAL_TEST_GUIDE.md) in order. Own the display or have explicit permission to test it.

Start stationary. For the first attempt, stop after Stage 3 authentication and inspect the log. Do not skip straight to projection. Record exact firmware, settings, the stage reached, and whether Stop Projection/Disconnect restored the normal display. Stop testing if normal speed/fuel/warning information does not recover.

Use the [hardware test result form](https://github.com/DagerottDev/OpenMoto/issues/new?template=test_result.yml). Never publish Wi-Fi passwords, raw SSIDs, keys, secret-bearing packet captures, registration numbers, exact personal routes, or unreviewed logs.

## What a result means

A successful build or protocol self-check does not establish display compatibility. A passing hardware result applies only to its recorded phone, iOS version, display firmware, settings and duration. Phone-lock behavior, reconnect and 30/60-minute endurance remain separate gates in the [hardware test matrix](HARDWARE_TEST_MATRIX.md).
