# OpenMoto privacy

OpenMoto is in testing. Vehicle, fuel, maintenance, expense and ride records are stored locally using SwiftData. Preferences use UserDefaults. Route lookup uses Apple MapKit and active navigation uses CoreLocation. Display networking sends navigation/projection traffic to the display selected by the user. Exported CSV and diagnostic logs are shared only through actions you initiate; review them before sharing.

## Optional usage analytics

Analytics is off by default. When a release build has a TelemetryDeck app ID and namespace configured, **Settings → Privacy → Share anonymous usage analytics** lets you opt in or out. Debug and Simulator builds never send analytics. An unconfigured build cannot enable the toggle.

The sole event is `OpenMoto.Screen.viewed`. Allowed screens are `home`, `navigation`, `garage`, `expenses`, `rides`, `settings`, `connection`, and `diagnostics`. Fixed payload properties are `OpenMoto.platform: iOS` and `OpenMoto.releaseStage: testing`; `OpenMoto.screen` is the allowlisted screen name. The API also sends the public app ID and `isTestMode: false` for configured physical-device release builds. A random, in-memory ID supplies `clientUser` and `sessionID` to group events within one app launch/consent period; it resets on app restart or when you turn sharing off. It is not an advertising, device, vehicle or account identifier. As a deliberate privacy tradeoff, this integration measures sessions and screen usage, not distinct users across app launches.

No locations, coordinates, destinations, search text, route URLs/history, registration numbers, vehicle records, amounts, expenses, fuel/maintenance details, Wi-Fi SSIDs/passwords, keys, packet data, screenshots, session replay, diagnostic/error content, emails or names are sent. There is no SDK, autocapture, crash capture or person identification. As with any HTTPS service, the provider receives the connection's network address; the app does not include IP/location fields in the event body.

Requests go directly over HTTPS to `https://nom.telemetrydeck.com/v2/namespace/<configured namespace>/` using the [documented ingestion API](https://telemetrydeck.com/docs/ingest/v2/). The app uses an ephemeral session without cookies or disk caching. Events are best-effort, with a five-second timeout, at most four in flight, no offline queue, and no retries. Failures do not block app features. Turning analytics off cancels outstanding requests and clears the in-memory ID; events already received by TelemetryDeck are not retroactively deleted.

See [TelemetryDeck's privacy policy](https://telemetrydeck.com/privacy/). This repository does not promise a provider-side retention period; maintainers must review project retention and data access before distributing a configured build. The Apple privacy manifest declares optional product-interaction analytics as not linked to identity and not used for tracking.

## Build configuration

Create a free TelemetryDeck account and an OpenMoto app in its dashboard, then set the public `TelemetryDeckAppID` (UUID) and `TelemetryDeckNamespace` in `OpenMoto/Info.plist`. No secret API key is needed. The repository contains the public OpenMoto app ID and namespace for its configured free workspace. Fork maintainers should replace them with their own app configuration or clear both values to disable analytics. Debug and Simulator builds remain disabled even after configuration.

The plan calculator checked on 8 October 2026 showed a free tier of 50,000 events/month with three-month retention and delayed reporting. Verify the current free plan in the dashboard before activation; do not add a paid plan or billing details to enable this preview. Physical-device release analytics remains unverified until a tester opts in and its event appears in the dashboard.

## Public reports

Use sample data. Remove personal route history, registration numbers, passwords, raw SSIDs, key material and personal identifiers from screenshots/logs. Diagnostics exports require your review even when fields are sanitized by the app. Public GitHub issues and pull requests can be read and copied by anyone.

The existing `dev.dagerott.ridedash` ingestion namespace is retained for reporting continuity. New events and properties use the `OpenMoto` prefix; historical events retain their original prefix.
