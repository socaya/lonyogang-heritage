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
