# LonyoGang Heritage

**Flutter / Dart personal wealth tracker** for Android and iOS — your home of wealth.

LonyoGang is a private, offline-first, owner-controlled record of investments, property, bank/SACCO savings, loans, income, financial position and legacy. The UI follows the approved **Theme 1** flat design; the Acholi granary identity is retained without chart bars or arrows.

## What works

This is a **real data-entry application, not a slideshow**:

- Create an encrypted device-local vault protected by an access PIN; optionally enable biometric unlock.
- Add, edit, search, archive and inspect investment, property, savings and other asset records.
- Record value, acquisition cost, date, ownership share, provenance and valuation history.
- Register and edit liabilities, link mortgages to the underlying properties and calculate property equity.
- Enter and edit dated income, expenses, contributions and withdrawals; see cash-flow totals.
- View owned assets, outstanding debt, consolidated net worth and allocation reports.
- Store beneficiary contacts, due-date reminders and **encrypted document attachments**.
- Export a plain CSV portfolio statement after an explicit disclosure confirmation; edit profile and erase local vault.
- Run Dart finance-domain tests and a Flutter widget test through GitHub Actions; build an Android debug APK.

Records start empty by design. **No demo numbers are presented as your actual wealth.** Dates, source and ownership percentages are explicitly recorded. Currency is currently UGX.

## Development

Requirements: Flutter stable **3.47+**, Dart SDK **3.10+**, Android SDK; Xcode/CocoaPods for iOS.

```bash
git clone https://github.com/socaya/lonyogang-heritage.git
cd lonyogang-heritage
bash tool/setup_platform.sh
flutter pub get
flutter analyze
flutter test
flutter run -d android
```

The `tool/setup_platform.sh` command generates standard Android and iOS host projects and inserts needed biometric platform configuration; Flutter source lives in `lib/`. On macOS, use `flutter run -d ios` with Xcode installed.

For an Android installer:

```bash
flutter build apk --debug
```

The GitHub [Flutter Android CI workflow](.github/workflows/flutter-ci.yml) executes analysis, tests and a debug Android build, then uploads the debug APK as a workflow artifact when successful.

## Design system

- **Background:** `#F7F9F7`
- **Midnight Navy:** `#102D40`
- **Antique Gold:** `#B88C3D`
- **Sage:** `#607E68`
- 24dp gutters, 14dp inputs, 18dp cards, low-chrome flat cards, readable hierarchy, native status/navigation bars.
- The 6.7-inch/1080 × 2400 approved screenshots are **visual acceptance references**; a full device screenshot-diff acceptance run remains required.
- Brand assets: `assets/brand/`; UI guidance: `docs/UI_DESIGN_SYSTEM.md`.

## Security and release boundaries

This implementation is **an encrypted local-device MVP**, not a production banking platform. The SQLCipher passphrase is kept in platform protected storage, and the local PIN is verified with a salted PBKDF2 check. Device biometrics provide optional unlocking. The PIN is an app-level unlock gate, **not independent cryptographic protection if the OS keystore has been compromised**. There is currently no server, cloud account, multi-device synchronization, cloud backup/recovery, live bank integration, live investment pricing, payment/subscription processing, legally valid nomination or official property-title verification. Exported CSV and shared document copies are **not encrypted**. Avoid storing irreplaceable information without your own backup strategy. Do not reuse real banking passwords in this app.

Before public release: threat model and security audit, recovery strategy, backup/restore, regulated-integration/compliance decisions, full accessibility and device-specific UI tests, code signing and App Store/Play Store readiness. See [Security](docs/SECURITY.md) and [Implementation status](docs/IMPLEMENTATION_STATUS.md).

**The full confidential v1.1 SRS is intentionally excluded from this public repository.** The previous React Native implementation remains available through Git history but is no longer the active mobile stack.
