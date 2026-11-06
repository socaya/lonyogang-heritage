# LONYOGANG HERITAGE
## Claude Code — Complete Flutter/Dart UI Implementation Requirements

**Document ID:** LGH-UI-CLAUDE-001  
**Version:** 1.0 | **Date:** 6 November 2026  
**Project:** `https://github.com/socaya/lonyogang-heritage`  
**Primary platform:** Flutter/Dart (Android and iOS)  
**Visual baseline:** Approved **modern flat UI**, Theme 1 — Midnight Navy, Antique Gold and Sage  
**Reference device:** 6.7-inch Android portrait; 1080 × 2400 screenshot baseline (not a fixed logical-pixel layout)  
**Status:** Implementation specification; authoritative for UI, not evidence of production security or completed external integrations.

---

## 1. Instructions to Claude Code: read and execute

You are the **senior Flutter engineer, product UI designer, accessibility specialist and QA engineer** responsible for implementing all LonyoGang Heritage application screens. Work in the existing repository **in place**. Do not scaffold another app, reintroduce React Native, build screenshot-only pages, or replace approved UI with an unrelated design template. Produce code, integration, tests, screenshots and a verifiable commit. **Do not consider a screen complete because its class exists.** It must satisfy the relevant screen requirements, support its claimed actions, and pass visual and functional acceptance.

Before changing code, read these files (when present):

1. `README.md`, `pubspec.yaml`, `lib/main.dart`
2. `lib/core/design.dart` (design tokens)
3. `lib/presentation/app.dart`, `screens.dart`, `forms.dart`, `widgets.dart`, `wealth_screens.dart`, `legacy_screens.dart`
4. `lib/domain/models.dart`, `lib/domain/finance.dart`, `lib/data/portfolio_store.dart`
5. `docs/ORIGINAL_UI_DESIGN_SYSTEM.md`, `docs/UI_QA.md`, `docs/SCREEN_INVENTORY.md`, `docs/REMAINING_SCREENS.md`, `docs/SECURITY.md`
6. All relevant image references in `assets/reference/screens/` and original branding under `assets/brand/`.

**Non-negotiable:** use the user-approved flat **Create your account** screen as the highest-priority visual authority. It has the soft off-white background, 24dp content gutters, compact logo, strong but restrained title, left-aligned text fields, understated two-step progress line, pale-sage security notice, one deep-navy CTA, and generous whitespace. In a conflict between older generated image mockups and this screen, **the approved flat screen wins**. Match each other reference only where it does not contradict that design system.

### Definition of done

- Every screen listed in Section 7 is implemented, integrated into discoverable navigation, and has correct empty/loading/error/success states as applicable.
- Forms validate and persist through the existing domain/store interface; no deceptive dummy success, hard-coded fake portfolio balance or unconnected primary action.
- All pages use actual Flutter widgets. A PNG may be shown **as a documented design reference**, brand image, or legitimately supplied content, but **never as the interactive screen**.
- Consistent layout, typography, spacing, brand, safe areas and bottom navigation on Android and iOS.
- `flutter analyze`, `flutter test`, Android debug build and automated visual regression tests pass. Include meaningful manual QA evidence for 6.7-inch devices.
- Existing financial and privacy invariants are preserved; code stays backward compatible with current sample portfolios.
- Changes are committed with a concise report of the actual implemented screens, automated checks, screenshots, known limitations and git commit SHA.

---

## 2. Approved design authority and branding

### 2.1 Primary reference hierarchy

| Rank | Authority | Required treatment |
|---|---|---|
| **1** | User-approved flat Create Account image (provided as `download.png` in design conversation; if not present in the repo, add it under `assets/reference/screens/approved-flat-create-account.png`) | Governs general layout density, geometry, typography, flat surfaces, page hierarchy and spacing |
| 2 | `assets/reference/screens/LonyoGang_Modern_Screen_06_Create_Account.png` | Registration composition reference, subordinate to rank 1 |
| 3 | `assets/reference/screens/LonyoGang_Modern_Screen_08_Secure_Account.png` | Security flow, two-step progress, pale-sage messaging |
| 4 | `assets/reference/screens/LonyoGang_Theme1_10_Portfolio_Setup.png` through `LonyoGang_Theme1_19_Reports_Insights.png` | Content hierarchy, information architecture and category presentation, restyled where needed to match rank 1 |
| 5 | Existing reusable Flutter widgets and Material 3 defaults | Use only where they support, not override, the higher references |

Do not use the earlier large-logo, thick-outline, grass-wave, cartoon or gradient onboarding layouts as the production design. Do not mix 3D illustrations or glossy buttons into the approved flat UI.

### 2.2 Brand assets: do not redraw

- Use the existing **Acholi granary** mark from `assets/brand/theme1-granary.png` and the approved primary arrangement from `assets/brand/theme1-primary.png`.
- Preserve the authentic layered thatch, woven granary wall, tied posts, footings and ground line. The chosen master should **not acquire decorative financial bars or arrows inside the granary**.
- **LONYO** is Midnight Navy; **GANG** is Antique Gold. **HERITAGE** sits **directly below GANG** (not centered below the whole wordmark), and its full visual span must align with the GANG letter span. Place the fine Antique Gold divider in the approved position.
- Make one reusable responsive `LonyoGangBrand`/`BrandMark` component with `compact`, `standard` and `hero` variants. Reuse the same master image where appropriate; never rebuild the icon differently on different screens.
- The wordmark must be readable at small sizes; when space is insufficient use the icon-only mark with an accessible brand label, **not squashed or incorrectly aligned text**.
- Leave clear space around the icon. Never stretch the logo to fill a card, clip its roof or substitute an invented home/chart pictogram.

### 2.3 Primary palette — Theme 1

Centralize all colors in `lib/core/design.dart`; remove stray hard-coded brand colors from individual screens.

| Token | Hex | Recommended use |
|---|---|---|
| `navy` | `#102D3F` | Headings, major totals, primary CTA backgrounds, navigation foreground |
| `navyDeep` | `#0C2738` | Secondary strong contrast; a few dark surfaces |
| `antiqueGold` | `#B58A3A` | Small premium accents, progress mark, active arrow, emphasized links |
| `sage` | `#62816B` | Positive/contextual accents, trust markers, selected filters |
| `sageDark` | `#446B55` | High-contrast text on pale sage |
| `sageSoft` | `#EAF0EB` | Informational and privacy surfaces |
| `canvas` | `#F7F9F7` | Default app background |
| `white` | `#FFFFFF` | Input surfaces and simple content surfaces |
| `surfaceSoft` | `#F0F4F1` | Secondary containers / quiet highlights |
| `hairline` | `#E5EAE7` | **Inputs or necessary separators only**; not card outlines |
| `ink` | `#163246` | General body copy where a lighter tone than navy is useful |
| `muted` | `#6C7D86` | Context and supporting labels |
| `negative` | existing `LG.negative` (`#AB4E46`) | Debts, errors, overdue values; no alarming large red panels |

Use **solid** colors (no gradients). Avoid saturated lime, bright yellow, neon green, gold-dominated containers, large tinted backgrounds and black shadows. Gold is a **controlled accent**, not a universal text or button color.

### 2.4 Typography hierarchy

Use a consistent system font or approved locally bundled font; preserve the native text metrics of the reference. Do not load unspecified font files from the internet or embed font binaries from this conversation.

| Element | Baseline Flutter logical size | Weight / treatment |
|---|---|---|
| Page display title | 28–32sp | Bold / 750–800, compact leading |
| Header/subsection | 18–21sp | 700–800 |
| Financial hero value | 30–36sp | Bold, tabular numerals where practical |
| List item title | 14–16sp | 600–700 |
| Body text | 14–16sp | 400–500, line height 1.35–1.55 |
| Form label | 13–14sp | 600–700 |
| Supporting text | 12–13sp | muted, readable contrast |
| Eyebrow / step label | 11–12sp | uppercase only sparingly, letter spacing ~1.0–1.5 |
| Main CTA label | 15–17sp | 700, white on navy |

Do **not** make every section heading 28sp. No text should overflow with larger accessibility font scaling. Use correct currency grouping and right-aligned values where comparing amounts.

### 2.5 Layout geometry and sizing

- **24dp** horizontal page gutters on a typical phone; safe-adapt to narrower widths while maintaining at least 16dp. Main page content and headers share the same leading edge.
- Base spacing: **4/8/12/16/24/32/40dp** only. Default gap between form fields: 18–22dp; sections: 24–32dp; major stage changes: 32–40dp.
- Main action height **52–56dp**; radius **12–14dp**. Use a meaningful verb and optional discreet gold arrow at trailing edge.
- Standard white surfaces radius **12–16dp**, borderless. Informational sage panels radius **14–16dp**. Input fields radius **12–14dp**, **very thin** light-grey line or minimally filled state. Pills may be fully rounded.
- Keep icons simple, preferably line icons in Navy/Sage; baseline icon size 18–24dp; minimum interactive touch area 44×44dp (prefer 48dp).
- **One dominant primary action** per screen. Secondary actions are muted text buttons, toned surfaces or outline-free alternatives.
- Keyboard interactions must scroll the focused input into view; the CTA must not be covered by the keyboard. Do not use a fixed pixel layout measured from the PNG.
- Use `SafeArea`, proper status/nav bars, Android edge-to-edge insets, and `NavigationBar` with unobtrusive selected indicator. **Never paint fake Android status bars as page artwork**.
- Design for a 6.7-inch Android 1080×2400 screenshot **and** compact Android devices, large text, tablets, and iPhone safe areas.
- Financial hero may use **one** deep-navy filled surface. Other cards should generally be white or pale-sage with no elevation.

### 2.6 Absolute UI anti-patterns (reject in review)

1. Thick dark borders, full-frame card borders, row-by-row framed boxes or raised shadows on every component.
2. Universal huge corner radii, giant oversized logos, disproportionate page headers or button capsules unrelated to the reference.
3. Finance illustrations, cartoon coins, upward arrows in the **granary icon**, grassy wave footers, glossy gradients, 3D effects or decorative background shapes.
4. Inconsistent alignment between brand, heading, form labels, hero totals, CTA and bottom navigation.
5. Too much information jammed above the fold; tiny font substitutions instead of natural scrolling.
6. Multiple equally prominent CTAs, hard-coded fake account statuses, placeholder handlers or dead-end pages.
7. Mock finance growth returns represented as live results, false security success claims, or simulated payment completion.
8. Rendering entire PNG mockups as page backgrounds or copying the image into a giant single `Image` widget.

---

## 3. Responsive page archetypes and reusable Flutter components

Before expanding individual pages, create or refine reusable components in `lib/presentation/widgets.dart` (or organized `components/` files), keeping `lib/core/design.dart` as the token authority:

| Archetype / component | Required behavior |
|---|---|
| `AppPage` / `PageScaffold` | SafeArea, responsive horizontal gutters, surface background, status-bar brightness, keyboard-aware vertical scrolling |
| `AppHeader` | Back button at left, optional `step X/Y` pill at right, compact brand as shown on approved account page |
| `LonyoGangBrand` | Original granary; HERITAGE precisely below GANG; compact/standard/hero variants |
| `PageHeading` | Title + short supporting sentence with reference-aligned positions and vertical rhythm |
| `StepProgress` | Two-step thin gold and pale-grey progress segments for account/security, no fat pills |
| `FormFieldBlock` | Accessible label, helpful text, input decoration with **light** border, error underneath, native keyboard types |
| `PhoneField` | Country code dropdown (initial Uganda `+256`), usable international dialing format, no fake identity verification |
| `MoneyField` | Numeric validation, visible UGX currency and normalized integer amount; reject negative/overflow/invalid user input |
| `DateField` | User-friendly date selection with bounds and accessible tap targets |
| `SelectionRow` / `ChoiceChip` | Selected state communicated by color, label and check icon; no gold outline around full card |
| `SoftSurface` | Flat filled white/sage neutral with subtle radius, no shadow or thick border |
| `SecurityNotice` | Shield outline icon, pale sage background, explicit truthful status text |
| `FinancialHero` | Dark-navy overview, current as-of date, attributable asset/debt positioning, optional privacy visibility toggle |
| `WealthComposition` | Accurate category totals and labels, no invented time series; chart includes accessible tabular alternative |
| `FinancialListRow` | Icon/label/subtitle left, amount/status right; optional chevron; deterministic spacing |
| `StatusChip` | `Estimated`, `User-entered`, `Stale`, `Overdue`, `Archived` with semantic color and text |
| `EmptyState` | Helpful explanation plus **working** relevant action (not illustration-heavy placeholder) |
| `ErrorState` | Localized human-readable error, retry and preserved form values |
| `LoadingState` | Quiet progress indicator/skeleton only when actual async work occurs |
| `ConfirmActionSheet` | Destructive import, archive, reversal, logout, removal; explicit consequence and cancel path |
| `PrimaryCTA` | Navy, 52–56dp, modest radius, optional gold arrow, disabled/loading states |
| `PageBottomNav` | Home / Portfolio / Add / Reports / More; centered Add triggers a contextual action sheet, not an inert tab |
| `Toast/Snackbar` | Concise after-confirmation feedback; only claim success when store call completes |

**Implementation guidelines:** Use strongly typed widgets; prefer semantic `ColorScheme` + theme extensions over repeated literals. Avoid overengineering state management unless there is a functional need. Existing `PortfolioStore` (`ChangeNotifier`), models and finance services are the baseline; migrate deliberately rather than duplicating data logic inside widgets.

---

## 4. Domain, security and data-integrity requirements for UI

These are **requirements**, not merely visual suggestions. Apply them to all screens and tests.

- **Net worth = sum of owner-attributable current assets − sum of outstanding liabilities.** Property full market value is multiplied by ownership fraction; linked mortgage is deducted **once**, not twice.
- Preserve an explicit distinction among *market value*, *owner-attributable value*, *original cost*, *property equity*, *cash income*, *unrealized appreciation*, and *net worth*.
- Save monetary UGX amounts as whole integers in the current domain; do not introduce double-based stored UGX amounts. For unsupported multiple currencies, show `not yet supported` rather than false converted totals.
- Each asset shows valuation **as-of date**, source and status (`estimated`, `user-entered`, etc.). Warn if stale. Do not call self-reported values verified/certified.
- Manual transaction events are append-only; a reversal writes a compensating event and preserves the original. Distinguish contributions from returns, transfers from income, rental receipts from appreciation.
- No chart may fabricate a growth trend from just one current value. Show `Not enough history` until sufficient dated data are available. TWR / XIRR must show unavailable if uncomputed.
- Document screens **currently store metadata only**. Do not offer fake upload, OCR, preview or encrypted vault features.
- Beneficiary entries are non-binding intentions. No actual legal property transfer or account access is implemented.
- Existing preview storage uses `shared_preferences` and plain JSON export: disclose that it is **not encrypted** and use fictional data only. Do not show a functional biometric/passkey sign-in until real integration exists.
- Financial account connections, verified valuations, notifications pushed to device, subscription billing and cloud backup are **not currently integrated**. Either implement the end-to-end service with security tests and clear consent or show a truthful non-transactional information state. Do not impersonate a successful integration.
- Avoid embedding real personal names, real account numbers, identity numbers, credentials or confidential SRS content in the public repository or seed dataset.
- Preserve existing versioned JSON imports with backward compatibility and explicit validation. Never silently wipe user data during navigation or schema migration.

---

## 5. Navigation and state architecture

**Bottom navigation (post-onboarding):** Home | Portfolio | Add | Reports | More. The Add action opens a short bottom sheet of supported creation flows without changing the active tab. Preserve the selected tab when returning from a detail page.

**Full pages:** Use full-screen route navigation for multi-field forms, asset details, property valuation, ledger details and settings. Use bottom sheets for **short single decisions**, filters, item actions and confirmation menus. Do not stack modal-on-modal workflows.

**Navigation implementation:** Define named routes or a typed router map; eliminate ad-hoc inconsistent pushes. Deep links should resolve only to authorized local entities and show a graceful not-found state if deleted/archived. Back navigation returns to the originating page with its scroll/filter state retained.

**Screen state contract:** every screen with data must handle `initial/empty`, `populated`, `loading` (if async), `error`, `success`, `stale/offline` where relevant, `archived/hidden` where relevant, and `large list` states. Persist filter/selection across local navigation when appropriate, but do not persist secrets. Use `ValueListenableBuilder`, `AnimatedBuilder` or existing store listeners to react immediately to edits.

**Lifecycle:** Unsubscribe/dispose controllers, check `context.mounted` after asynchronous operations, manage app lifecycle and keyboard focus correctly. Do not call network or storage writes directly from `build`.

---

## 6. Global UX patterns

### 6.1 Registration / onboarding

The approved registration page uses: real system status area → back arrow → small step pill (`01 / 02`) → compact icon+wordmark → main heading → concise subtitle → `ACCOUNT DETAILS` + thin two-segment progress → labels+subtle white inputs → pale-sage `Private by design` notice → legal links → navy `Continue` → muted Sign In. **Repeat this flat pattern** for security steps, not the older oversized illustration style.

### 6.2 Lists, filters, details

- List page: 28–30sp title, brief subtitle, contextual segmented filters/search, summary metric, rows of white fill and minimal dividers.
- Detail page: asset name/status + attributable value + `as of` / source, then organized attributes and related actions, not every field jammed in a single grey outlined frame.
- Creation page: one column of labeled inputs, focused grouping and one bottom anchored or trailing primary action; no unnecessary field icons.
- Tooltips and inline helper text for finance terminology, especially *economic ownership*, *property equity*, *realized income*, *net worth*.
- Show `UGX 0` intentionally, never blank where zero is a real value. Negative values display explicit sign; no green label for a loss.

### 6.3 Confirmations and feedback

- Archive/restore changes retain history; an archive is not deletion.
- Reversal requires irreversible-event explanation and optional reason, then append-only outcome.
- Import/export warns before exposing unencrypted data; import shows a **preview** of record counts and replacement scope before commit.
- Avoid success messages before actual persistence completion; provide actionable errors and an accessible retry where safe.

### 6.4 Account gating

The **local demo portfolio** may be used without pretending to have a server account. The future sign-up / OTP / passkey flow should remain a visually complete, properly labeled **design/prototype flow** until backend services are connected. Do **not** set a `verified` flag by tapping an illustrative button or imply that a passkey was created.

---

## 7. Complete screen and workflow inventory

Every item below requires a functional, navigable implementation or an explicit, truthful gated state where a production service does not yet exist. **Existing class** means code may be present; it does **not** waive visual or functional acceptance.

### A. Launch, onboarding, identity and access

| ID | Screen | Required UI / behavior | Existing or target |
|---|---|---|---|
| A01 | Splash / launch | Original granary logo; readable wordmark; clean off-white canvas; load current local portfolio, no decorative illustration; move to right state | Refine/new |
| A02 | Welcome / intro | Premium concise value proposition on assets, status, net worth and legacy; `Get started` or `Explore sample`; no pseudo live banking | `WelcomeScreen` refine |
| A03 | Intro: all wealth | Property + investments + savings scope; minimal editorial layout, skip/next controls | Optional first-run informational route |
| A04 | Intro: position | Clear financial standing, net worth and liabilities; avoid imaginary charts | Optional first-run informational route |
| A05 | Intro: heritage | Long-term assets, continuity and legacy message; no false estate-service claims | Optional first-run informational route |
| A06 | Sign in | Email/password or real configured passkey options; forgot password; no pretend authentication | Future/backend-gated design |
| A07 | Create account step 1 | **Exact canonical flat reference**: full name, email, mobile country code, terms, step `01/02`, security panel | Canonical reference |
| A08 | Create account step 2 | Same alignment; passkey concept, recovery contact, progress `02/02`, truthful preview gating | Security reference / refine |
| A09 | OTP verification | Six accessible slots or one semantic six-digit entry with styled slots, resend cooldown, edit email/phone; no fake verification | Future/backend-gated design |
| A10 | Recover account | Email/phone reset initiation, anti-enumeration language, error handling; disable if no backend | Future/backend-gated |
| A11 | Passkey creation / device security | Device biometrics explanation, consent, skip/recover; show not available unless wired to real platform API | Future/backend-gated |
| A12 | Portfolio setup | Choose investments, savings, property, other assets and liabilities; real selection, clear `Continue` / skip | `WelcomeScreen` plus setup route |
| A13 | Portfolio creation confirmation | Confirm name, currency UGX and optional illustrative dataset; never silently preload real-looking money | New/refine |

**Acceptance A:** Screenshot A07 compared to the canonical flat image is the first styling gate for the entire application. Test validation, keyboard overlap, focus order, contrast and 150% font scale.

### B. Primary wealth overview and portfolio

| ID | Screen | Required UI / behavior | Existing or target |
|---|---|---|---|
| B01 | Home dashboard | Portfolio greeting, attributable net worth, gross assets, debt, allocation and recent activity; accessible search/alerts | `HomeScreen` refine |
| B02 | Net worth overview | `Assets − Liabilities`; dated composition; percentage asset allocation, source/freshness cues | `WealthStatementScreen` refine |
| B03 | Portfolio overview | All asset classes and count/UGX totals, category chip filters, sort, Add CTA | `PortfolioScreen` refine |
| B04 | Portfolio global search | Search names, categories, institutions, liabilities and transactions; meaningful filters & empty state | `PortfolioSearchScreen` refine |
| B05 | Financial holdings overview | Investment and savings breakdown, current values, institutions, as-of metadata | `InvestmentOverviewScreen` refine |
| B06 | Portfolio activity summary | Recent transactions, due dates, reversed entry status; drill down | New/refine Home |
| B07 | Add action sheet | Investment, savings, property, other asset, liability, transaction; conditional entry points | `openCreateSheet` refine |
| B08 | Portfolio archived items | List archived assets, debt and document metadata, restore and cancel | `ArchivedRecordsScreen` refine |

**Acceptance B:** Dashboard totals are computed from current store data and update immediately after any valid create/edit/reversal/restore; no hard-coded graph growth percentages.

### C. Investments and savings

| ID | Screen | Required UI / behavior | Existing or target |
|---|---|---|---|
| C01 | Investments list | Cards/rows with institution, holding type, attributable balance, currency, valuation date/source | B05/filter refine |
| C02 | Investment detail | Value, cost, institution, acquisition date, status, notes; linked transactions; Edit/Archive | `AssetDetails` refine |
| C03 | Add investment | Investment type (shares, funds, government securities, retirement, SACCO etc.), institution, value, cost, date, source and notes | `AssetForm` refine |
| C04 | Edit investment | Prepopulated values, validation and non-destructive update; preserve history | `AssetForm` refine |
| C05 | Savings accounts list | Bank, SACCO, fixed deposit, NSSF-like saving product as configured; last recorded balance and as-of date | Holdings filter/refine |
| C06 | Savings account detail | Balance, contributions, accrued interest only if recorded, maturity date if applicable | `AssetDetails` refine |
| C07 | Add/edit savings | Institution, subtype, balance, date, optional maturity and recurring contribution notes | `AssetForm` enhance as model allows |
| C08 | Investment history / valuations | Dated value records + clear source and no false calculated performance | `ValuationHistoryScreen` |
| C09 | Record investment valuation | Whole value and date, source, notes; reject invalid and stale ordering | `ValuationForm` |
| C10 | Instrument performance | Cashflows vs value movement; TWR/XIRR `Unavailable` unless implemented with documented policy | New, gated if data insufficient |

**Acceptance C:** Investment income (dividend/interest) does not automatically increase stated asset value; transfers are not labeled profit.

### D. Property and real estate

| ID | Screen | Required UI / behavior | Existing or target |
|---|---|---|---|
| D01 | Property portfolio | Land, house, rental, commercial, development; owner-adjusted value, count and summary | Portfolio property filter / improve |
| D02 | Property detail | Location, type, full valuation, owner share, attributable value, value date/source and linked mortgage; visual hierarchy | `AssetDetails` property mode |
| D03 | Add property | Property label/type, location, current whole-property value, acquisition cost, ownership %, value source/date | `AssetForm` enhance |
| D04 | Edit property | Pre-filled values; preserve ownership economics; no fabricated title verification | `AssetForm` enhance |
| D05 | Property valuation history | Record and display dated estimates and provenance with label, not official valuations | `ValuationHistoryScreen` |
| D06 | Record valuation | Choose date/source, full value, save; derived owner share updated consistently | `ValuationForm` |
| D07 | Property equity | Attributable value minus linked loans, finance explanations and accurate debt links | Property detail / new subpage |
| D08 | Rental income | Property selector, rent receipts, operating expenses, net rental cash; transaction drill-through | `RentalIncomeScreen` |
| D09 | Property maintenance/expenses | Categorized expenditure, date, linked property, optional notes, impact on cash flow | `EventForm` property filter |
| D10 | Property documents | Property-linked document metadata, renewal dates; no file vault claims | `DocumentsScreen` filtered |

**Acceptance D:** A 75%-owned property valued at UGX 200M contributes UGX 150M in gross attributable assets. A UGX 40M linked mortgage is deducted **once**. The UI explains this instead of displaying two debt deductions.

### E. Liabilities, cash activity and transaction integrity

| ID | Screen | Required UI / behavior | Existing or target |
|---|---|---|---|
| E01 | Liabilities overview | Total debt + mortgage/loan summary, as-of, lender and linked property | `DebtsScreen` refine |
| E02 | Liability detail | Principal/recorded outstanding, last as-of, lender, linked asset, edit/archive | New detail or `LiabilityForm` enhancement |
| E03 | Add/edit liability | Loan category, lender, outstanding balance, as-of, optional asset link, status | `LiabilityForm` refine |
| E04 | Transactions ledger | Search/filter by type/date/asset, income/expense sign, reversals and source | `TransactionsScreen` refine |
| E05 | Transaction detail | Original event, linked asset, source, effective amount and reversal history | New, built on ledger |
| E06 | Add transaction | Contribution, withdrawal, dividend, interest, rent, fee, tax, expense, transfer, adjustment; validation and linkage | `EventForm` refine |
| E07 | Reverse transaction | Explain append-only adjustment, confirm, record reversal and show status | `reverseEvent` + confirmation UX |
| E08 | Cash flow report | Date filters, received income, costs, external contributions, list and drill-through | `CashFlowScreen` refine |

**Acceptance E:** Reversal does not delete the original transaction; adjusted totals exclude reversed entries; transfer is not treated as income.

### F. Reports and financial position

| ID | Screen | Required UI / behavior | Existing or target |
|---|---|---|---|
| F01 | Reports landing | Net worth summary, asset mix, financial standing, links to all available report types | `ReportsScreen` refine |
| F02 | Statement of position | Investments, savings, properties, other assets, gross assets, all debt, final net worth | `WealthStatementScreen` |
| F03 | Asset allocation | Actual category percentages, descriptive legend and accessible table | `WealthBreakdown` / drilldown |
| F04 | Cash flow / income | Actual dated transactions only; distinguish rent, dividends, fees and tax | `CashFlowScreen` |
| F05 | Property income report | Per-property rent/cost totals, current period, zero state, disclaimers | `RentalIncomeScreen` |
| F06 | Historical wealth trend | Only from valid historical snapshots; no invented curve, sensible missing-data state | New, data-gated |
| F07 | Investment performance | Distinguish distributions, market movement, contributions and available returns | New, data-gated |
| F08 | Report filters and export | Period filter; preview; export only through a safe and verified pipeline | Enhance; gated for sensitive exports |

**Acceptance F:** No report suggests certified net worth, verified valuations, guaranteed returns or live integration. Data provenance visible in context.

### G. Goals, planning, legacy and documentation

| ID | Screen | Required UI / behavior | Existing or target |
|---|---|---|---|
| G01 | Goals overview | Target, current allocation, progress and due date for each goal; create/edit/delete | `GoalsScreen` refine |
| G02 | Add/edit wealth goal | Name, UGX target, amount saved, target date, validation and current progress | Goal form/refine |
| G03 | Legacy planning hub | Stewardship overview, beneficiaries, trusted contacts and document index | `BeneficiariesScreen` refine |
| G04 | Beneficiaries list | Non-binding planned share, relationship and notes; combined shares ≤100% | `BeneficiariesScreen` |
| G05 | Add/edit beneficiary note | Name, relationship, planned share, notes, guard against >100% total | `BeneficiaryFormScreen` |
| G06 | Trusted contacts | Relationship, reachability and edit/delete, no granted portfolio access | `LegacyScreen` refine |
| G07 | Document record index | Filter/search name, category, related asset, expiry metadata; informative empty state | `DocumentsScreen` |
| G08 | Add/edit document metadata | Name, category, linked asset, issue/expiry, notes, archive/restore; **no fake attachment upload** | `DocumentFormScreen` |
| G09 | Document record detail | Metadata, related asset, renewal reminder, no false encrypted file preview | Enhance documents flow |
| G10 | Archival and continuity | Archived asset/liability/document record recovery; clarify history retained | `ArchivedRecordsScreen` |

**Acceptance G:** Beneficiary allocations cannot exceed 100%; legacy notes include an explicit non-legal-transfer disclaimer.

### H. Notifications, reminders and portfolio tasks

| ID | Screen | Required UI / behavior | Existing or target |
|---|---|---|---|
| H01 | Notification center | Derived local alerts for near-due reminders, expiring documents and stale valuations | `NotificationsCenterScreen` |
| H02 | Notification details | Source item, due date/context and direct route to originating record | Enhance local alerts |
| H03 | Alert preferences | Local toggles for reminders, document expiry and stale values, persisted | `NotificationPreferencesScreen` |
| H04 | Reminders overview | Upcoming/completed/overdue filters, ordered dates, task state | `RemindersScreen` refine |
| H05 | Add/edit reminder | Title, due date, optional linked asset and type, validation | Reminder form/refine |
| H06 | Complete/remind later | Real state update and local due-date editing, meaningful feedback | Enhance reminders |

**Acceptance H:** These are in-app notices. Do not display OS-level notification permission controls as functional unless push/local scheduling is genuinely integrated.

### I. Profile, security, billing, data and support

| ID | Screen | Required UI / behavior | Existing or target |
|---|---|---|---|
| I01 | More / navigation hub | Group routes by wealth / planning / account; single concise list, icon and chevron; no blank destinations | `MoreScreen` refine |
| I02 | Portfolio profile | Editable display name; status `On-device preview`; no false cloud identity | `ProfileScreen` |
| I03 | Security & privacy status | Transparent availability of passkeys, biometrics, local encryption, session and sync | `SecurityCenterScreen` |
| I04 | Notification preferences | Local preferences and disclosure about delivery capability | `NotificationPreferencesScreen` |
| I05 | Subscription information | Product scope and `Billing not connected`; never fake active subscription, checkout or renewal | `SubscriptionScreen` |
| I06 | Settings & data management | Import/export with explicit plain-JSON privacy warning; demo reset; confirmation & recovery | `SettingsScreen` refine |
| I07 | Archive management | Reopen archived assets, debt and document records | `ArchivedRecordsScreen` |
| I08 | Help & FAQ | Search/expand practical answers on asset ownership, calculations, security and records | `HelpCenterScreen` |
| I09 | About app | Brand meaning (Lonyo = wealth; Gang = home), product version and limits | `AboutScreen` |
| I10 | Account deletion / logout | Only real device reset or authenticated sign-out with correct semantics, explicit destructive confirmation | Gated / implement only once lifecycle is defined |
| I11 | Data & sync status | Local-only data state; last saved indication if verified; future sync clearly `Not connected` | New/refine Settings |

**Acceptance I:** Never portray the current preview as secure cloud-connected fintech. Security pages communicate accurately and help users avoid entering real financial secrets.

### J. Cross-screen operational and accessibility states

| ID | State / screen | Required implementation |
|---|---|---|
| J01 | No portfolio created | Proper onboarding / import / sample path |
| J02 | Empty category | Helpful empty text and real Add action |
| J03 | Loading / saving | Only genuine asynchronous operations; disable duplicate submissions |
| J04 | Invalid input | Inline semantic error + preserved user input |
| J05 | Persistence failure | Retry or recover; do not fake success |
| J06 | Stale valuation | Dated explicit warning, direct Record valuation link |
| J07 | Archived reference | Recover entry or show context without crash |
| J08 | Long labels / big values | Wrap naturally, avoid clipped UGX, `TextOverflow.ellipsis` only in legitimate compact rows |
| J09 | Offline device | Local preview stays functional; remote actions truthfully unavailable |
| J10 | Keyboard / accessibility | Keyboard-aware scrolling, TalkBack labels, focus order and readable large type |
| J11 | Session / privacy control | Avoid exposing unencrypted data as protected; remove false lock claims |
| J12 | Error / not found route | Professional recovery state with back navigation |

---

## 8. Recommended implementation order (avoid re-scaffolding)

**Phase 1 — Visual baseline / shared components:** Ensure canonical screenshot is stored; reconcile `LG` tokens; build responsive page scaffold, brand lockup, title + progress, input, CTA, surface and empty states; improve bottom nav. Create a golden for the approved flat Create Account page.

**Phase 2 — Identity and onboarding UI:** A01–A13. Maintain truthful preview gating for identity operations. Ensure first-run portfolio flow is usable; optional sample data loaded only by user choice.

**Phase 3 — Core wealth operations:** B01–B08, C01–C09, D01–D10, E01–E08. Connect actual store, forms, details, archive, reversal, attributed property values and valuation history.

**Phase 4 — Financial understanding:** F01–F08, including date filters and `not enough history` states. Avoid fabricated returns, incomplete financial accounting and invented graphs.

**Phase 5 — Planning / personal workflows:** G01–G10, H01–H06, I01–I11. Ensure metadata-only document scope, legal continuity disclaimers and truthful security status.

**Phase 6 — Cross-screen QA:** J01–J12, accessibility and responsive behavior; correct inconsistencies; capture and compare screenshots; run full CI, commit.

For each phase, deliver a real end-to-end slice; do not defer all work to placeholders or a list of TODO files. Existing working code should be improved, not discarded. If a feature requires production backend work, explicitly distinguish **UI complete but service gated** from **service integrated and tested**.

---

## 9. Flutter architecture and code standards

1. Keep `lib/domain` as the source of accounting truth and `lib/data` as persistence boundary. Widgets must not contain financial computations that contradict `lib/domain/finance.dart`.
2. Use an app state manager only if warranted by complexity; keep models immutable or well-encapsulated, with stable IDs and notifications after state changes.
3. Consolidate shared UI in `lib/presentation/widgets.dart` or small organized modules. Split overlong screen files when useful; no copy/paste variations of the same form field or card.
4. Use Material 3 components only when themed to the approved flat design; Flutter's default elevated, pill-shaped or tinted components are not automatically acceptable.
5. Use `const` where appropriate; dispose controllers and listeners; prevent navigation after unmount; preserve route state across back navigation.
6. Use correct form keyboard (`TextInputType.emailAddress`, phone, decimal or numeric), labels, input actions, validation and focus advance. Provide visible errors and accessible announcements.
7. Use semantic icons and illustrations sparingly; category icons must be consistent and non-decorative.
8. Keep colors and spacing central. No direct magic color hex literals inside individual pages except genuinely semantic extensions approved in the theme.
9. Add `Key` and semantic labels to critical controls for widget/integration tests.
10. Use deterministic fake/sample data **only in tests and explicit demo mode**, never as a fallback for real data or an implied live account connection.
11. Respect user data: do not overwrite persisted state automatically when adding new screens or changing the data schema.
12. Keep confidential planning and SRS material out of the public repository; source code, screen references and this UI specification are appropriate for public version control unless new private data are included.

---

## 10. Validation, screenshot comparisons and QA

### 10.1 Automated quality gates

At minimum run and fix all failures:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Where platform folders are not generated in the repository, use the project's documented controlled `flutter create --platforms=android,ios --org com.lonyogang .` setup in CI or local build before compilation. Never hide compiler errors by disabling analyzer rules.

Test **accounting and UI contracts** at least for:

- 75%-owned property + linked mortgage; correct attributable value and one debt deduction.
- Asset edit and archive/restore; no stale total after update.
- Transaction entry, reversal, income aggregation and transfer classification.
- Valuation history with source/date and rejection of illegal date/amount.
- Beneficiary combined share ≤100%; records survive app restart and export/import.
- Document metadata validation and expiry alerts; alerts toggle persists.
- Search empty and populated results; list sort/filter; sheet and back-navigation behavior.
- Registration input validation and keyboard flow; clear demo-mode status without pretend authentication.

### 10.2 Golden/screenshots

1. Use device-frame **1080 × 2400** Android reference output and consistent Flutter logical viewport/density. The PNG pixels are the **acceptance target**, not the source of hard-coded widget positions.
2. Save one PNG per screen or meaningful state with stable names, e.g. `LGH_A07_create_account_flat_1080x2400.png`.
3. Compare side-by-side to corresponding user-approved PNG: gutter spacing, title baseline, brand lockup, HERITAGE alignment, input heights, radius, progress segments, CTA position and visual calmness.
4. Use Flutter golden tests where deterministic; exclude or normalize actual system status-bar icons from pixel-diff if they vary by emulator OS. Preserve semantic content of the real status bar.
5. For changed screens, report screenshot QA as **pass / needs work**. Do not claim pixel-perfect unless an actual comparison was run.
6. Manually assess **small Android**, **6.7-inch Android**, **tablet/foldable**, **iPhone safe area**, **portrait**, and **textScaleFactor ~1.5**.
7. Check absence of overflow, hidden CTAs, tiny touch targets, contrast failures, clipped financial values, keyboard obstruction and inaccessible chip controls.
8. If screenshots differ from the accepted style, correct Flutter layout **before** moving to a new design aesthetic. Do not regenerate the image to justify a mismatch.

### 10.3 Acceptance scorecard for each screen

| Check | Gate |
|---|---|
| Brand and Theme 1 fidelity | Mandatory |
| Flat surfaces, understated radius, no heavy outlines/shadows/gradients | Mandatory |
| Visual alignment + whitespace against approved flat template | Mandatory |
| Navigation, CTA, cancel/back and error handling work | Mandatory |
| Real data mutations persist where advertised | Mandatory |
| Honest security/financial status claims | Mandatory |
| Keyboard, safe areas and 150% text scaling usable | Mandatory |
| Empty, populated, invalid and unavailable states | Mandatory |
| Unit/widget/golden tests relevant to screen | Mandatory |
| Android compilation and no analyzer errors | Mandatory |

---

## 11. Commit instructions and completion report for Claude Code

- Work on a feature branch when practical (e.g. `feature/flutter-flat-ui-completion`), or use safe sequential commits to the current branch when explicitly authorized. **Do not force-push, overwrite unrelated work or rewrite Git history**.
- Commit cohesive implementation batches: `style(ui): ...`, `feat(ui): ...`, `test(ui): ...`, `docs(ui): ...`.
- Include UI screenshot reference assets in `assets/reference/screens/` **unaltered**. A mockup image must never be used as a fake interactive screen.
- Keep `docs/SCREEN_INVENTORY.md`, `docs/IMPLEMENTATION_STATUS.md` and `docs/UI_QA.md` current; reconcile contradictory references and stale paths.
- On completion give a compact table: **Screen ID / route / implemented action / test evidence / visual QA / service dependency**.
- Provide links to the GitHub commits, CI run and screenshot artifacts. Explicitly identify gated production features; do not say “fully complete” when any corresponding service remains unimplemented.

### Required final deliverables

- Working Flutter/Dart app in the existing repository.
- Full implemented screen coverage, no unconnected primary controls.
- Shared Theme 1 component library and corrected primary logo layout.
- Valid domain-calculation and persistence behavior, with coverage.
- 6.7-inch screen captures, 1 PNG per completed view/state, and visual comparison results.
- Updated developer docs, QA checklist, passing CI and commit SHA.
- Honest list of production blockers: authenticated accounts, encryption, sync, document vault, subscriptions, supported FX, audited finance performance and security review.

---

## 12. Reference traceability and precedence note

The **specific styling requirements** above are derived from the latest user-approved Create Account flat UI image and the connected repository's `docs/ORIGINAL_UI_DESIGN_SYSTEM.md`, `docs/UI_QA.md` and stored Theme 1 screen references. The **current class names and functional boundaries** reflect the Flutter source and `docs/SCREEN_INVENTORY.md`, `docs/REMAINING_SCREENS.md`, `docs/ARCHITECTURE.md` and `docs/IMPLEMENTATION_STATUS.md` as reviewed on 6 November 2026.

Some items in this document are **new implementation requirements**, not claims that the current app already supports them: this includes expanded account recovery, granular performance reports, transaction details, improved form states, full golden comparisons and future security/billing workflows. Implement the UI for these without manufacturing nonexistent backend functionality. The user-approved flat registration reference takes precedence over earlier generated visuals whenever there is a conflict.

**Final guiding principle:** LonyoGang should look like a **quiet, premium private wealth-position application**—clear financial status, ownership, assets, liabilities and legacy—rather than a promotional finance dashboard or an illustrated template. *Precision, restraint, coherence and honest data* are the design quality criteria.