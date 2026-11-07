# Uganda Data Protection and Privacy Act, 2019 — compliance playbook

**Document ID:** LGH-COMP-DPPA-2019-001
**Status:** operational playbook for the LonyoGang Heritage backend.
**Audience:** data controller, data protection officer, product engineer on call.
**Last reviewed:** 2026-11-07.

This document is a playbook, not legal advice. It describes the concrete
steps the LonyoGang Heritage backend takes to meet the obligations of the
Uganda Data Protection and Privacy Act, 2019 (the "Act") and the Data
Protection and Privacy Regulations, 2021 (the "Regulations"). Every item
maps to a specific section of the Act or the Regulations.

---

## 1. Data controller registration

| Act reference | Obligation | How we satisfy it |
|---|---|---|
| s. 29 of the Act; reg. 6 of the Regulations | Register as a data controller with the Personal Data Protection Office (PDPO) | Submit the registration form annually to the PDPO. Current controller of record: *LonyoGang Heritage Ltd.*, Kampala. Registration number tracked in `config:pdpo.registrationNumber`. |
| reg. 6(3) | Keep the entry current (controller name, DPO contact, categories of data, purposes) | Any time we change a processing purpose, the DPO opens a ticket under label `compliance:pdpo-update` and refiles within 30 days. |

**On-call action:** before a new release that adds a new personal-data field
or a new processing purpose, open a PR against this document and the PDPO
registration file. Block the release on the DPO's signoff.

## 2. Data Protection Officer

| Act reference | Obligation | How we satisfy it |
|---|---|---|
| reg. 10 | Appoint a Data Protection Officer with contact details on the website and in-app | DPO contact (`privacy@lonyogang.com`) surfaced on `/healthz`, in the client's `AboutScreen` and in every onboarding email. |
| s. 5(1)(g); reg. 11 | DPO must be reachable by data subjects | We open an inbox + ticket queue monitored during business hours; a target SLA of 5 business days for acknowledgement is tracked in Datadog SLO `privacy-ack`. |

## 3. Principles of data protection (s. 3 of the Act)

| Principle | Implementation |
|---|---|
| Accountability | Every sensitive action appends to the Merkle-chained `audit_entries` table; transparency anchors publish the tip hash weekly to OpenTimestamps. |
| Fairness | Sign-up collects the minimum: email, optional phone, optional display name, optional recovery contact. |
| Lawfulness | Purposes are documented in §5. The user signs an explicit consent at account creation (`CreateAccountStep1Screen` terms checkbox). |
| Collection for a specified purpose | Payloads above the identity layer are AES-GCM encrypted on the device; the server holds ciphertext only. |
| Minimum necessary | We store ciphertext, counters and derived metadata. We never see portfolio plaintext or biometric templates. |
| Retention | Session refresh tokens are SHA-256 hashed; OTP codes are SHA-256 hashed with a pepper and expire in 15 (sign-up) / 30 (reset) minutes; raw passwords are never persisted. |
| Transparency | `/healthz` exposes the controller contact; the audit log is readable by the user via `GET /audit/entries`; anchors via `GET /audit/anchors`. |
| Integrity | Attachments are SHA-256 verified on read; every audit entry is chained; transparency anchors are notarised. |

## 4. Lawful bases for processing (s. 7 of the Act)

Every processing activity must declare its lawful basis. Current bases:

- **Consent (s. 7(1)(a)):** sign-up, push-token registration, biometric
  unlock stash, discretionary marketing.
- **Contract (s. 7(1)(b)):** operating the owner profile, running the
  subscription, honouring the data-subject rights channel.
- **Legal obligation (s. 7(1)(c)):** tax record retention when a paid
  subscription is active, PDPO reporting duties.
- **Vital interests (s. 7(1)(d)):** denying a sign-in attempt that looks
  like a credential-stuffing attack to protect the account holder.
- **Legitimate interests (s. 7(1)(e)):** rate limiting, fraud prevention,
  Merkle-chained audit, transparency anchoring.

Marketing uses rely on an explicit, revocable consent captured in
`accounts.marketing_consent_at` (nullable; `null` means "no consent").

## 5. Specific categories of data we process

| Category | Collected? | Why | Lawful basis | Retention |
|---|---|---|---|---|
| Email | Yes | Account identifier + OTP delivery | Contract | Life of account |
| Phone number | Optional | Second OTP channel, SMS alerts | Consent | Life of account |
| Display name | Optional | UI personalisation | Consent | Life of account |
| Password | Hashed only (Argon2id) | Authentication | Contract | Life of account; wiped on close |
| TOTP seed | Encrypted (KMS-sealed) | 2FA | Consent | Life of account |
| Passkey public key + counter | Yes | WebAuthn authentication | Contract | Life of account |
| Vault ciphertext | Yes (opaque) | Multi-device sync | Contract | Life of account |
| Attachment ciphertext | Optional | Document retention | Contract | Life of account or until user deletion |
| Bank-connection token | Encrypted (KMS-sealed) | Open-banking read-only access | Consent | Until user revokes |
| Push token | Optional | Delivery of near-due reminders | Consent | 90 days inactive → deleted |
| Payment reference id | Yes | Receipts, chargeback handling | Legal obligation | 7 years |
| IP + user-agent of session | Short-lived in logs | Fraud prevention | Legitimate interest | 30 days |
| Access/refresh tokens | Hashed only | Session management | Contract | Until logout / expiry |

**Special categories** (s. 9 of the Act — health, religion, political views,
sexual orientation, criminal records): *not processed*. The product is not
designed for them; our UX validators and server-side input policies reject
such inputs when detected.

## 6. Data-subject rights (ss. 24–28 of the Act)

Each right has a code path. Delays beyond 7 business days are escalated to
the DPO.

| Right | Endpoint / ops procedure |
|---|---|
| Right to be informed (s. 24) | Privacy notice on the website; same notice linked in-app via the "Privacy & data" help page. |
| Right of access (s. 25) | `GET /me/export` returns a JSON bundle of every row where `account_id = me`. A portable-encrypted archive is available on request through the DPO inbox. |
| Right to correction (s. 26) | `PATCH /identity/accounts/me` handles the identity fields; vault content corrections happen client-side and sync as new events. |
| Right to erasure (s. 27) | `DELETE /me` tombstones the account, revokes all sessions, deletes attachments from S3, and clears vault envelopes. Legal-hold records (payment refs under audit retention) are kept in encrypted archive, as required by s. 7(1)(c). |
| Right to object / withdraw consent (s. 28) | Marketing opt-out endpoint + server-side rate limits. Withdrawing consent revokes the corresponding token (push, biometric stash, bank connection) immediately. |
| Right to not be subject to automated decisions | We do not take binding automated decisions. Fraud scoring is informational; a human reviews any lockout. |

Data-subject requests can also arrive by email, in writing or through the
PDPO portal. The ops runbook `runbooks/privacy-requests.md` tracks them to
closure.

## 7. Cross-border transfers (s. 19 of the Act)

The primary production region is **GCP `europe-west1`** (or **AWS
`af-south-1`**). The Act permits a transfer only if the destination
provides "adequate protection". Our current declaration (see PDPO
registration appendix B) is:

- **Primary processor:** Google Cloud EMEA — approved by the PDPO as part
  of the existing 2024 registration.
- **DR replica:** South Africa — recognised as an adequate jurisdiction
  under reg. 29(2).
- **Transactional email:** SendGrid (Twilio) US — covered by the EU-US
  Data Privacy Framework; we execute the SCC addendum documented in
  `contracts/sendgrid-scc.pdf`.
- **SMS:** Africa's Talking — Kenya processor, covered by the EAC regional
  adequacy decision.
- **OpenTimestamps calendars:** hashes only. No personal data crosses the
  border because we submit a 32-byte digest.

## 8. Breach notification (s. 23 of the Act; reg. 32)

The Act requires notification to the PDPO *and* affected data subjects
"within 72 hours" of becoming aware of a breach. Steps the on-call engineer
runs when Datadog alert `security.unauthorized-access` fires:

1. Freeze the affected service and page the DPO (`pager://dpo`).
2. Collect the window of audit entries via `GET /audit/entries` filtered on
   the suspected actor_id.
3. Rotate the suspected sessions (`UPDATE sessions SET revoked_at = now()
   WHERE ...`).
4. Draft the PDPO notification using `templates/pdpo-breach.md`.
5. Email affected data subjects using the queued template under
   `templates/data-subject-breach.md`.
6. File the formal notice to the PDPO within 72 hours of detection.
7. Post an incident report to the public status page within 7 days.

## 9. Retention and destruction

- Access and refresh tokens: revoked on logout or 30 days after issue.
- OTP codes: 15 minutes (sign-up) / 30 minutes (reset).
- Audit entries: retained for the life of the account; anchored weekly.
- Attachments: deleted on user request or account closure.
- Payment event ledger (`payment_events`): 7 years for tax; encrypted at
  rest and off-site.
- Database backups: encrypted at rest; retention 30 days hot + 1 year cold.
- Log retention: structured logs 30 days; PII redacted at write time by
  the pino redaction list in `logger.ts`.

## 10. Record of processing activities (RoPA)

`docs/RoPA.csv` (generated quarterly by `pnpm ropa`) lists every processing
activity, its purpose, lawful basis, categories, recipients, retention and
cross-border notes. The DPO signs the CSV and files it with internal
audit.

## 11. DPIA triggers

Any of these triggers a Data Protection Impact Assessment ahead of release:

- Processing of a new special category of data (we do not currently).
- Automated decision making with legal effect.
- Large-scale systematic monitoring.
- Cross-border transfer to a new jurisdiction.
- Any change to the audit-log retention or anchoring cadence.

The template is `docs/DPIA_TEMPLATE.md` and the completed DPIA lives next to
the migration that introduces the change.

## 12. Operational tooling checklist

- ✔ `pnpm anchor` — runs the weekly transparency anchor pass.
- ✔ `GET /healthz` — includes DPO contact + build revision.
- ✔ Backup encryption: Postgres base backups are sealed with the configured
  KMS (local or AWS) before leaving the production boundary.
- ✔ Access logs: NGINX edge logs rotated daily; redacted of authorization
  headers before shipping to Datadog.
- ✔ Privacy inbox: `privacy@lonyogang.com` monitored during business hours
  with a 5 business-day acknowledgement SLO.
- ✔ Vendor list reviewed quarterly against reg. 29.

## 13. Updates

Any amendment to the Act or Regulations must be reflected here within 15
days of publication. This file is referenced in the release PR template.
