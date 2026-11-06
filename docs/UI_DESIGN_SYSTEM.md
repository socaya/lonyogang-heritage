# LonyoGang Heritage — UI design system v0.1

## Approved style

**Primary design authority:** the modern flat account-creation screen in `assets/reference/screens/approved-account-layout.png`, supported by `screen-06-create-account.png`, `screen-08-security.png`, and the 10 previously approved reference images. These references should not be reimagined or replaced with decorative finance-app templates. The supplied Theme 1 granary is a graphic asset, not a shape to reproduce with an improvised chart icon. The logo geometry is preserved.

The interface is light, soft and calm. Navigation flows lead with task context; wealth summaries lead with the value and provenance. Establish clear vertical rhythm and avoid unnecessary information density.

## Colour tokens

| Token | Hex | Usage |
|---|---|---|
| Navy | `#102D40` | Headings, important data, primary button |
| Navy deep | `#0D283A` | Strong contrast |
| Antique gold | `#B88C3D` | Controlled emphasis, selected states, call-to-action arrow |
| Sage | `#607E68` | Wealth context, supportive accent, success |
| Sage dark | `#446B55` | Accessible sage text/icons |
| Sage soft | `#E8F0E9` | Informational and security surfaces |
| Canvas | `#F7F9F7` | App-level background |
| White | `#FFFFFF` | Low-elevation cards/inputs |
| Soft surface | `#F0F4F1` | Neutral cards and control backgrounds |
| Hairline border | `#E1E8E3` | Inputs and nav separators only |
| Ink | `#163246` | Default copy |
| Muted | `#6F808A` | Supporting descriptions |

## Layout rules

1. 24 dp horizontal gutters, 8 dp base rhythm; more air between titled sections (24–40 dp).
2. Titles 27–31 sp, secondary headings 19 sp, body 14–16 sp, supporting labels 11–12 sp. Avoid tight letterspacing on multi-line copy.
3. White inputs on off-white background with a thin *subtle* border; do not use bright or thick input outlines. Cards use softly filled surfaces without border boxing.
4. Input corners 14 dp, standard cards 18 dp, primary buttons 14 dp, badges fully rounded. Do **not** apply universal 30+ dp radii.
5. Keep the primary action 56 dp tall with meaningful button text. One visually dominant action per view.
6. Maintain predictable content positions across flows. Align card titles, financial values and list rows with the same content grid.
7. Reserve gold for selected tabs, progress marks and a few highlights; do not make every asset card gold.
8. Use native status bar and safe-area handling rather than painting decorative fake Android system bars.
9. Include source and date on all assets and property values. Never label an owner estimate as a certified appraisal.
10. At 6.7-inch reference target, density should remain readable with Android font scaling. Scroll vertically for content rather than squeezing all details above the fold.

## Components implemented

`Brand`, `H`, `Body`, `Surface`, `Pill`, `Action`, `Input`, `SectionHeading`, `ItemRow`, `Divider`, `Icon`, `Trend`, `WealthDonut`, bottom navigation and task-specific finance forms.

## Image usage and fidelity policy

The repository contains untouched approved screenshot/reference PNGs. They are the visual acceptance target, not a substitute for functional UI. React Native renders native components rather than presenting flattened PNG screenshots as app pages. **Pixel-for-pixel equivalence has not been verified on an Android emulator**; compare screenshots at matched density and adjust text metrics, logo clear-space and responsive sizing after a device build. Earlier generated screens sometimes place the same page into different compositions; the modern flat-account screen takes precedence where references conflict.

## Accessibility and interactions

Provide semantic accessibility roles, accessible button names, adequate touch sizes (~44 dp or more), sufficient contrast, no information encoded only by colour, dynamic type validation and positive/negative currency sign clarity. Demo tabs and forms are interactive. Production flows require external identity, accessibility and device QA.