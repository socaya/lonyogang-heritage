# Flutter implementation status — 6 November 2026

## Implemented and committed

- Flutter/Dart source with Theme 1 flat UI tokens; responsive navigation and reused approved granary artwork.
- On-device account creation with local PIN gate, optional biometrics, vault lock, local profile updates and erase.
- Encrypted device-local SQLCipher database for assets, valuations, debts, transactions, beneficiary records, reminders and documents.
- User-controlled investment, property, savings and other-asset forms; full record CRUD, search and detailed valuations.
- Consolidated ownership-adjusted gross assets, linked mortgage equity, total debt, net worth, account allocation and dated cash-flow calculations.
- Explicit valuation date/source disclosure and stale estimate hints. No manufactured market rates or fabricated ROI.
- Encrypted document import, user-confirmed decrypted sharing, beneficiary/contact record management and in-app due-date reminders.
- Plain CSV export with explicit warnings that exported financial data leaves encryption.
- Automated domain tests, widget test and GitHub Actions native Android debug APK build workflow.

## Deliberately excluded until services are selected

- Cloud identities, email/SMS OTP, synchronized multi-device accounts, secure backup/recovery and server-side APIs.
- Live read-only bank, SACCO or investment integrations; official financial/product pricing or validation.
- Payment processing, subscription billing, custody, trades, advisory, property brokerage or official land registry verification.
- Automatic push notifications and web portal (in-app due-date list exists).
- Legally binding nomination or estate-transfer workflow; beneficiary records are informational.

## Before production release

- Independent security review, secure recovery and backup/restore protocol, OS keystore compromise analysis and key rotation.
- Financial correctness test suite with real-world fixtures, full ledger/reconciliation model, multicurrency FX policy, property income/ownership history and independent comparison.
- Android/iOS device-level screenshot QA against approved 6.7-inch modern designs; accessibility/large-text, low memory and offline tests.
- Privacy/retention and subscription terms, secure deployment, signing and store distribution.

## User interface source of truth

`docs/UI_DESIGN_SYSTEM.md` specifies layout and colours. Reference screenshots were provided separately to the design process; they are not guaranteed to be present in this public repository. Avoid reinterpreting them as heavily boxed finance UI. Android screenshot-diff acceptance is still outstanding.

The previous Expo source was removed from the active tree when Flutter became the selected stack; it is preserved in Git commit history.
