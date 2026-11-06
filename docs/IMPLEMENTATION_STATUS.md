# Implementation status — Flutter 0.4.0 local alpha

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
- Schema-1 JSON backward compatibility; schema-2 export carries new fields.
- Automated finance, persistence and widget tests; CI analyzer + Android debug APK.
- CI-generated 1080×2400 Flutter UI preview PNGs for new screen visual review.
- **New in 0.4.0**: AES-GCM 256-bit at-rest encryption of the persisted portfolio under a PBKDF2-HMAC-SHA-256 (120k rounds) passphrase-derived key, with optional biometric unlock stash.
- **New in 0.4.0**: Real document attachments picked via `file_picker`, stored on device under `vault-attachments/`, AES-GCM encrypted at rest and decrypted into a temporary file for preview via `open_filex`.
- **New in 0.4.0**: Pure-Dart TWR (Modified-Dietz chain-link, annualized) and XIRR (Newton–Raphson) per asset, surfaced in Reports when enough history exists.
- **New in 0.4.0**: Offline FX reference table and dated UGX conversion with freshest-rate selection.
- **New in 0.4.0**: Target allocation weights and per-asset drift reporting.
- **New in 0.4.0**: Recurring scheduled contributions with a one-tap post-and-advance workflow.
- **New in 0.4.0**: Scheduled local OS notifications (via `flutter_local_notifications` + `timezone`) that derive their fire list from `computeScheduledAlerts` and resync after every state change. A `NoopNotificationScheduler` is used on web/test.
- **New in 0.4.0 (Phase 1+2)**: Shared component library (`AppPage`, `AppHeader`, `StepProgress`, `PrimaryCTA`, `SecurityNotice`, `StatusChip`, `MoneyField`, `DateField`, `PhoneField`, `confirmActionSheet`, `LoadingState`, `ErrorState`, `AppEmptyState`) in `lib/presentation/components.dart`.
- **New in 0.4.0 (Phase 1+2)**: `SplashScreen` (A01), canonical flat `CreateAccountStep1Screen` / `CreateAccountStep2Screen` / `OtpVerificationScreen` / `RecoverAccountScreen` prototype flow (A07/A08/A09/A10), three-step `PortfolioSetupScreen` (A12), and `NotFoundScreen` (J12) in `lib/presentation/onboarding_screens.dart`.
- **New in 0.4.0 (Phase 1+2)**: Visual export preview test now captures the new onboarding and 0.4 screens (step 1/2, recover, portfolio setup, not-found, unlock, encryption, allocation, FX, scheduled contributions).

## Not production implemented
- Authenticated remote accounts, passkeys, remote recovery, or protected multi-device access. There is no server-side key escrow for the passphrase.
- Encrypted cloud backup, financial-institution feeds, verified third-party valuations, live FX feed.
- Payment processing, subscriber billing and account entitlements.
- Certified accessibility, cross-device pixel matching, independent security review or signed release distribution.
- iOS release signing and TestFlight distribution.

IMPORTANT: use **only fictional demonstration data** until an independent security review has signed off on the local vault model. Attachments are encrypted on device, but the device itself remains the only backup — losing the passphrase makes encrypted data unrecoverable.
