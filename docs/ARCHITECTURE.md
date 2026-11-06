# Flutter implementation architecture

## Modules

- `domain/models.dart`: versioned persisted DTOs, asset kinds, beneficial ownership basis points, append-only ledger events and reversal links.
- `domain/finance.dart`: gross assets, debt, net worth and property equity. Linked mortgage is subtracted exactly once in consolidated net worth. Cash income, fees and transfers remain distinct.
- `data/portfolio_store.dart`: `ChangeNotifier` backed by `shared_preferences`; local-only demo storage and schema v1 import/export. No misleading claim of encryption or cloud authentication.
- `core/design.dart`: Theme 1 tokens and mobile typography, soft surfaces, restrained radius and semantic colours.
- `presentation/app.dart`: bottom navigation and home flow.
- `presentation/screens.dart`, `forms.dart`, `widgets.dart`: interactive portfolio and planning screens.

## Accounting invariants

1. All UGX money is stored as integer units. Fractional currency, FX feeds and securities quantity precision need a separate decimal engine before launch.
2. Property owner value = current whole-property value × recorded economic ownership share (basis points / 10,000).
3. Net worth = all attributable current assets − all attributable outstanding debt; never property equity minus mortgage twice.
4. Manual property appreciation is not realized cash income. Event log entries do not automatically mutate current asset value.
5. Reversals append a separate event; original posted events remain accessible. Duplicate event IDs are ignored.
6. No TWR/XIRR claim is made without sufficient dated valuations and cashflows.
7. No third-party integrations, legal title checks or automatic beneficiary access are assumed.

## Production gaps (explicit release blockers)

Identity/passkeys/MFA and secure session lifecycle; per-user backend authorization; encryption-at-rest and encrypted document vault; secure sync, conflict resolution and backup/recovery; external feeds with explicit user consent; full decimal/multi-currency valuation; statement reconciliation and investment TWR/XIRR; immutable server audit; app notification permissions and scheduler; accessibility/localization/device QA; threat modelling/pen test; subscription billing and legal review. See the original confidential SRS for requirements and acceptance criteria. Do not publish that SRS into a public GitHub repo.
