# Flutter implementation architecture

## Modules

- `domain/models.dart`: versioned persisted DTOs (schema 2, back-compat with schema 1), asset kinds, beneficial ownership basis points, append-only ledger events and reversal links, FX rates, scheduled contributions, target weights, and attachment references.
- `domain/finance.dart`: gross assets, debt, net worth and property equity; a pure-Dart Modified-Dietz TWR and Newton–Raphson XIRR; offline FX conversion that picks the freshest rate not newer than the as-of date; allocation drift versus target weights; due-schedule detection.
- `core/crypto.dart`: PBKDF2-HMAC-SHA-256 key derivation and AES-GCM 256-bit encryption primitives.
- `data/vault.dart`: metadata + lock state + session key cache; writes encrypted or cleartext payloads to `shared_preferences` depending on whether a passphrase is set; optional biometric stash.
- `data/portfolio_store.dart`: `ChangeNotifier` composing a Vault and AttachmentStore. All mutations go through the vault so that enabling a passphrase retroactively encrypts existing data.
- `data/attachment_store.dart`: encrypted-at-rest file storage under the app's private documents directory; SHA-256 integrity check on read.
- `data/notifications.dart`: pure-Dart `computeScheduledAlerts` plus a `NotificationScheduler` abstraction; `LocalNotificationScheduler` wraps `flutter_local_notifications`, `NoopNotificationScheduler` is used in web/test.
- `data/biometric.dart`: `local_auth` wrapper that degrades to "unavailable" on hardware without biometrics.
- `core/design.dart`: Theme 1 tokens and mobile typography, soft surfaces, restrained radius and semantic colours.
- `presentation/app.dart`: bottom navigation and home flow; gates the UI behind `UnlockScreen` when a vault is locked.
- `presentation/screens.dart`, `forms.dart`, `widgets.dart`, `wealth_screens.dart`, `legacy_screens.dart`: interactive portfolio and planning screens.
- `presentation/analysis_screens.dart`: target allocation, FX rates, scheduled contributions.
- `presentation/security_screens.dart`: unlock, passphrase set/change, biometric linking.

## Dual-sync (0.4 online path)

Two complementary channels fan writes out from the Flutter store to the
backend. Both carry the same AES-GCM content key — ciphertext bytes are
byte-identical across the channels — so consumers see a consistent view
regardless of which channel they read from.

- **`/sync/events`** — append-only log, ordered by `receivedAt`. Used
  for cross-device replay with a server-side cursor. `SyncOutbox`
  queues every mutation locally, then `RemoteSyncService.sync()`
  posts and pulls. `SyncReducer.apply` decrypts each pulled row and
  merges it into `PortfolioStore` in a single pass.
- **`/resources/:kind/:id`** — latest-state REST layer with per-kind
  listing, `expectedVersion` optimistic concurrency, and a tombstone
  flag for deletions. Written by `ResourcePublisher` alongside every
  outbox record; read by `ResourceHydrator` on a new-device install or
  on-demand from Data & sync status. Max ciphertext per row is ~350 KB
  of base64; writes are rate-limited to 120/min per account; reads to
  600/min (room for the hydrator's 12 back-to-back GETs).

The REST layer never decrypts `ciphertext`. The only plaintext the
server inspects is the small `integrity` map (`combined_bps`,
`ownership_bps`, `amount_ugx`) used for cross-field invariants, and
the per-device `prev_hash` chain the outbox and the reducer both
recompute.

## Accounting invariants

1. All UGX money is stored as integer units. Fractional currency, FX feeds and securities quantity precision need a separate decimal engine before launch.
2. Property owner value = current whole-property value × recorded economic ownership share (basis points / 10,000).
3. Net worth = all attributable current assets − all attributable outstanding debt; never property equity minus mortgage twice.
4. Manual property appreciation is not realized cash income. Event log entries do not automatically mutate current asset value.
5. Reversals append a separate event; original posted events remain accessible. Duplicate event IDs are ignored.
6. No TWR/XIRR claim is made without sufficient dated valuations and cashflows.
7. No third-party integrations, legal title checks or automatic beneficiary access are assumed.

## Production gaps (explicit release blockers)

Server-backed identity/passkeys/MFA and secure session lifecycle; per-user backend authorization; OS keystore integration (replace the device-scoped biometric wrap); encrypted backups with restore testing and cross-device recovery; external feeds with explicit user consent; live FX feed; statement reconciliation; immutable server audit; accessibility/localization/device QA at scale; threat modelling / pen test; subscription billing and legal review. See the original confidential SRS for requirements and acceptance criteria. Do not publish that SRS into a public GitHub repo.
