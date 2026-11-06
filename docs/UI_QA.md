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

## QA checklist

- [ ] Verify Android screenshot visually against each approved PNG at consistent density.
- [ ] Validate long account names, number formatting and overflow.
- [ ] Validate touch targets, keyboard avoidance and accessible text scaling.
- [ ] Verify TalkBack focus order, screen-reader labels and form error announcements.
- [ ] Test empty, loading, error and large-portfolio states.
- [ ] Confirm no invented auto-generated returns or false live-account status.
- [ ] Test tablets, foldables and small Android devices.
- [ ] Produce golden screenshot tests once the CI emulator is available.

Pixel-perfect equivalence has **not** been verified in this development environment; Flutter Android emulator was unavailable.
