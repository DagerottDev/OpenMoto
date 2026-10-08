# Contributing to RideDash

RideDash is in testing. Reproducible bugs, passing test reports, documentation improvements and small Swift fixes are welcome.

1. Search existing issues; use the [issue chooser](https://github.com/DagerottDev/RideDash/issues/new/choose) for a bug, test result or feature request.
2. For fixes, describe the observed behavior, expected result and reproduction steps. Keep pull requests focused and state what was actually validated.
3. Build in Xcode and run relevant checks. For protocol changes, run **Settings → Diagnostics → Run Protocol + RTP Self-Check**, then follow the staged [hardware guide](Docs/MANUAL_TEST_GUIDE.md) when applicable. Label untested hardware behavior explicitly.
4. Preserve the [safety scope](Docs/SAFETY_SCOPE.md), local records, permissions, protocol defaults and user preferences. Discuss changes to those contracts first.
5. Remove credentials, precise locations, personal records and unreviewed exports before sharing. A suspected security vulnerability belongs in [private vulnerability reporting](https://github.com/DagerottDev/RideDash/security/advisories/new), not a public issue. If that form is unavailable, contact the maintainer through an existing channel without including exploit details publicly.

## Local deterministic check

```sh
mkdir -p /tmp/ridedash-swift-cache
swiftc -module-cache-path /tmp/ridedash-swift-cache RideDash/App/UsageAnalytics.swift Tests/UsageAnalyticsCheck.swift -o /tmp/ridedash-analytics-check
/tmp/ridedash-analytics-check
```

This standalone macOS check intercepts network requests and uses an isolated UserDefaults suite. It does not send events to a real analytics service or establish physical-device compatibility. There is intentionally no CI/CD pipeline or Xcode test target.

An unsigned Simulator compile check is also available:

```sh
xcodebuild -project RideDash.xcodeproj -scheme RideDash -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/ridedash-build CODE_SIGNING_ALLOWED=NO build
```

Contributions are provided under the repository's [Apache-2.0 license](LICENSE). Preserve [NOTICE](NOTICE) and notices for incorporated third-party material.
