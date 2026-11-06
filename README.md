# LonyoGang Heritage — Android & iOS app

**LonyoGang** is a personal wealth and asset portfolio tracker for investments, savings, property, liabilities and net worth. The name combines Acholi *Lonyo* (wealth) and *Gang* (home). The visual identity retains its granary construction motif and places **HERITAGE** beneath **GANG**.

## Implementation status

This repository is a **functional Expo / React Native UI prototype**, not a production financial product. The portfolio is preloaded with obviously illustrative data, and add-asset, add-debt and record-transaction flows update session state. No backend or live financial accounts are connected. **Do not enter real financial credentials or sensitive portfolio information** until secure authentication, encryption, backend persistence and security review are implemented.

The prototype includes welcome, sign-up, verification, security and portfolio setup screens; Home, Portfolio, Net Worth, Investments, Savings, Property, Liabilities, Transactions, Reports; asset details; data-entry forms; Legacy, Documents, Reminders, Profile and Settings.

## Run

```bash
npm install
npx expo start --android
# or scan the QR in Expo Go where supported
```

Requirements: Node.js LTS, Android emulator or a compatible Expo Go application. This project targets the **Expo SDK 54** family and React Native 0.81.4. Run `npx expo install --check` and `npx expo-doctor` after dependencies have been installed; adjust package versions only based on the SDK's verified compatibility output.

```bash
npm run typecheck
npm run test:unit
```

> This build environment did not have npm registry access, so dependencies could not be downloaded and Android native builds could not be executed here. Source syntax and core finance rules were checked locally, but full device rendering remains a required verification step.

## Source tree

- `App.tsx` — Expo entrypoint
- `src/screens/AppScreens.tsx` — navigation, core screens, interactive capture flows
- `src/components/ui.tsx` — brand, typography, controls, cards, charts, bottom navigation primitives
- `src/model/finance.ts` — typed assets, liabilities, records and wealth semantics
- `src/data/demo.ts` — explicitly non-live sample portfolio
- `src/theme/tokens.ts` — canonical Theme 1 design tokens
- `assets/brand/` — approved original colour logo and granary image
- `assets/reference/screens/` — PNG visual references retained intact
- `docs/` — design specification, screenshot mapping, data and implementation notes
- `tests/domain.test.cjs` — financial invariants and input parsing regression tests

## Safety and boundaries

LonyoGang does **not** hold customer funds, broker trades, provide regulated advice, guarantee yields, certify ownership or verify land titles. Imported/entered data must be labeled by provenance and date. The current app operates with **ephemeral demo state only**, deliberately avoiding storage of unencrypted real financial records.

The confidential product requirements document is **not** included in this public repository; the documentation here is a minimal implementation/design specification derived from approved UI and non-sensitive requirements.

## Visual source of truth

The modern account-creation screenshot is the canonical visual reference. Follow its calm light background, minimal dividers, subtle surfaces, compact brand lockup, navy text, muted sage help text and antique-gold accents; avoid thick outlines, gratuitous shadows, gradients, oversized illustrations and landscape wave backgrounds. Screens are designed responsively using dp and safe areas, with a **1080 × 2400 (6.7-inch 20:9)** PNG reference target.

See [UI design system](docs/UI_DESIGN_SYSTEM.md), [screen inventory](docs/SCREEN_INVENTORY.md), and [implementation status](docs/IMPLEMENTATION_STATUS.md).