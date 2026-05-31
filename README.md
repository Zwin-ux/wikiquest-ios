# WikiQuest for iOS

WikiQuest turns Wikipedia into a native iOS game: solve a hidden article, race through blue links, and place pins on a map.

This repository is the public SwiftUI app. It is intentionally narrow: iOS app, widget, App Clip, Live Activities, design system, tests, and release automation. The production backend is separate.

## What It Is

- **Mystery**: solve a Wikipedia article from clues and photo reveals.
- **Race**: move from one article to a target article by choosing links.
- **Map**: guess where a nearby article belongs on the map.
- **App Clip**: a lightweight one-round Mystery preview with no account or purchase.
- **Widgets and Live Activities**: quick return surfaces for daily play and active runs.

The design direction is **Native Wiki Arcade**: paper, ink, rule lines, mode color, compact controls, real Wikipedia/Commons media, and small tactile motion.

## Repository Shape

```text
AppClip/            App Clip entry point and Clip Quest UI
Resources/          Info.plist, entitlements, AppIcon, brand assets
Sources/            SwiftUI app, core clients, game view models, shared design
Tests/              unit tests, UI smoke tests, App Clip smoke tests
WidgetExtension/    widget and ActivityKit surfaces
scripts/            deterministic asset generator and release helpers
project.yml         XcodeGen project definition
```

## Requirements

- macOS with Xcode 16+
- XcodeGen
- Node 24+ and pnpm 10 for asset generation

```sh
brew install xcodegen
corepack enable
corepack pnpm@10 install
```

## Build Locally

```sh
corepack pnpm@10 run assets:wikiquest
xcodegen generate --spec project.yml
open WikiQuest.xcodeproj
```

For a simulator build without signing:

```sh
xcodebuild \
  -project WikiQuest.xcodeproj \
  -scheme WikiQuest \
  -destination "generic/platform=iOS Simulator" \
  API_BASE_URL="https://wikiquest.app" \
  REVENUECAT_IOS_API_KEY="" \
  APPLE_TEAM_ID="" \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Configuration

The app reads build settings through `Info.plist`:

- `API_BASE_URL`: WikiQuest API base URL.
- `REVENUECAT_IOS_API_KEY`: RevenueCat public SDK key for native subscriptions.
- `APPLE_TEAM_ID`: Apple Developer team id for signed archive builds.

Public CI uses placeholder values and disables code signing. Release workflows require private GitHub secrets.

## Assets

The app icon and brand marks are generated from deterministic SVG paths. No font-based logo export is accepted.

```sh
corepack pnpm@10 run assets:wikiquest
```

The verifier checks icon dimensions, empty files, and SVG text/font usage.

## Open Source Boundary

This repo contains the public iOS client. Do not commit:

- App Store Connect `.p8` keys
- distribution certificates
- provisioning profiles
- RevenueCat secrets
- database URLs
- webhook secrets

The app may display Wikipedia and Wikimedia Commons media. Those assets are loaded at runtime and remain under their original licenses. The UI should expose source links when media is revealed.

## Contributing

Small, focused changes are preferred. Before opening a PR:

```sh
corepack pnpm@10 run assets:wikiquest
corepack pnpm@10 run typecheck
xcodegen generate --spec project.yml
```

Then run the relevant Xcode tests. Public CI builds the app and App Clip, runs the Swift unit suite, and compiles simulator test bundles on macOS. Full UI smoke runs remain part of TestFlight/device QA because simulator accessibility timing can be noisy for boot and sign-in screens.

The next product/design loop is captured in [Next Skill System](docs/next-skill-system.md).

## License

Apache-2.0. See [LICENSE](LICENSE).

WikiQuest is not affiliated with the Wikimedia Foundation.
