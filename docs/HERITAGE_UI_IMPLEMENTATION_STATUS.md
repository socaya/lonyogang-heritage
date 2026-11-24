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
