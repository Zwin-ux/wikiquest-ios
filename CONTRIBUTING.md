# Contributing

WikiQuest is a focused iOS project. The bar for changes is simple: make the game clearer, more playful, faster, or easier to trust.

## Before You Start

- Keep changes small and reviewable.
- Do not add runtime dependencies unless the problem clearly needs one.
- Prefer SwiftUI, Swift Concurrency, MapKit, ActivityKit, WidgetKit, and system APIs.
- Keep forms flat and direct. Avoid generic card-heavy app layouts.
- Use real Wikipedia/Commons media and preserve attribution behavior.

## Local Checks

```sh
corepack pnpm@10 install
corepack pnpm@10 run assets:wikiquest
corepack pnpm@10 run typecheck
xcodegen generate --spec project.yml
```

Then run the relevant Xcode tests:

```sh
xcodebuild \
  -project WikiQuest.xcodeproj \
  -scheme WikiQuest \
  -destination "generic/platform=iOS Simulator" \
  API_BASE_URL="https://wikiquest.app" \
  REVENUECAT_IOS_API_KEY="" \
  APPLE_TEAM_ID="" \
  CODE_SIGNING_ALLOWED=NO \
  build-for-testing
```

Public CI runs generated-asset checks, script typecheck, app/App Clip builds, and the Swift unit suite. For visual or navigation changes, still attach real simulator or TestFlight screenshots because UI smoke is a release gate, not a substitute for design review.

## Pull Requests

Every PR should include:

- What changed
- Why it matters for the player
- What was tested
- Screenshots for UI changes

## Design Standard

The product direction is Native Wiki Arcade: compact, visual, tactile, and readable. Avoid broad neon, glass panels, generic SaaS copy, and decorative noise.

## Security

Never commit credentials, signing assets, provisioning profiles, or private API keys. See [SECURITY.md](SECURITY.md).
