# RevenueCat

WikiQuest uses RevenueCat for native iOS Member subscriptions. The backend remains the source of truth for gameplay and server-side entitlements, while the iOS app uses RevenueCat for App Store purchase, restore, paywall, and Customer Center surfaces.

## SDK

Swift Package:

```text
https://github.com/RevenueCat/purchases-ios-spm.git
```

`project.yml` links both products:

- `RevenueCat`
- `RevenueCatUI`

Regenerate the project after changing packages:

```sh
xcodegen generate --spec project.yml
```

## API Keys

Use the key that matches the build:

- Local/debug with RevenueCat Test Store: `test_...`
- TestFlight/App Store with real App Store products: `appl_...`
- Never use `sk_...` in the iOS app. Secret keys are server-side only.

Local simulator example:

```sh
xcodebuild \
  -project WikiQuest.xcodeproj \
  -scheme WikiQuest \
  -destination "generic/platform=iOS Simulator" \
  API_BASE_URL="https://workspaceapi-server-production-e092.up.railway.app" \
  REVENUECAT_IOS_API_KEY="test_REPLACE_WITH_TEST_STORE_KEY" \
  APPLE_TEAM_ID="" \
  CODE_SIGNING_ALLOWED=NO \
  build
```

TestFlight release requires the public Apple SDK key:

```sh
gh secret set REVENUECAT_IOS_API_KEY --repo Zwin-ux/wikiquest-ios
```

Paste the `appl_...` key. The TestFlight workflow rejects `sk_...` and `test_...` keys.

## RevenueCat Dashboard Setup

Create these products:

```text
wikiquest_member_monthly
wikiquest_member_annual
```

Create this entitlement:

```text
member
```

Create a default Offering with two packages:

- Monthly package -> `wikiquest_member_monthly`
- Annual package -> `wikiquest_member_annual`

Attach the paywall design to the current Offering. The app opens `PaywallView` from `RevenueCatUI`, so the paywall content is managed in RevenueCat.

Enable Customer Center after products and entitlement are connected. The app opens `CustomerCenterView` from the Profile purchase area.

## App Behavior

`PurchaseStore` owns all RevenueCat state:

- configures the SDK once with `REVENUECAT_IOS_API_KEY`
- logs in with the WikiQuest account id when available
- fetches current Offerings
- fetches CustomerInfo
- purchases monthly/annual packages
- restores purchases
- maps the `member` entitlement into local UI state

Profile exposes:

- RevenueCat Paywall
- direct monthly/annual purchase rows when packages exist
- restore purchases
- Customer Center
- concise store/error status

If no products or Offering are configured, the app does not fake prices. It shows a direct Offering notice and keeps restore/Customer Center available.

## Release Rule

Do not upload TestFlight with a Test Store key. Use `test_...` for local development only, then replace the GitHub secret with the Apple public SDK key before release.
