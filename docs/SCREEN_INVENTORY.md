# Screen inventory — Flutter 0.3.0

LonyoGang Heritage uses flat Material 3 Theme 1. All screen classes below render native Flutter widgets and reuse the same design tokens.

## Core
- Welcome/local portfolio: WelcomeScreen
- Home with search and notices: HomeScreen
- Portfolio and asset details: PortfolioScreen, AssetDetails
- Asset / liability / transaction capture: AssetForm, LiabilityForm, EventForm
- Debts, ledger and reports: DebtsScreen, TransactionsScreen, ReportsScreen
- Goals, trusted contacts and reminders: GoalsScreen, LegacyScreen, RemindersScreen
- Local JSON and settings: SettingsScreen

## Newly completed
- Financial position: WealthStatementScreen
- Investments and savings: InvestmentOverviewScreen
- Global portfolio search: PortfolioSearchScreen
- Income and cashflow: CashFlowScreen
- Property rental income: RentalIncomeScreen
- Valuation history and capture: ValuationHistoryScreen, ValuationForm
- Archived asset, liability and metadata restoration: ArchivedRecordsScreen
- Document metadata index/edit: DocumentsScreen, DocumentFormScreen
- Beneficiary planning/edit: BeneficiariesScreen, BeneficiaryFormScreen
- Local notification center and preferences: NotificationsCenterScreen, NotificationPreferencesScreen
- Local profile: ProfileScreen
- Security status and privacy: SecurityCenterScreen
- Subscription information: SubscriptionScreen
- Help and about: HelpCenterScreen, AboutScreen

The screen code resides in lib/presentation/wealth_screens.dart and lib/presentation/legacy_screens.dart, wired to app navigation through lib/presentation/screens.dart. See docs/REMAINING_SCREENS.md for workflows and limitations.
