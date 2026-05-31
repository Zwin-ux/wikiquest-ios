# Release

Public CI builds without signing. TestFlight release requires private Apple and RevenueCat secrets.

## Required GitHub Secrets

- `API_BASE_URL`
- `REVENUECAT_IOS_API_KEY`
- `APPLE_TEAM_ID`
- `APPLE_CERTIFICATE_BASE64`
- `APPLE_CERTIFICATE_PASSWORD`
- `APPLE_PROVISIONING_PROFILE_BASE64`
- `APPLE_WIDGETS_PROVISIONING_PROFILE_BASE64`
- `APPLE_APP_CLIP_PROVISIONING_PROFILE_BASE64`
- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_API_KEY_P8_BASE64`

## Apple Identifiers

- App: `com.wikiquest.app`
- Widget extension: `com.wikiquest.app.widgets`
- App Clip: `com.wikiquest.app.Clip`
- App Group: `group.com.wikiquest.app`

## Release Checklist

1. Confirm backend `API_BASE_URL` points to production.
2. Run backend smoke tests from the private backend repo.
3. Confirm RevenueCat products and `member` entitlement.
4. Run public iOS CI.
5. Dispatch TestFlight release workflow.
6. Install TestFlight build.
7. Capture screenshots: icon, onboarding, Quest Deck, Mystery, Race, Map, Ranks, Me, App Clip.
8. Review screenshots before public App Store submission.

## App Clip

The App Clip is included in the archive only when the App Clip provisioning profile secret exists. Public App Clip invocation still needs Associated Domains and App Store Connect App Clip metadata.
