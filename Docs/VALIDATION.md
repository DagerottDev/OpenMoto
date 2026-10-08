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


## OpenMoto rename validation — 8 October 2026

The app, share extension, Xcode project/targets, source directories, UI strings, projection/diagnostic labels, documentation, issue templates and new analytics event/property names use OpenMoto.

Completed for the rename:

- Unsigned Simulator Debug and iPhone Release builds passed with Xcode 27.0, including the renamed share extension. The initial sandboxed compile could not execute Swift macro plugins; the build passed outside that sandbox. Existing concurrency/capture warnings remain as described above.
- The standalone analytics contract check passed with the OpenMoto event/property allowlist and intercepted network requests.
- A Foundation-only Swift self-check compiled the actual `importURL` method extracted from the navigation source. It passed new and legacy schemes, mixed-case schemes/query aliases, percent-encoded destination text, external URLs and absent-query behavior. This is a method check, not a full navigation-view or extension hand-off test.
- App/share display names, new and legacy URL registrations, Xcode plist/entitlement paths, plist/project syntax, issue-form YAML and relative Markdown links passed checks. The staged rename diff was reviewed and `git diff --check` passed.
- The rename was pushed to GitHub and the remote `main` SHA matched the local commit. The renamed repository and profile links were verified through GitHub's API. Public announcement verification is recorded in [LAUNCH_POSTS.md](LAUNCH_POSTS.md).

Intentional compatibility references retain the former name: installed-app/extension bundle IDs, the SwiftData model module name, `ridedash://` URL support, the analytics ingestion namespace, historical records and permanent social links. Model definitions, storage configuration and preference keys are unchanged. Physical-device upgrade/data-retention testing is still pending.

A Simulator boot succeeded after an initial boot error, but installation stalled without returning a result. That test was stopped and the Simulator was shut down; no installed app, UI smoke test or runtime deep-link result is claimed. Physical iPhone/display validation and release analytics reporting remain pending.

The local checkout directory is `OpenMoto`. A `Ride Dash` symlink points to it so existing chat/tool paths continue to resolve. Codex's saved project label remains unchanged because no supported project-rename tool is available and native control of Codex is blocked. The TelemetryDeck organization label also remains unchanged; its app display name is OpenMoto.
