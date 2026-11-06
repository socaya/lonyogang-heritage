# Reference-to-implementation mapping

| Ref | Approved PNG | Implemented route | Notes |
|---|---|---|---|
| Modern registration | `approved-account-layout.png` / `screen-06-create-account.png` | `signup` | Two-step, uncluttered flat forms; original reference remains immutable |
| Modern security | `screen-08-security.png` | `security` | Passkey interface only, no security provider wired |
| 10 | `LonyoGang_Theme1_10_Portfolio_Setup.png` | `setup` | Initial asset class selection |
| 11 | `LonyoGang_Theme1_11_Home_Dashboard.png` | `home` | Net worth, asset cards, activity, provenance |
| 12 | `LonyoGang_Theme1_12_Net_Worth_Overview.png` | `networth` | Assets minus debts; ownership-adjusted property |
| 13 | `LonyoGang_Theme1_13_Investments_List.png` | `investments` | Investment holding list |
| 14 | `LonyoGang_Theme1_14_Investment_Detail.png` | `investment` | Per-asset cost, value source and date |
| 15 | `LonyoGang_Theme1_15_Properties_Portfolio.png` | `properties` | Owned property inventory |
| 16 | `LonyoGang_Theme1_16_Property_Detail.png` | `property` | Property equity and valuation provenance |
| 17 | `LonyoGang_Theme1_17_Liabilities.png` | `liabilities` | Outstanding balances and mortgage association |
| 18 | `LonyoGang_Theme1_18_Transactions.png` | `transactions` | Recorded entries; expense and income separated |
| 19 | `LonyoGang_Theme1_19_Reports_Insights.png` | `reports` | Prototype trend + exact current distribution |

## Additional routes

`welcome`, `verification`, `addAsset`, `addDebt`, `addTransaction`, `savings`, `legacy`, `documents`, `reminders`, `settings`, `profile`, `portfolio`.

## PNG quality note

The source PNGs have been copied **without editing, recompression or layout modification**. Each individual reference remains a 1080 × 2400 PNG except original brand assets. The React Native screens are separately coded and need emulator screenshot comparisons before pixel-match sign-off.