# Heritage UI implementation status

## Delivered in this batch
- Branded 104-screen concept, requirements and field catalogue committed.
- Shared Flutter theme: ivory canvas, navy navigation, gold active icons, reduced radii, lighter type, accessible muted text and tabular hero numerals.
- Approved bundled primary logo in shared BrandMark; branded splash and welcome.
- Four destination shell; contextual Add on Home and Portfolio; legacy Home report callback mapped to the new index.
- Flat navy dashboard hero and hidden dashboard allocation/asset/activity amounts when masking is enabled.

## Not yet complete
- Native Flutter analyze, format, tests, screenshots and device accessibility verification have not been run in this environment.
- Screen-by-screen composition, form grouping, dark theme, local bundled fonts, global privacy masking, and full 104-route traceability require further implementation and testing.
- Two-stage authentication remains outstanding: current backend accepts combined password/TOTP and permits password-only accounts. Implement expiring, single-use server challenge and supported second-factor enrollment/delivery, then migrate all clients and integration tests. Do not expose a fake OTP or claim MFA enforcement.

This is an incremental implementation, not a 100% completion or production readiness declaration.

## Batch 2 — portfolio and asset entry
- Added ownership-adjusted total holdings hero, live portfolio search and sorting, and filter-aware empty states.
- Asset registration now groups existing fields by purpose and retains fractional ownership on edit.
- Allocation chart omits zero segments, avoids misleading charts for nonpositive totals, and presents exact values and percentages.
- Updated navigation regression test for four tabs, contextual Add and search.
- Tests not executed: Flutter SDK unavailable. Authentication, native dark mode and remaining screen-specific work remain open.

## Batch 4 — transaction and expense browsing
- Live transaction search, type and inclusive date range filters, date grouping and exact amounts; reversal status uses the full ledger.
- Expense period and search filters, real category totals, accurate local-day and month bounds (future records excluded from daily/monthly summaries).
- Existing recording, editing, attachment and reversal flows retained.
- Native tests remain unexecuted; no Verified status asserted.

## Batch 5 — liability entry and detail
- Original principal, balance date and repayment due date now editable and persisted using existing model fields. Preserve archive state, custom category input and previously linked archived or unavailable property. Stable ID during retry, duplicate-submit guard and inline save failure feedback. Detail shows category/reference and unknown principal explicitly. Added store validation for negative principal and persistence regression test. Flutter tests not run.

## Batch 6 — reporting improvements
- Rental income uses property/period filters, current ledger receipts and costs, exact totals and dated records; excludes reversed and future entries.
- Cash flow excludes future entries; exact row amounts wrap. Historical net-worth range selection uses actual dated observations only. Asset performance refreshes current asset and includes a numeric valuation list.
- Native build, screenshots and regression tests remain unexecuted; no verified coverage claim.

## Batch 7 — heritage planning and document editing
- Document search now includes notes and stored custom categories. Metadata edits preserve attachments, archive flag and archived/missing asset links. Stable retry IDs and guards prevent duplicate record creation.
- Beneficiary basis-point precision preserved, combined share validated before saving, destructive actions confirmed.
- Goal and schedule date pickers accept existing overdue dates, stable IDs protect retries, trusted contact and schedule deletion require confirmation. Scheduled postings described truthfully as reviewed/manual.
- Native verification remains outstanding.

## Batch 8 — notifications and reminders
- Persisted scheduled-contribution preference; inbox and native scheduling use it. Dismissals suppress corresponding native alerts; short lead-time reminders schedule at due date. Added restore-dismissed action and alert detail dismissal.
- Full reminder add/edit/remove form with stable IDs, validation, failure handling and reactive list. Existing reminder completion preserved. Regression tests added but not run.
- Overall functional coverage percentage remains unmeasured; 0% independently verified in this environment. Do not count source mapping as implementation.

## Batch 9 — account and security interfaces
- Data & sync uses actual scoped service even when constructor argument omitted; no false offline success or misleading cloud copy. Sync and hydration guarded against duplicate operations and unmounted state updates; hydration requires unlocked content key.
- Device sessions identify current session from access-token sid for UI purposes, distinguish expired/revoked/active and prevent accidental self-revocation in client. Server remains authorization authority.
- Privacy actions expose errors, prevent updates after navigation, reset remote status after account erasure and truthfully label clipboard export.
- Native verification and mandatory two-stage authentication remain outstanding. Overall functional coverage denominator not yet audited; verified coverage 0% in this environment.

## Batch 10a — authenticator UI and device identity
- Dedicated working TOTP verification screen using existing server contract; password screen no longer embeds TOTP or simulates successful offline sign-in. Secure random persisted installation UUID shared by online registration and sign-in. Optional empty phone corrected.
- Mandatory email OTP, server-issued pre-auth challenge, replay prevention and registration/sign-in separation still outstanding. Existing password-only server behavior remains; this is not full two-stage authentication. Native tests not run.

## Batch 10b — restricted authentication challenge endpoints
- Database-backed hashed challenge tokens, five-minute expiry, attempt and account limits, credential binding, single-use verification, cancellation, email delivery and TOTP replay protection on new challenge endpoints. Session creation and consumption are transactional. Legacy endpoint remains available for compatibility until client and test migration; mandatory enforcement is NOT complete. Resend endpoint and Flutter wiring remain outstanding. Backend integration tests not run.

## Batch 10c–e — mandatory password sign-in verification
- Server-side resend rotation and independent Flutter email and authenticator routes use restricted sign-in challenges. Registration verifies all required channels before navigating to sign-in; no registration password is reused to issue sessions.
- Legacy password session issuance removed from client and service. Historical POST /identity/sessions now issues only a challenge (202), never credentials. The separate passkey authentication path remains unchanged.
- Existing integration test callers of the historical endpoint require contract migration; native and backend builds and tests have not yet been executed. Mandatory password authentication source changes are committed; release readiness is not established.

## Batch 12a — shared responsive UI foundation
- Adaptive page gutters and centered maximum content widths on AppPage and WealthPage; keyboard dismissal on scroll; orientation lock removed to allow platform-supported landscape.
- Responsive heading and detail label/value rows, wrapping form labels, 48dp filter targets with selected semantics and reduced-motion support, scrollable confirmation sheets, wrapped error and list headings. Existing logo and palette preserved.
- Native viewport and text-scale tests remain unexecuted; individual screen overflow and tablet layouts remain to be audited. No claim of overall screen completion.

## Batch 13 — Native appearance
- Explicit light/dark palettes, locally persisted System/Light/Dark preference, Settings appearance route, adaptive shared and screen-specific colour migration across finance, heritage, forms, onboarding, identity, sessions, privacy and supporting screens.
- Added appearance persistence, contrast, switching and shared-component widget test cases in test/appearance_test.dart. Tests are not executed in the connector-only environment. Remaining hardcoded colours, actual native contrast, visual regressions and compilation must be checked before marking this milestone verified. Overall 104-screen functional completion remains unquantified.

## Batch 14 — Typography
- Bundled upstream Manrope and Inter variable fonts and SIL OFL licence texts, registered fonts in pubspec, centralized theme hierarchy and financial numeral features, migrated primary financial summaries and shared label/value rows; reduced excessive font weights in affected screens and removed selected FittedBox wrappers.
- Added font asset, theme hierarchy and nine viewport/text-scale regression cases in test/typography_test.dart. Native test execution and full screen-level typography audit remain outstanding. Overall functional coverage is not established by these source changes.
