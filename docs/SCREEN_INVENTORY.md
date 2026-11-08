# Screen inventory — Flutter 0.4.0

LonyoGang Heritage uses flat Material 3 Theme 1. All screen classes below render native Flutter widgets and reuse the same design tokens in `lib/core/design.dart` and the shared component library in `lib/presentation/components.dart`.

## Launch, onboarding and identity (lib/presentation/onboarding_screens.dart)
- A01 `SplashScreen` — real Flutter splash; loads the portfolio off disk and routes to the next state.
- A02 `WelcomeScreen` (in `app.dart`) — value proposition, `Create local portfolio`, `Explore with sample data`, `View account design preview`.
- A06 `SignInScreen` — email + password prototype with gated passkey tile; clearly labeled as a design preview, never verifies credentials.
- A07 `CreateAccountStep1Screen` — canonical flat Create Account prototype; collects name, email, mobile; terms gate; clearly labeled as a design preview with no backend.
- A08 `CreateAccountStep2Screen` — passkey & biometric option tiles, recovery contact, truthful "no server recovery" notice.
- A09 `OtpVerificationScreen` — six-digit entry with resend cooldown; design preview, never verifies against a real server.
- A10 `RecoverAccountScreen` — anti-enumeration recovery initiation; design preview until a backend exists.
- A12 `PortfolioSetupScreen` — three-step multi-stage setup (name → category picks → confirm); persists `ownerName` and `onboardingDone` via `PortfolioStore.setOwner`.
- J12 `NotFoundScreen` — fallback for unresolved deep links.

## Primary wealth overview (lib/presentation/screens.dart)
- B01 `HomeScreen` with search and alert icons.
- B03 `PortfolioScreen` with category chips.
- B06 `HomeRecentActivity` — three most recent non-reversed ledger entries on Home, tapping each opens `TransactionDetailScreen`.
- B04 `PortfolioSearchScreen` (in `wealth_screens.dart`).
- B05 `InvestmentOverviewScreen`.
- B08 `ArchivedRecordsScreen`.
- `AssetDetails` with property-equity subpanel.
- `AssetForm`, `LiabilityForm`, `EventForm` (in `forms.dart`).
- `DebtsScreen`, `TransactionsScreen`.

## Reports (lib/presentation/screens.dart, wealth_screens.dart, analysis_screens.dart)
- F01 `ReportsScreen` with new per-asset TWR/XIRR row via `ReturnsList` (tap-to-detail).
- F02 `WealthStatementScreen`.
- F04 `CashFlowScreen`.
- F05 `RentalIncomeScreen`.
- F06 `HistoricalTrendScreen` — dated net-worth snapshots synthesized from `wealthHistory`; honest Not-enough-history empty state.
- F07 `AssetPerformanceScreen` — per-asset TWR/XIRR with cashflow table and valuation sparkline.
- F08 `AllocationScreen` for target weights & drift.

## Planning, legacy, documents (lib/presentation/legacy_screens.dart, forms.dart, detail_screens.dart)
- G01 `GoalsScreen` — rows tap to edit.
- G02 `GoalForm` (full-screen) — add + edit flow with optional target date, saved-exceeds-target guard and destructive remove.
- G04 `BeneficiariesScreen`, `BeneficiaryFormScreen`.
- G06 `LegacyScreen` for trusted contacts, with a full-screen `ContactForm` add/edit flow. `LegacyContact` carries optional email + phone for reachability.
- G07 `DocumentsScreen` — rows tap to detail.
- G08 `DocumentFormScreen` — pure metadata editor (title, category, linked asset, dates, notes).
- G09 `DocumentDetailScreen` — landing with metadata card, attachment lifecycle (attach via `file_picker`, decrypt + preview via `open_filex`, SHA-256 integrity), Edit metadata CTA, Archive/Restore.
- G10 `ArchivedRecordsScreen`.

## Notifications, reminders (lib/presentation/legacy_screens.dart)
- H01 `NotificationsCenterScreen` derives alerts from state via pure-Dart `buildLocalAlerts`; rows tap to detail.
- H02 `NotificationDetailScreen` — shows source kind, detail, dated occurrence and an Open-source-record CTA that routes to the originating screen.
- H03 `NotificationPreferencesScreen` toggles reminder/document/stale rules; a `LocalNotificationScheduler` (lib/data/notifications.dart) schedules real OS notifications via `flutter_local_notifications`.
- H04 `RemindersScreen` (in `forms.dart`).

## Account, security, data (lib/presentation/legacy_screens.dart, security_screens.dart, analysis_screens.dart, account_screens.dart)
- I01 `MoreScreen` navigation hub.
- I02 `ProfileScreen`.
- I03 `SecurityCenterScreen` — now reports the live vault/biometric/notification state truthfully.
- I04 `NotificationPreferencesScreen`.
- I05 `SubscriptionScreen` (information only).
- I06 `SettingsScreen` for JSON import/export, demo load, destructive Reset portfolio and Data & sync status entry.
- I10 `runLocalReset` — destructive confirmActionSheet-gated reset invoked from Settings; calls `PortfolioStore.resetLocal` to clear every record, attachment and passphrase.
- I11 `DataSyncStatusScreen` — counts, last-saved timestamp, encryption state, Remote state (explicitly not connected), unencrypted-export reminder.
- `UnlockScreen` — gates the UI when a passphrase is set and the vault is locked.
- `EncryptionSetupScreen` — enables, re-links or removes the passphrase and biometric stash.
- `FxRatesScreen` — offline FX reference entries.
- `ScheduledContributionsScreen`, `ScheduleForm` — recurring contributions with one-tap post-and-advance.
- `SessionsScreen` (`lib/presentation/sessions_screen.dart`) — lists every device session, shows user-agent + opened/refreshed/revoked timestamps, revokes a session with a confirmActionSheet. Reachable from OnlinePrivacyScreen when an online session is wired.
- `PasswordResetCompleteScreen` (`lib/presentation/onboarding_screens.dart`) — closes the `/identity/password/reset/complete` loop inside the app, reachable from the RecoverAccountScreen "I already have a reset code" link.

## Entity detail routes (lib/presentation/detail_screens.dart)
- E02 `LiabilityDetailScreen` — outstanding balance, lender, linked property, edit + archive/restore with confirmActionSheet.
- E05 `TransactionDetailScreen` — ledger entry context, linked asset, reversal lineage, Reverse action gated by confirmActionSheet. Append-only invariants preserved.

## Shared component library (lib/presentation/components.dart)
`AppPage`, `AppHeader`, `StepProgress`, `PrimaryCTA`, `SecurityNotice`, `StatusChip`, `MoneyField`, `DateField`, `PhoneField`, `confirmActionSheet`, `LoadingState`, `ErrorState`, `AppEmptyState`, `ListHeaderRow`, plus pure-Dart helpers `isLikelyEmail`, `isLikelyName`, `isLikelyPhone`, `recordStatusChip`.

See `docs/REMAINING_SCREENS.md` for the feature map and `docs/IMPLEMENTATION_STATUS.md` for what is production-ready vs still gated.
