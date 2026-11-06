# Initial implementation and delivery status

## Completed in initial source package

- Expo React Native TypeScript scaffold, Android/iOS project configuration, canonical Theme 1 tokens.
- Approved Theme 1 granary branding (optimized PNG files) committed under `assets/brand/`.
- The design reference manifest is in `docs/REFERENCE_ASSET_MANIFEST.json`. The 13 original full-resolution PNG mockups are distributed separately in the LonyoGang source ZIP; they have **not** been committed to this GitHub repository.
- Reusable native views, action styles, data rows, summaries and two lightweight SVG graph components.
- Route-based interactive prototype (five bottom tabs, back navigation, registration/security/setup pages, detail and reporting flows).
- Editable session portfolio: add new asset; add outstanding liability; record income/expense/transfer entry.
- Basic validation on names, amounts, ownership percentages and YYYY-MM-DD date format.
- Net-worth arithmetic: `gross assets = sum(value × ownership share)`; `net worth = gross assets − outstanding liabilities`.
- Reporting cards explicitly mark demo trend data; asset detail shows last valuation date and source. Liabilities are not also subtracted from property gross value in the consolidated calculation.
- Tests covering portfolio arithmetic, parsing, formatting and valuation age.

## Partial / demo-only

- Sign-up, verification and passkey screens are **UI simulation**, not authenticated enrollment. They do not send OTPs or register device credentials.
- Demo assets and activity are stored **in memory for the current session only**. Changes are lost on restart.
- Reports show illustrative trends; a real historical valuation/ledger engine is not yet implemented.
- 'Liquid assets' proxy currently uses savings only. Real product must classify account liquidity and restricted funds by product and effective date.
- Screenshots are retained in the separately delivered source ZIP as design references. Native UI has not been proven pixel-equivalent on a 6.7-inch physical device or emulator.
- Document vault, beneficiary records, reminders, subscription and device management are information/placeholder screens; no document storage or notifications.

## Required before real-user launch

1. Identity provider implementing verifiable email/phone, MFA and actual passkeys; secure session token lifecycle and step-up operations.
2. Authenticated, tenant-isolated API with transaction audit log, server-side monetary precision, permissions and input validation.
3. Encrypted database and evidence vault, key rotation, backup, restore, deletion/export policy and threat-model review.
4. Immutable double-entry-like journal, reconciliation, effective-dated balances, cash flow aware TWR/XIRR and multi-currency FX provenance.
5. Property-specific ownership history, valuation source and freshness, rent/capex/opex, mortgage equity rules and evidence.
6. Beneficiary/continuity, nomination verification states and platform billing, implemented according to approved business and legal decisions.
7. Test on real Android and iOS targets, Android accessibility / WCAG 2.2 AA-oriented review, performance profiling and screenshot-diff visual QA against supplied references.
8. CI checks, dependency lockfile (requires network), repository protections, secret scan, pen-test and compliance review.

## Build verification limitation

The container's npm registry requests and Git remote HTTPS DNS calls were unavailable. An Expo dependency installation, Metro bundle build, device render and end-to-end app test therefore could not be performed. Syntax and domain tests can be run with a local TypeScript compiler; successful native builds must be verified by CI or your development machine.

## GitHub note

GitHub Contents read/write permissions were verified on 6 November 2026. The `main` branch now holds the Expo application source, component implementation, business-domain prototype, UI theme and branding assets, with tests in GitHub Actions. The 13 full-resolution design-reference PNGs and the confidential SRS PDF are not committed. This is not yet production ready.