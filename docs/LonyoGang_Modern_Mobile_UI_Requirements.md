# LonyoGang Heritage — Modern Mobile UI/UX Requirements
**Version:** 1.0 proposed redesign | **Date:** 24 November 2026 | **Platform:** Flutter / Dart, Android and iOS

## 1. Objective and scope
Transform the existing personal wealth and asset tracker into a calm, premium, flat fintech experience for Uganda. This is a presentation-layer modernization, not a bank, loan marketplace, payment wallet or investment advisory service. Preserve all existing functional workflows, domain calculations, storage, permissions, security boundaries and approved granary logo (HERITAGE below GANG). No fabricated financial data outside explicit demo mode. This specification proposes changes to the approved design system; obtain design approval before replacing reference baselines.

## 2. Research and repository assessment
| Reference | Evidence / lesson | LonyoGang application |
|---|---|---|
| [Walex Designs, Fiverr](https://www.fiverr.com/walexdesigns/design-fintech-loan-cash-app-ui-with-prototype) | Listing describes custom fintech UI, banking, investment and wallet flows; full gallery not independently inspected | Consistent flow design, readable hierarchy, branded reusable components; no borrowing/payment promotions |
| [Fintez, Fiverr](https://www.fiverr.com/fintez/create-lending-app-financing-microfinancing-app-pos-lending-app-p2p-lending) | Visual reference shows a balance-led dashboard, recent activity and progressive onboarding | One dominant financial figure; clear activity rows and staged setup |
| [Genesis508, Fiverr](https://www.fiverr.com/genesis508/design-fintech-and-banking-mobile-app-ui-ux-in-figma-ios-and-android) | Listing emphasizes reusable layouts, onboarding and confirmation; seller claims not independently validated | Component variants and explicit review/confirmation for sensitive actions |
| [Ronas IT, Dribbble](https://dribbble.com/shots/26823085-Fintech-Investment-Portfolio-Mobile-App) | Portfolio dashboard, instrument details and restrained accent colors | Asset-first hierarchy and detail drill-down |
| [Aakif Iqbal, Dribbble](https://dribbble.com/shots/27876529-Fintech-Mobile-App-UI-Design-Investment-Tracker-Bank-Flow) | Portfolio breakdown and reusable design tokens described | Shared chart and account-linking patterns, only where supported |
| [Cashly, Behance](https://www.behance.net/gallery/204840861/Cashly-Online-Loan-App-UI-Kit) | Broad screen system with bill and payment status | Consistent state vocabulary; reject gamification and loan marketing |
| [Flutter accessibility](https://docs.flutter.dev/ui/accessibility/ui-design-and-styling), [Apple HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility), [Material accessibility](https://m1.material.io/usability/accessibility.html) | Contrast, scalable text and touch-target guidance | 48 dp controls, contrast checks, assistive technology tests |

Repository reviewed: [README](https://github.com/socaya/lonyogang-heritage/blob/main/README.md), [design.dart](https://github.com/socaya/lonyogang-heritage/blob/main/lib/core/design.dart), [app.dart](https://github.com/socaya/lonyogang-heritage/blob/main/lib/presentation/app.dart), [screen inventory](https://github.com/socaya/lonyogang-heritage/blob/main/docs/SCREEN_INVENTORY.md), [approved design system](https://github.com/socaya/lonyogang-heritage/blob/main/docs/ORIGINAL_UI_DESIGN_SYSTEM.md). This is a static source review, not a device audit. README includes both early alpha limitations and later security/backend capabilities; verify actual runtime configuration before showing any capability as available.

| Observed baseline | Required change |
|---|---|
| LG theme, Material 3, 16 dp card and 14 dp input radii | Centralize role-specific radii, reduce visual weight; no blanket card treatment |
| Heading weights 800–900 | Use 600–700, reserve 700 for critical figures |
| 24 dp uniform gutters | 20 dp standard, 16 on compact devices, 24 on wide phones |
| Five-slot navigation with non-destination Add and empty IndexedStack child | Four persistent destinations, contextual Add action; preserve existing route access and tab state |
| Welcome exposes account design preview | Keep preview only in explicitly marked demo/developer mode; expose real account flow only when configured |
| Approved references and current tokens differ slightly | Keep actual LG palette as baseline and reconcile docs after approval |
| Existing inventory includes local and online workflows | Retain all; never conflate connection, vault lock, sync and backup status |

## 3. Visual system (normative)
### 3.1 Palette
| Role | Hex | Use |
|---|---|---|
| Brand navy | #102D3F | Main text, primary action, hero |
| Deep navy | #0C2738 | Pressed / dark brand surface |
| Antique gold | #B58A3A | Brand accents, non-text highlights |
| Gold soft | #F4EBD6 | Selected neutral surface |
| Sage | #62816B | Charts, supporting marks |
| Sage dark | #446B55 | Positive text |
| Canvas | #F7F9F7 | Screen background |
| Surface | #FFFFFF | Inputs / selective cards |
| Muted | #526570 | Secondary copy, proposed accessible replacement for #6C7D86 |
| Divider | #E5EAE7 | Sparse separators |
| Negative | #AB4E46 | Loss, destructive actions |
| Warning ink | #805510 | Pending/stale text |

Use navy on gold-soft rather than gold text on white. Verify actual foreground/background contrast (4.5:1 normal text, 3:1 large text, 3:1 essential non-text indicators). Never communicate status by color alone. No gradients, glass, neon, 3D illustrations, glowing controls, stacked cards, or decorative AI motifs. Keep approved logo asset intact; do not draw a substitute granary. Dark mode is a separate tested phase, not automatic inversion.

### 3.2 Typography
Use platform Roboto/SF system fonts or a single licensed bundled family after approval. No mixed ornamental fonts. Enable tabular numerals for aligned figures (`FontFeature.tabularFigures()`).
| Role | sp / line height | Weight |
|---|---|---|
| Hero value | 34 / 40 | 700 |
| Page title | 28 / 34 | 700 |
| Section title | 19 / 25 | 600 |
| Row title | 16 / 22 | 600 |
| Body | 15 / 22 | 400 |
| Secondary | 13 / 19 | 400 |
| Navigation | 12 / 16 | 600 |
| Button | 15 / 20 | 600 |
No truncation of amounts, dates or critical labels; use wrapping and adaptive layout, not forced shrinking below readable size. Show exact full amounts on details and confirmation.

### 3.3 Geometry and controls
4 dp base, spacing 4/8/12/16/20/24/32/40. Standard horizontal padding 20; compact 16; wide 24. Screen section separation 24–32. Rows min 56, two-line rows 64–72. Touch targets >=48 dp both platforms. Primary button min 52 dp; inputs min 52 dp, grow for text scale. Radius: button/input 10, functional card 12, sheet 16, avatar circular only. Elevation zero except modal separation when necessary. Icons 22–24 dp, consistent outline/filled selected variants. Native safe areas, keyboard insets and system bars; no painted fake status bars. No horizontal scrolling except deliberately labeled charts or category controls with alternatives.

## 4. Navigation and page anatomy
Home | Portfolio | Reports | More. Add is an action, not a selected destination; put it in contextual toolbar or reachable bottom action on Home/Portfolio. Maintain back stack and scroll position per tab. More groups Planning, Records, Account & security, Help. Global search indexes permitted records only. Use a top title and optional back/action row, content on a shared grid, one primary CTA. Lists use dividers and whitespace instead of cards per item. Full-screen forms for multi-field tasks; sheets for short selection and confirmation. Respect system back and warn on unsaved changes.

## 5. Screen-by-screen requirements
| Screen family / existing class | Required composition and behavior |
|---|---|
| Splash / Welcome / PortfolioSetupScreen | Approved brand, concise value proposition, local setup and explicit sample mode; explain vault and online availability; named stages with progress and Back |
| SignIn / CreateAccountStep1/2 / OTP / RecoverAccount / PasswordResetComplete | Persistent labels, password visibility, autofill, accessible errors, resend state, non-enumerating recovery; actual backend only when wired; no pretend verification |
| UnlockScreen / EncryptionSetupScreen | Minimal locked page; biometrics only if enrolled, passphrase fallback; explain recovery limitations before activation; never show wealth before unlock |
| HomeScreen | Header + search/notifications; one net-worth hero with privacy toggle, as-of context; assets and liabilities pair; category breakdown; recent activity; Add record; no artificial growth figures |
| PortfolioScreen / PortfolioSearchScreen | Total holdings, search, category filter with accessible selected state, sort; rows show name, type, value, date and status when necessary; filters persist, clearable; no duplicated summary cards |
| InvestmentOverviewScreen / AssetDetails | Value, valuation source/date, currency, change only with evidence, linked ledger and documents; property share and equity separate; archive/restore and edit via menu |
| AssetForm | Type-specific sections; name, ownership share, value, currency, valuation source/date; numeric keyboard; validation; optional advanced fields collapsed only if discoverable; save with error recovery |
| DebtsScreen / LiabilityDetailScreen / LiabilityForm | Outstanding principal, lender, linked property, due date where present; no loan offers; validate positive balance and relationship; do not double count mortgage |
| TransactionsScreen / TransactionDetailScreen / EventForm | Date groups, signed amounts, event type and linked asset; show reversal lineage; append-only reversal confirmation; distinguish recorded event from money actually moved |
| ExpensesScreen | Period total, category breakdown, expense rows, search/filter; preserve existing expense classification; no inferred cash flow beyond actual recorded data |
| ReportsScreen / WealthStatementScreen | Reports hub with net worth, holdings, cash flow, returns, allocation; statement as-of date, signed amounts, exact values, export disclosure |
| CashFlowScreen / RentalIncomeScreen | Period selector, income/expense/net, dated event list, property filter, explain scope; no fake yield |
| HistoricalTrendScreen / AssetPerformanceScreen | Actual dated observations; time range; accessible table alternative; TWR/XIRR labeled and unavailable reason; no interpolated fake history |
| AllocationScreen | Actual vs target in labeled bars, drift, explicit denominator, edit targets and validate total; avoid donut if categories unreadable |
| GoalsScreen / GoalForm | Goal name, saved/target, remaining, target date, progress bar; support exceeded target without clipping; no promise of returns |
| ScheduledContributionsScreen / ScheduleForm | Next due, amount, cadence, post-and-advance action; distinguish reminder from actual transfer |
| LegacyScreen / ContactForm / BeneficiariesScreen / BeneficiaryFormScreen | Trusted contacts and intended beneficiaries as separate concepts; clarify intentions not legally executed inheritance; consent and restricted details |
| DocumentsScreen / DocumentFormScreen / DocumentDetailScreen / attachments block | Searchable list, linked asset, expiry, metadata, actual encrypted attachment state, integrity/error feedback, preview/open/share with privacy disclosure |
| ArchivedRecordsScreen | Type filter, archive date, restore action, explain archived values excluded according to domain rules |
| NotificationsCenterScreen / NotificationDetailScreen / NotificationPreferencesScreen / RemindersScreen | Group by date, unread and meaningful alert states; source link; permission denial fallback; no duplicate reminder rows |
| MoreScreen / ProfileScreen / SettingsScreen | Grouped settings rows, owner profile, privacy, data, billing, help; avoid promotional dashboard; protect reset with explicit confirmation |
| SecurityCenterScreen / OnlinePrivacyScreen / OnlineAccountScreen / SessionsScreen / TOTP enrol | Display live capability and session state; reauth destructive changes; recovery codes never in logs or screenshots; revoke session feedback |
| DataSyncStatusScreen / FXRatesScreen / TransparencyScreen / BankProvidersScreen | Separate local saved, pending, synced, failed and stale; source/as-of FX; actual audit verification; provider unsupported or disabled state; no fictional bank linking |
| SubscriptionScreen / About / Help / NotFoundScreen | Truthful plan and quota from backend when configured, support contacts from configuration only; navigable recovery path |

## 6. Financial presentation and local context
UGX whole-shilling integers, comma grouping, full form `UGX 320,000,000`; compact `UGX 320.0M` only in summaries with accessible exact value. Date `24 Nov 2026`; timezone Africa/Kampala for local dates, stored timestamps remain canonical. Display asset total minus outstanding liabilities once. Show gross property value, ownership-adjusted value, linked debt and equity distinctly. Do not treat transaction log as current valuation. Percent changes require comparable dated points and defined denominator. Unknown is not zero; no data is not a loss. FX conversion must display reference rate/source/date and stale status. Charts require accessible summaries, no 3D, maximum 5 distinct segments before grouping, labels/legend and non-color cues. Sample concept figures: assets UGX 390M, liabilities UGX 70M, net worth UGX 320M; all mockups explicitly labeled sample.

## 7. Component contracts
Centralize LG tokens and text styles; reuse or evolve AppPage, AppHeader, PrimaryCTA, MoneyField, DateField, PhoneField, LoadingState, ErrorState, AppEmptyState, confirmActionSheet. Add shared MoneyText (exact/compact/masked), NetWorthHero, SummaryPair, FinancialRow, AllocationBar, SectionHeader, PrivacyToggle, SyncStatusRow, FormSection, ChartSummary and accessible filter controls. Every component must handle disabled/loading/error/focus/pressed states where applicable. Avoid nested interactive targets and nested cards. Prefer existing Flutter widgets and domain selectors; no new dependencies without justification. Use list builders and stable keys; preserve state on navigation. Do not bake screen PNGs into production UI.

## 8. Interaction and state requirements
- Loading: skeleton only for expected content, no fake figures; local data render immediately where available.
- Empty: explain why and offer appropriate create/import action; no automatic sample data.
- Offline: retain allowed local workflows, show last saved/synced distinctly, queue only existing supported operations; do not claim cloud backup.
- Error: inline field errors, screen retry for retrieval, preserve input, actionable messages, no raw exceptions.
- Submit: disable duplicate tap while pending, await result, show success only after confirmed persistence; use existing idempotency where supported.
- Privacy: mask all visible monetary values when enabled, including accessibility labels and charts; persist preference securely as appropriate; avoid sensitive notifications, logs and previews. Re-lock according to existing policy.
- Archive/reversal/reset: show consequences and affected record, require confirmation; preserve existing authorization and audit invariants.
- Motion: 150–220 ms restrained transitions; reduced-motion support; no animated amounts that misrepresent data.

## 9. Flutter delivery plan
1. Baseline: inspect `CLAUDE.md`, existing UI requirements, implementation status, remaining screens, assets, tests and actual runtime routes. Inventory every screen and capture current device screenshots. Reconcile conflicting docs; do not delete old approvals.
2. Foundation: update `lib/core/design.dart`; consolidate `lib/presentation/components.dart` and `widgets.dart` via adapters; add golden and semantic tests. Preserve public APIs until migration complete.
3. Shell: refactor `app.dart` navigation, creation sheet and onboarding; maintain unlock gating and route reachability; preserve online session handling.
4. Core: modernize `screens.dart`, `wealth_screens.dart`, `detail_screens.dart`, `forms.dart`, `expenses_screen.dart`; test CRUD, archive/restore and ledger reversal.
5. Analysis: update `analysis_screens.dart` and report screens; verify exact totals, FX, historical gaps and return calculations against domain fixtures.
6. Heritage and settings: update `legacy_screens.dart`, `attachments_block.dart`, account/security/online/session/TOTP/transparency/provider screens. Preserve encryption, deletion, consent and permissions.
7. QA: responsive and device tests, screenshots, accessibility, performance, security regression; update `docs/UI_QA.md`, screen inventory and design system. Do not mark complete solely because compilation succeeds.

## 10. Acceptance criteria and test matrix
| ID | Acceptance gate |
|---|---|
| UI-01 | All reachable routes inventoried; existing workflows remain reachable and functional; no duplicate or orphan screens |
| UI-02 | 320, 360, 390, 412 and 430 logical widths; portrait and landscape; no overflow or unintended horizontal scroll |
| UI-03 | Text scale 1.0, 1.3, 2.0; TalkBack/VoiceOver reading order and labels; >=48 dp touch targets; contrast verified |
| UI-04 | Golden screenshots for Home, Portfolio, detail, form, reports, goals, More, unlock and empty/error/offline states; approved baseline comparison |
| UI-05 | Sample data only opt-in; 390M - 70M = 320M; property debt counted once; archive/restore and reversal tests pass |
| UI-06 | No unsupported network features presented as live; offline, timeout, expired session and sync conflict states tested |
| UI-07 | No sensitive data exposure when locked or masked; actual attachment and recovery behavior preserved |
| UI-08 | Form validation, keyboard navigation, date/amount input and double-submit prevention tested |
| UI-09 | Profile-mode scroll and transition performance measured on representative low/mid-range Android and iOS; target 60 fps where device permits, document results |
| UI-10 | Run `flutter pub get`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`, and device integration tests where available; report actual outputs and blockers |

## 11. Claude implementation instruction
Act as a senior Flutter engineer and fintech UX specialist. Read this document and repository guidance, inspect actual implementation before modifications, and create a route-to-requirement traceability checklist. Implement phases sequentially, migrating shared components rather than building disconnected mock screens. Preserve brand assets, domain/storage/security behavior and all existing working routes. Do not introduce fake endpoints, hardcoded balances, unsupported account capabilities, or placeholder actions. Run local tests after each phase and fix regressions. Produce before/after screenshots, test evidence, list changed files, and record any remaining blockers. Do not declare production readiness without security and device verification. Commit only when explicitly authorized; this specification does not authorize repository mutations.

## 12. Companion concept screens
`LonyoGang_Mobile_UI_Concepts.html` is a standalone responsive visual prototype using illustrative data and a typographic wordmark placeholder. It is not the existing app or approved logo asset; replace the placeholder with the repository's approved brand asset during Flutter implementation. Screens demonstrate Home, Portfolio, Property detail, Add asset, Reports and More. Layouts are proposals for review, not evidence of implemented functionality.


## Mandatory authentication separation (supersedes earlier sign-in layout)

- A06 accepts email and password only. No OTP or authenticator field on this screen. Primary action: Continue.
- Validate primary credentials on the server; issue a short-lived, restricted pre-authentication challenge, not a usable account session. Route directly to the enrolled verification method or A06a if multiple server-approved methods exist.
- A06b is a dedicated authenticator (TOTP) screen with a six-digit numeric input, paste support, accessible label, invalid/expired code feedback and alternate method only if policy allows. No resend for TOTP.
- A06c is a dedicated sign-in OTP screen with masked delivery destination, six-digit input, resend cooldown and server-controlled expiry/attempt limits. Never offer email/SMS fallback if not enrolled and supported.
- Only successful server-side second-factor verification creates a full session and permits access to protected routes. Require verification for online password sign-in; if no eligible factor exists, use an approved enrollment/recovery flow rather than bypassing verification.
- Cancel/back clears the challenge and returns to sign-in; expired challenges require fresh primary authentication. Prevent replay, rate-limit attempts/resends, avoid account enumeration, do not log secrets or codes, and do not persist passwords across screens.
- Preserve account-registration verification (A09/I14), authenticator enrollment (I17), password recovery and local vault unlock as distinct workflows.
- Audit backend identity endpoints and implement a two-stage challenge contract if the existing endpoint expects password and TOTP in one request. Do not simulate successful authentication or merely hide a field while issuing a full session early.
- Tests: wrong password cannot reach challenge; correct password cannot reach protected resources before factor success; wrong/expired/replayed code fails; cancellation invalidates challenge; resend is limited; unsupported factors are not offered; successful verification opens the intended authenticated destination.
