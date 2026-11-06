# LonyoGang Heritage — Theme 1 flat mobile design

## Primary visual authority

Use the approved **modern flat Create Account (01 / 02) image** as the design source of truth, not older illustration-heavy onboarding screens. The Acholi granary graphic remains an unchanged identity asset. HERITAGE is aligned directly below GANG; no bar-chart or arrow icon may replace the approved granary.

## Colour tokens

| Token | Colour | Role |
|--|--|--|
| Navy | `#102D40` | Titles, numbers, primary buttons |
| Deep Navy | `#0D283A` | Strong text contrast |
| Antique Gold | `#B88C3D` | Selected highlights and accents |
| Sage | `#607E68` | Wealth context / support |
| Sage Dark | `#446B55` | Accessible emphasis |
| Sage Soft | `#E8F0E9` | Subtle information surfaces |
| Canvas | `#F7F9F7` | Overall surface |
| White | `#FFFFFF` | Forms and cards |
| Soft Surface | `#F0F4F1` | Low-contrast grouping |
| Hairline | `#E1E8E3` | Light borders on fields only |
| Ink | `#163246` | Body text |
| Muted | `#6F808A` | Supporting labels |

## Layout
- Use 24dp horizontal gutters with an 8dp rhythm and 24-40dp vertical section spacing.
- Page titles typically 27–31sp, body 14–16sp and metadata 11–12sp.
- Corners: inputs 14dp, soft cards 18dp, primary actions 14dp, small badges pill.
- Flat rounded surfaces only; no heavy shadows, thick boxes, gradient washes, decorative landscape waves or excessive illustration.
- One clear 54–56dp high primary action; tactile targets at least 44dp.
- Preserve readable UGX values (int amounts; display with thousands separators and prefix).
- Include provenance/date for values, owner share for co-owned property, and a separate debt total.
- Honour native status bar, gesture/navigation area, safe areas and accessibility text scaling.
- 6.7-inch Android reference design target: 1080 × 2400 (20:9), verify across densities and devices.

## Flutter source mapping

- `lib/core/theme.dart`: Theme 1 colours, typography, button/input theme.
- `lib/ui/components.dart`: brand lockup, form inputs, labels, cards, actions, empty states.
- `lib/ui/auth.dart`: device-local enrollment and unlock.
- `lib/ui/shell.dart`: bottom navigation and Add sheet.
- `lib/ui/home.dart`: wealth dashboard.
- `lib/ui/portfolio.dart`: asset list, search, details and valuation history.
- `lib/ui/editors.dart`: typed validated asset, debt and transaction editors.
- `lib/ui/reports.dart`: net worth statement, cashflow report, allocation donut.
- `lib/ui/organize.dart`: beneficiary, reminders, encrypted documents, privacy settings.
- `assets/brand/`: approved Theme 1 granary and horizontal lockup assets.

### Fidelity and security gates

UI fidelity is a **test criterion**, not automatically guaranteed by a design token palette. Compare Android screenshots at the reference device dimensions, check spacing and logo clear-space, verify scroll/keyboard safe area, and support large text. The Flutter version uses real native controls and local records, not screenshots as page backgrounds.

The registration flow is a **local vault account**, not remote account verification. Do not add fake OTP, bank sync or sign-in promises without supported services.
