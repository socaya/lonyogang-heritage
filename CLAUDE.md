# Claude Code instructions — LonyoGang Heritage

This project is a **Flutter/Dart** personal wealth and asset tracker. The canonical UI implementation brief is:

**[`docs/CLAUDE_UI_IMPLEMENTATION_REQUIREMENTS.md`](docs/CLAUDE_UI_IMPLEMENTATION_REQUIREMENTS.md)**

Read that specification **in full** before planning or editing screen code. It is the authoritative UI contract for all screen designs, interactions, financial semantics, state handling, accessibility, and screenshot acceptance.

## Immediate priorities

1. Study `lib/core/design.dart`, `lib/presentation/*`, `lib/data/portfolio_store.dart`, `lib/domain/*`, and the approved screenshots in `assets/reference/screens`.
2. Follow **Theme 1**: Midnight Navy `#102D3F`, Antique Gold `#B58A3A`, Sage `#62816B`, off-white `#F7F9F7`.
3. The latest **flat Create Account** reference is the primary visual authority: 24dp content gutters, understated white inputs with hairline borders, flat and softly filled cards, 12–16dp radii, ample whitespace, no heavy outlines/shadows/gradients/decorative waves.
4. Preserve the original Acholi granary; **HERITAGE is exactly below GANG**. Never redraw the symbol or insert bar/arrow motifs.
5. Build working Flutter screens and flows; **never show a screenshot as a fake UI** or wire dead-end CTAs. Use real persisted demo data and tested domain calculations.
6. Do not claim that passkeys, encryption, cloud sync, bank feeds, document uploads, payments or real account verification exist until integrated and tested. Public repo must not contain confidential SRS or real financial data.
7. Update `docs/SCREEN_INVENTORY.md`, `docs/IMPLEMENTATION_STATUS.md`, and `docs/UI_QA.md` as you complete work.
8. Run `flutter analyze`, `flutter test`, and `flutter build apk --debug`. Compare Android captures against actual approved images (1080×2400) and record any mismatch.

**Execution requirement:** Implement features in cohesive, verified batches; prioritize correct existing code and end-to-end user interactions over scaffolding and cosmetic mockups. Commit changes and report factual test results, screenshots, unresolved blockers and commit references.

If the latest user-approved flat Create Account screenshot is not yet in the repository, ask for or copy the original supplied file into `assets/reference/screens/approved-flat-create-account.png`; **never substitute an earlier illustration** or invent an approval.
