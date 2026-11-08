# LonyoGang Heritage — Flutter screen completion register

Updated: 6 November 2026 · Version: 0.4.0 local alpha.

## Approved visual language

The app follows the 6.7-inch Android flat UI reference: Midnight Navy #102D3F, Antique Gold #B58A3A, Sage #62816B, off-white #F7F9F7, 24 logical-pixel horizontal gutters, 12–14 px radii, restrained separators and no card elevation. Approved screenshots remain in assets/reference/screens. All application views are Flutter widgets; reference PNGs are not used as a substitute for interactive UI.

## Navigation and working screens

- Welcome and local portfolio selection: WelcomeScreen
- Home, total net worth and recent assets: HomeScreen
- Portfolio, holdings, and asset detail: PortfolioScreen, AssetDetails
- Add/edit investments, savings, properties and other assets: AssetForm
- Liabilities and linked mortgages: DebtsScreen, LiabilityForm
- Activity ledger and reversals: TransactionsScreen, EventForm
- Financial position and allocation: ReportsScreen, WealthStatementScreen
- Savings and investment overview: InvestmentOverviewScreen
- Global portfolio search: PortfolioSearchScreen
- Date-filtered cash flow and income: CashFlowScreen
- Property-linked rent and expenses: RentalIncomeScreen
- Historical valuations and capture: ValuationHistoryScreen, ValuationForm
- Restore archived assets, loans and document records: ArchivedRecordsScreen
- Goals and progress: GoalsScreen
- Trusted contacts: LegacyScreen
- Beneficiary planning notes: BeneficiariesScreen, BeneficiaryFormScreen
- Document record index and metadata editor: DocumentsScreen, DocumentFormScreen
- In-app reminders: RemindersScreen
- Local notification center and options: NotificationsCenterScreen, NotificationPreferencesScreen
- On-device portfolio profile: ProfileScreen
- Security readiness and privacy: SecurityCenterScreen
- Subscription and billing information: SubscriptionScreen
- JSON import/export and demo data: SettingsScreen
- In-app FAQ and product information: HelpCenterScreen, AboutScreen
- Passphrase unlock, set/change and biometric linking: UnlockScreen, EncryptionSetupScreen
- Target allocation and drift: AllocationScreen
- Recurring contributions: ScheduledContributionsScreen, ScheduleForm
- Offline FX reference rates: FxRatesScreen

Most new screens are reached via More, with shortcuts from Home, Asset details and Reports.

## Financial and persistence semantics

The local PortfolioState is now schema version 2, but imports of schema version 1 remain supported — documents, beneficiary plans, valuation history, notification preferences, FX rates, scheduled contributions and target weights are all optional new fields that default to empty. Amounts are integer UGX. Ownership-adjusted asset values contribute to net worth. Linked mortgages are deducted just once. Activity events remain append-only and reversals cancel originals. Valuations preserve source and dates. Beneficiary intended shares are constrained to a combined 100%. TWR is computed per asset from dated valuations using a Modified-Dietz chain-link and annualized over the observed span; XIRR uses Newton–Raphson over contributions, withdrawals, dividends/interest/rent, fees/tax/expenses and the current value as the terminal flow.

## Clear limitations

Document attachments are encrypted on device under the vault key (AES-GCM) but still live in the app sandbox — enable the passphrase under Encryption for strongest protection. Beneficiary notes are non-binding and do not give legal estate rights or account access. Subscription checkout and payment processing are not connected. OS notification delivery depends on the platform granting the app permission. There are no remote passkeys, cloud database, remote account recovery, multi-device sync, financial institution feeds, live FX feed or independently verified property values. Do not capture real identity numbers, title identifiers, account credentials or confidential financial details until an independent security review has signed off on the local vault model.

## Device acceptance checklist

1. Render on a 6.7-inch device and check safe areas, scroll, keyboard and 150% text scaling.
2. Compare typography, spacing, controls and branding with assets/reference/screens.
3. Add a 75%-owned property and a linked mortgage and check net worth.
4. Add a dated asset valuation and confirm history and current-value updates.
5. Record rent and costs, reverse an expense, and confirm cash-flow reports.
6. Enter beneficiary intentions totaling 100% and confirm further additions are rejected.
7. Add an expiring document record and verify notification preferences.
8. Archive and restore entries; check that all records survive app restart.
9. Export and import non-sensitive sample data and verify legacy schema compatibility.
10. Perform accessibility, device compatibility, encryption, privacy and security audits before production launch.

GitHub Actions runs Flutter analyzer, tests and Android debug compilation. A passing build does not certify pixel-matched UI or production security.
