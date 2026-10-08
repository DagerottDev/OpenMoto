# RideDash tester announcement

Publication scope: X, the maintainer's Reddit profile, and r/SideProject. Build-from-source testing preview only; no packaged release or App Store/TestFlight availability is implied.

## X

RideDash is open source and in testing 🏍️

An iOS ride companion for navigation, fuel, maintenance & expenses, with experimental Wi-Fi display projection.

Looking for iPhone testers & Swift contributors. Source build only; hardware validation pending.

https://github.com/DagerottDev/RideDash

## Reddit

Title: RideDash: an open-source iOS motorcycle companion in testing — looking for testers

I'm opening up RideDash, a native Swift/SwiftUI motorcycle navigation and ride companion, and I'm looking for testers and contributors.

The app has MapKit route previews, vehicle records, fuel and maintenance logs, expenses with CSV export, and ride history. It also has an experimental Wi-Fi motorcycle-display projection layer.

**Current status: testing phase.** Display compatibility, authentication, projection, controls, reconnect and endurance still need physical iPhone/display validation. I am not claiming it works with any particular firmware yet.

**Build from source only:** iOS 17+, a Mac with Xcode 16+, and your own appropriate signing setup for physical-device testing. I don't currently have an Apple Developer Program account, so there is no App Store, TestFlight, IPA or DMG download.

You don't need a motorcycle display to help: installation, permissions, navigation, local records, CSV export, accessibility and route sharing all need feedback. Authorized display owners can follow the staged test guide, starting stationary with Wi-Fi/authentication rather than jumping straight to projection. RideDash's project scope excludes safety-critical vehicle control and firmware modification.

The repo has a tester guide and issue forms for bugs, passing/failing test results and feature requests. Optional screen-only analytics is off by default and disabled in Debug/Simulator; routes, location, records, credentials and logs are excluded.

Repository: https://github.com/DagerottDev/RideDash
Tester guide: https://github.com/DagerottDev/RideDash/blob/main/Docs/TESTING.md
Feedback: https://github.com/DagerottDev/RideDash/issues/new/choose

If you try it, a small reproducible report with your commit, iPhone/iOS version and the checks you ran would help a lot. Swift review and accessibility feedback are welcome too.
