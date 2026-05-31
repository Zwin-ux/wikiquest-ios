# Security

Report security issues privately through GitHub Security Advisories.

Do not open public issues for:

- account/session vulnerabilities
- purchase or entitlement bypasses
- App Store signing leaks
- backend token leaks
- private API keys or webhook secrets

## Secret Handling

The public repo must never contain:

- App Store Connect `.p8` keys
- `.p12` distribution certificates
- `.mobileprovision` profiles
- RevenueCat webhook secrets
- database URLs
- private API tokens

Public SDK keys may be required for builds, but release workflows should still source them from GitHub Actions secrets.

## Supported Branch

Security fixes target `main`.
