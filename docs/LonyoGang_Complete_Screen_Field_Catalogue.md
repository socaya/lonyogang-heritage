# LonyoGang Heritage — Complete mobile screen and field catalogue

104 concepts. All sample data is fictional. This is a visual implementation reference, not a verified backend contract. Fields marked * are proposed required fields; validate against current Flutter domain models and services. Conditional online screens must remain gated. Never collect real data in the HTML.

## 01 Access & setup

| ID | Screen | Fields / controls shown | Primary action |
|---|---|---|---|
| A01 | LonyoGang Heritage | Read-only summary, links or state | Contextual navigation |
| A02 | Your wealth. One view. | Read-only summary, links or state | Contextual navigation |
| A06 | Sign in | Email; Password only | Continue to verification |
| A06a | Verify your identity | Server-approved verification method (only if multiple available) | Choose method |
| A06b | Authenticator verification | Six-digit TOTP code | Verify and sign in |
| A06c | Sign-in OTP verification | Six-digit OTP; masked destination; resend cooldown | Verify and sign in |
| A07 | Create account | Full legal name; Email address; Mobile number; Accept terms and privacy notice | Continue |
| A08 | Protect your account | Password; Recovery contact (optional); Enable biometrics when available | Continue to verification |
| A09 | Verify your account | Verification code | Verify |
| A10 | Recover account | Email or mobile | Send recovery instructions |
| A11 | Reset password | Email; Reset code; New password | Reset password |
| A12a | Name your portfolio | Portfolio name | Continue |
| A12b | Choose asset categories | Investments; Property; Savings; Other assets | Continue |
| A12c | Review setup | Read-only summary, links or state | Create portfolio |
| A13 | Unlock portfolio | Passphrase | Unlock |

## 02 Wealth & portfolio

| ID | Screen | Fields / controls shown | Primary action |
|---|---|---|---|
| B01 | Your wealth | Read-only summary, links or state | Contextual navigation |
| B02 | Add a record | Read-only summary, links or state | Contextual navigation |
| B03 | Portfolio | Search assets; Category; Sort by | Add asset |
| B04 | Search portfolio | Search; Record type | Contextual navigation |
| B05 | Investments & savings | Read-only summary, links or state | Contextual navigation |
| B08 | Archived records | Read-only summary, links or state | Review restore |
| C01 | Gulu property | Read-only summary, links or state | Edit asset |
| C02 | Treasury bonds | Read-only summary, links or state | Edit asset |
| C03 | Personal savings | Read-only summary, links or state | Edit asset |
| C04 | Other asset | Read-only summary, links or state | Edit asset |
| C05 | Liabilities | Read-only summary, links or state | Contextual navigation |
| C06 | Property mortgage | Read-only summary, links or state | Edit liability |
| D01 | Add investment | Asset name *; Category *; Custom category (if other); Current value (UGX) *; Ownership share (%) *; Acquisition cost (UGX); Institution; New institution (if other); Account / portfolio reference; Interest frequency; Interest rate per selected period (%); Valuation date *; Record status; Notes / valuation source; Supporting document (optional) | Save asset |
| D02 | Add property | Asset name *; Category *; Custom category (if other); Current value (UGX) *; Ownership share (%) *; Acquisition cost (UGX); Location; Valuation date *; Record status; Notes / valuation source; Supporting document (optional) | Save asset |
| D03 | Add savings | Asset name *; Category *; Custom category (if other); Current value (UGX) *; Ownership share (%) *; Acquisition cost (UGX); Institution; New institution (if other); Account / portfolio reference; Interest frequency; Interest rate per selected period (%); Valuation date *; Record status; Notes / valuation source; Supporting document (optional) | Save asset |
| D04 | Add other | Asset name *; Category *; Custom category (if other); Current value (UGX) *; Ownership share (%) *; Acquisition cost (UGX); Location; Valuation date *; Record status; Notes / valuation source; Supporting document (optional) | Save asset |
| D05 | Add liability | Liability name *; Category; Custom category (if other); Lender; Loan reference; Outstanding amount (UGX) *; Original principal (UGX); Linked property; Balance as of *; Due date; Notes | Save liability |

## 03 Transactions & expenses

| ID | Screen | Fields / controls shown | Primary action |
|---|---|---|---|
| E01 | Record transaction | Description *; Transaction type; Amount (UGX) *; Transaction date *; Linked asset; Notes; Receipt / evidence | Record transaction |
| E02 | Transactions | Search; Type; From; To | Record transaction |
| E05 | Transaction details | Read-only summary, links or state | Contextual navigation |
| E06 | Reverse transaction | Read-only summary, links or state | Confirm reversal |
| E07 | New expense | Description *; Category; Custom category (if other); Amount (UGX) *; Merchant; Payment method; Date *; Paid from asset (optional); Notes; Receipt (scan, gallery or file) | Save expense |
| E08 | Expenses | Period; Category | Contextual navigation |
| E09 | Expense details | Read-only summary, links or state | Contextual navigation |
| E10 | Record deposit / withdrawal | Asset; Direction; Amount (UGX); Date; Description; Notes | Review record |

## 04 Reports & analysis

| ID | Screen | Fields / controls shown | Primary action |
|---|---|---|---|
| F01 | Reports | Read-only summary, links or state | Contextual navigation |
| F02 | Wealth statement | Read-only summary, links or state | Review statement |
| F04 | Cash flow | Period | Contextual navigation |
| F05 | Rental income | Read-only summary, links or state | Contextual navigation |
| F06 | Historical trend | Range | Contextual navigation |
| F07 | Asset performance | Read-only summary, links or state | Contextual navigation |
| F08 | Allocation & drift | Read-only summary, links or state | Contextual navigation |
| F08a | Target allocation | Gulu property (%); Treasury bonds (%); Personal savings (%) | Save targets |
| F09 | Valuation history | Read-only summary, links or state | Contextual navigation |
| F10 | Record valuation | Valuation (UGX) *; Valuation date *; Source *; Notes | Save valuation |
| F11 | FX reference rates | Read-only summary, links or state | Contextual navigation |
| F12 | Add FX rate | Currency code *; UGX per unit *; Source *; As of date | Save rate |

## 05 Planning & heritage

| ID | Screen | Fields / controls shown | Primary action |
|---|---|---|---|
| G01 | Financial goals | Read-only summary, links or state | Contextual navigation |
| G02 | Wealth goal | Goal name *; Target amount (UGX) *; Saved amount (UGX); Target date | Save goal |
| G03 | Scheduled contributions | Read-only summary, links or state | Review due contribution |
| G03a | Contribution schedule | Schedule name *; Amount (UGX) *; Frequency; Next due date; Linked asset | Save schedule |
| G04 | Beneficiary intentions | Read-only summary, links or state | Contextual navigation |
| G05 | Beneficiary intention | Full name *; Relationship *; Intended share (%); Notes / intentions | Save intention |
| G06 | Trusted contacts | Read-only summary, links or state | Contextual navigation |
| G06a | Trusted contact | Name *; Relationship *; Email; Phone; Instructions | Save contact |
| G07 | Documents | Search documents; Category | Contextual navigation |
| G08 | Document record | Document title *; Category; Linked asset; Issue date; Expiry date; Notes; Attachment | Save document |
| G09 | Document details | Read-only summary, links or state | Contextual navigation |
| G09a | Manage attachment | Replace file | Review file action |

## 06 Notifications

| ID | Screen | Fields / controls shown | Primary action |
|---|---|---|---|
| H01 | Notifications | Read-only summary, links or state | Contextual navigation |
| H02 | Reminder due | Read-only summary, links or state | Dismiss alert |
| H03 | Notification preferences | Reminders; Document expiry; Stale valuations; Scheduled contributions | Save preferences |
| H04 | Reminders | Read-only summary, links or state | Contextual navigation |
| H05 | Add reminder | Reminder title *; Due date * | Save reminder |

## 07 Account, security & sync

| ID | Screen | Fields / controls shown | Primary action |
|---|---|---|---|
| I01 | More | Read-only summary, links or state | Contextual navigation |
| I02 | My profile | Portfolio owner name | Save profile |
| I03 | Security center | Read-only summary, links or state | Contextual navigation |
| I04 | Enable encryption | New passphrase; Confirm passphrase; I understand local recovery limits | Enable encryption |
| I04a | Manage encryption | Current passphrase | Verify passphrase |
| I04b | Biometric unlock | Read-only summary, links or state | Enroll biometrics |
| I04c | Remove encryption | Current passphrase; I understand records may become less protected | Review removal |
| I05 | Subscription | Read-only summary, links or state | Contextual navigation |
| I06 | Settings | Read-only summary, links or state | Contextual navigation |
| I07 | Help & support | Search help | Copy feedback subject |
| I08 | About LonyoGang | Read-only summary, links or state | Contextual navigation |
| I09 | Export portfolio | I understand the export risk | Review export |
| I09a | Import portfolio | JSON file; Or paste exported JSON | Validate import |
| I10 | Reset portfolio | Type RESET to confirm; Current passphrase if required | Review reset |
| I11 | Data & sync | Read-only summary, links or state | Contextual navigation |
| I12 | Connect online account | Email; Password | Connect account |
| I13 | Create online account | Display name; Email; Mobile; Password | Create account |
| I14 | Verify online account | Email code; Phone code | Verify and sign in |
| I15 | Online privacy & rights | Marketing consent | Save preferences |
| I15a | Account erasure | Current account password; Confirm account erasure | Review erasure |
| I16 | Device sessions | Read-only summary, links or state | Review session |
| I17 | Two-factor authentication | Authenticator code | Verify enrollment |
| I18 | Audit transparency | Read-only summary, links or state | Check audit status |
| I19 | Sync review | Read-only summary, links or state | Contextual navigation |
| I20 | Bank data providers | Read-only summary, links or state | Contextual navigation |

## 08 System states

| ID | Screen | Fields / controls shown | Primary action |
|---|---|---|---|
| X01 | No assets yet | Read-only summary, links or state | Add asset |
| X02 | Loading records | Read-only summary, links or state | Contextual navigation |
| X03 | Could not load records | Read-only summary, links or state | Try again |
| X04 | You are offline | Read-only summary, links or state | Continue locally |
| X05 | Archive record? | Read-only summary, links or state | Confirm archive |
| X06 | Review changes | Read-only summary, links or state | Confirm save |
| X07 | Check your entries | Asset name *; Current value (UGX) * | Review fields |
| X08 | Record saved | Read-only summary, links or state | Return to record |
| X09 | Page not found | Read-only summary, links or state | Contextual navigation |
| X10 | No search results | Search | Clear filters |

## Implementation safeguards

- Preserve the existing domain model, integer UGX accounting, ownership basis points, append-only reversals and single mortgage deduction.
- Asset attachments and receipts must use existing encrypted storage and only be available with the vault unlocked.
- Map proposed fields that are not currently editable (e.g. original principal, optional rate date, separate valuation source) to actual supported models or explicitly implement and test model migration before exposing them.
- Online registration, sync, provider feeds, TOTP, sessions, billing and audit screens depend on runtime capabilities. Never simulate a successful live action.
- Use existing approved logo asset, no recreated logo. Test every form with empty, invalid, valid, large text, keyboard and offline states.
- The sample dashboard uses UGX 390M gross assets and UGX 70M liabilities, net worth UGX 320M. Additional records and histories are illustrative and must not be injected into production.
