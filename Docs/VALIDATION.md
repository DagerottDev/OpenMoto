# Testing-preview validation — 8 October 2026

## Completed checks

- Unsigned Simulator Debug compile with Xcode 27.0 (27A266a), iOS SDK 27.0, Swift 5 language mode. Both Simulator architectures compiled, including the share extension.
- Unsigned physical-device Release compile with the public TelemetryDeck configuration; no signing, install, archive or export.
- Standalone analytics contract check: consent defaults/persistence, absent and invalid configuration, strict event/property allowlist, all eight screen names, session ID reset after opt-out/relaunch, failure isolation, four-request bound and cancellation. All requests are intercepted; no external traffic.
- TelemetryDeck workspace/app created under the original RideDash name on the free plan (50,000 events/month, three apps, three-month retention, daily ingestion). A synthetic `isTestMode: true` event was accepted by the documented v2 endpoint with HTTP 200 / OK. This proves endpoint acceptance, not physical-device collection or dashboard reporting.
- GitHub issue-form YAML parsed with Ruby's standard YAML library; form IDs checked for duplicates and dropdown values checked as strings. All three forms appear in the live issue chooser, and the tester form renders its required fields. Plists/Xcode project syntax and local documentation links checked. `git diff --check` passed.
- Local Git history credential-pattern scan: 123 unique file versions, no matches. This is a limited pattern scan, not a guarantee that history contains no sensitive information.

The compile exposed existing blockers, corrected here: main-actor dependencies were created in nonisolated default-argument expressions; two Diagnostics sections used an invalid header/footer overload; two odometer values used SwiftUI-only interpolation where a plain String was required. No protocol or navigation behavior was changed by those corrections.

## Remaining checks

1. Physical iPhone signing, installation and UI/permission smoke testing. No Apple Developer Program account is available to the maintainer; testers need their own appropriate signing setup.
2. Consented physical-device Release analytics visible in the TelemetryDeck dashboard. The free plan ingests daily; no immediate dashboard result is claimed.
3. All staged firmware-specific display checks in [HARDWARE_TEST_MATRIX.md](HARDWARE_TEST_MATRIX.md), including authentication, normal-display recovery, projection, controls, reconnect, lock behavior and endurance.

The compiler still reports the existing CLLocationManagerDelegate actor-isolation and RootView capture-ownership warnings in Swift 5 mode. A Swift 6 migration needs separate validation. Xcode also reports skipped AppIntents metadata extraction because this app has no AppIntents dependency.

This record does not claim an installed app, physical hardware compatibility, a signed artifact or a packaged release. No DMG, IPA, TestFlight or App Store release is produced.
