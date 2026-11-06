# Implementation status — Flutter 0.3.0 preview

## Implemented and tested
- Material 3 Theme 1 native Flutter components and functional navigation.
- Investment, savings, property and debt create/edit/archive; owner-adjusted property accounting.
- Immutable transaction log with reversal; reports and cashflow range filtering.
- Valuation histories, recorded value source and dates; explicit zero/old valuation checks.
- Document metadata create/edit/archive/restore, categories, optional asset links and expiry.
- Legacy beneficiary intentions with combined 100%-share guard; trusted contacts.
- Goals, reminders, in-app notification rules and persisted alert settings.
- Search, financial statement, rental income and archive recovery.
- Local profile editing, help, safety disclosures, and subscription-information screen.
- JSON schema-1 backward compatibility for existing exports.
- Automated finance, persistence and widget tests; CI analyzer + Android debug APK.
- CI-generated 1080×2400 Flutter UI preview PNGs for new screen visual review (workflow artifact).

## Not production implemented
- Authenticated user accounts, passkeys, biometrics, account recovery, or protected multi-device access.
- Encrypted local database, encrypted file vault, real document uploads, remote backup.
- Financial integrations, FX policy, verified third-party valuations, full TWR/XIRR.
- Push notifications, payment processing, subscriber billing and account entitlements.
- Certified accessibility, cross-device pixel matching, independent security review or signed release distribution.

IMPORTANT: use **only fictional demonstration data** until security and privacy infrastructure is delivered. No legal estate transfer is performed by beneficiary notes. The public repository deliberately excludes confidential SRS materials.
