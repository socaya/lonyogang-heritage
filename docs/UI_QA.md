# Approved UI reference and visual acceptance

The approved screen language is the modern, light, calm, flat account-registration image provided by the product owner, **not** the earlier illustrated, thick-bordered screens.

- Reference target: Android 6.7 inch, representative 1080 × 2400 portrait.
- Screen canvas: soft off-white `#F7F9F7`.
- Primary: Midnight Navy `#102D3F` and deep navy `#0C2738`.
- Premium accent: Antique Gold `#B58A3A` (not bright yellow).
- Secondary: Sage `#62816B`; neutral text `#6C7D86`; subtle line `#E5EAE7`.
- Containers: white or sage-tinted cards without heavy shadows; modest radius (~12–14 logical px), 22–24 logical px horizontal margins; no decorative grassy wave footer.
- Financial hierarchy: large readable net worth; gross assets and liabilities separately; dates, sources, estimates, and ownership share disclosed.
- Branding: original granary mark. The **HERITAGE** subtitle sits below **GANG**, not below full wordmark.
- Components use real Flutter text, controls and navigation. Reference PNGs are NOT placed as static backgrounds.

## Shared component library

Every new screen in this codebase composes from `lib/presentation/components.dart`:

- `AppPage` — canvas background, SafeArea, keyboard-aware scroll, 24dp gutters.
- `AppHeader` — back button, optional `step X / Y` pill, centered compact brand.
- `StepProgress` — thin two-segment gold/line progress used on canonical Create Account.
- `PrimaryCTA` — 52dp navy button with optional discreet gold trailing arrow; supports loading.
- `SecurityNotice` — pale-sage panel with shield icon; use for honest privacy statements.
- `StatusChip` + `recordStatusChip(RecordStatus)` — semantic info / warn / danger / positive / neutral tones.
- `MoneyField` — UGX numeric input with rejection of negatives and overflow.
- `DateField` — soft tile tapping into Material 3 `showDatePicker`.
- `PhoneField` — country-code dropdown (default `+256`) + subscriber number.
- `confirmActionSheet` — bottom-sheet confirmation for destructive actions.
- `LoadingState`, `ErrorState`, `AppEmptyState` — standardized state widgets.

## Canonical Create Account acceptance (A07)

Compare against the approved flat Create Account PNG:

- [ ] Top row: back arrow, centered compact `BrandMark(height:28)`, `01 / 02` pill on the right.
- [ ] Headline `Create your account` on the top content gutter (24dp left).
- [ ] Short subtitle in muted grey, 14sp, line-height ~1.5.
- [ ] `ACCOUNT DETAILS` sage eyebrow then a thin two-segment progress line (first gold, second `#E5EAE7`).
- [ ] Three stacked fields: Full name, Email, Mobile number (with country-code dropdown).
- [ ] Terms-of-service checkbox inline with legal-link `Text.rich`.
- [ ] Pale-sage `Private by design` panel with shield icon.
- [ ] Navy `Continue` CTA with gold trailing arrow.
- [ ] Muted `Sign in instead` and `Recover access` row below.
- [ ] Footer: `Design preview · No real account is created or verified.`

## QA checklist

- [ ] Verify Android screenshot visually against each approved PNG at consistent density.
- [ ] Validate long account names, number formatting and overflow.
- [ ] Validate touch targets, keyboard avoidance and accessible text scaling.
- [ ] Verify TalkBack focus order, screen-reader labels and form error announcements.
- [ ] Test empty, loading, error and large-portfolio states.
- [ ] Confirm no invented auto-generated returns or false live-account status.
- [ ] Test tablets, foldables and small Android devices.
- [ ] Produce golden screenshot tests once the CI emulator is available.
- [ ] Encryption flow: enable passphrase → kill app → unlock → data intact.
- [ ] Attachment flow: attach + decrypt + preview + remove, each stage verified.
- [ ] Prototype flow: canonical Create Account step 1 → step 2 → OTP (always surfaces the design-preview disclaimer).
- [ ] Not-found flow: navigate to an invalid route and confirm `NotFoundScreen` renders a `Return home` CTA.

Pixel-perfect equivalence has **not** been verified in this development environment; Flutter Android emulator was unavailable.
