# LonyoGang Heritage — Online service plan

**Document ID:** LGH-BACKEND-PLAN-001
**Version:** 0.1 · draft
**Last updated:** 2026-11-07
**Scope:** server-backed capabilities needed to retire the "backend-gated" caveats in `docs/CLAUDE_UI_IMPLEMENTATION_REQUIREMENTS.md §4`.
**Primary client:** Flutter 0.4 local-alpha (this repository).
**Status:** this document is a plan, not a contract. Nothing in this file constitutes an implementation claim or a security assurance.

---

## 0. Guiding principles

1. **The device is still the source of truth.** The client vault keeps working offline. The online service is additive — synchronisation, recovery, aggregation and identity — never a prerequisite for using the app.
2. **End-to-end encryption by default.** The server stores ciphertext for every record that currently lives inside the AES-GCM vault. Server-side search and reporting only operate on fields the user has explicitly opted to disclose (e.g. category names, non-sensitive aggregates).
3. **Honest gating.** Every UI element the client already labels "Not connected" stays truthful. A feature only flips to "Connected" after an end-to-end integration test passes against the production service.
4. **Opt-in cloud.** A user can keep running the app forever in local-only mode. Enabling sync is a deliberate flow that explains exactly what leaves the device.
5. **Small blast radius.** Authentication, payments, bank aggregation and sync are separate services with narrow scopes so one compromise does not cascade.

---

## 1. Spec items this plan addresses

| Spec ID | Current state | Addressed by |
|---|---|---|
| A06 Sign in | Prototype UI only | §3 Identity |
| A09 OTP verification | Prototype | §3 Identity |
| A10 Account recovery | Prototype | §3.5 Recovery |
| A11 Passkey enrolment | Not available | §3.3 Passkeys |
| F feature-set live FX | Not integrated | §6 FX service |
| Bank feeds (open banking) | Not integrated | §7 Account aggregation |
| Payment processing | Not integrated | §8 Billing |
| Tamper-resistant audit log | Not integrated | §9 Audit service |
| Multi-device sync | Not integrated | §4 Sync |
| Server-backed passphrase recovery | Not available | §3.5 Recovery (Shamir) |
| Scheduled push notifications | Local only | §10 Notifications |

---

## 2. High-level architecture

```
                 ┌──────────────────────────────────┐
                 │ Flutter client (iOS / Android)   │
                 │  - Local vault (AES-GCM, PBKDF2) │
                 │  - Sync agent                    │
                 │  - Passkey platform binding      │
                 └───────────────┬──────────────────┘
                                 │ HTTPS 1.3 · mutually-pinned
                                 ▼
 ┌───────────────┐   ┌────────────────────┐   ┌────────────────────┐
 │ Identity svc  │◄──┤ API gateway        ├──►│ Sync service       │
 │ OIDC, passkey │   │ (rate limit, waf)  │   │ (ciphertext only)  │
 └───────┬───────┘   └─────────┬──────────┘   └──────────┬─────────┘
         │                     │                         │
         ▼                     ▼                         ▼
 ┌───────────────┐   ┌────────────────────┐   ┌────────────────────┐
 │ Audit log svc │   │ FX feed service    │   │ Payments service   │
 │ append-only   │   │ (rate oracle)      │   │ (checkout, invoice)│
 └───────────────┘   └────────────────────┘   └────────────────────┘
                                 │
                                 ▼
                     ┌────────────────────┐
                     │ Account aggregation │
                     │ (open-banking)      │
                     └────────────────────┘
```

Each box is a separate service with its own database, operator, SLA and failure mode. The API gateway is the only public surface. Everything else lives in a private subnet.

### 2.1 Hosting choice

- **Primary region:** Africa / East (preferred: Google Cloud `europe-west1` with a Nairobi edge, or AWS `af-south-1` in Cape Town). Latency from Uganda to both is ~60–90 ms. Data residency expectations under the Uganda Data Protection and Privacy Act 2019 strongly prefer in-region storage.
- **Secondary:** cold replica in a second region (DR only, never user-facing).
- **Edge:** Cloudflare or AWS CloudFront for TLS termination, bot mitigation, OWASP CRS.
- **Stack:** stateless services in Go or Kotlin (JVM) behind the gateway; Postgres as the primary datastore; S3-compatible object storage for ciphertext attachments; Redis for ephemeral locks + rate limits.

### 2.2 Why not serverless-first

Zero-knowledge sync requires careful control of request latency, key-wrapping round-trips and streaming attachment uploads. Containers on a managed Kubernetes or Cloud Run give predictable knobs for these without the 15-minute lambda ceiling.

---

## 3. Identity service (A06, A09, A10, A11)

### 3.1 Standards

- **OIDC core** for the browser-based onboarding paths and third-party integrations.
- **WebAuthn Level 3** for passkeys (device-bound and synced via the OS credential manager).
- **RFC 6238 TOTP** as the fallback second factor.
- **Email + phone OTP** via a transactional mail provider and a Uganda-specific SMS gateway (e.g. Africa's Talking or a Mobile Money aggregator).

### 3.2 Flow — first-time sign-up

1. Client POSTs `{email, phone, display_name}` to `/identity/accounts`. Server returns `account_id` and a pending-verification record.
2. Server issues an email OTP and an SMS OTP. Client collects both on `A09 OtpVerificationScreen`. Server marks either channel verified when the correct code is submitted within the TTL; both must be verified before the account is `active`.
3. Client is invited to enrol a passkey (`A11`). We call `PublicKeyCredential.create` through the Flutter `local_auth` plus a WebAuthn bridge plugin. The resulting attestation is stored under the account.
4. Client generates its vault salt (unchanged from 0.4) and pushes a **key-wrapping blob** (see §5) so the user can recover after losing a device.

### 3.3 Passkeys

- Store **only the attestation public key**. No biometric templates ever leave the device.
- A user can bind multiple passkeys (one per device). Enrolling a new device requires an authenticated session on an existing device or a recovery flow.
- Fallback: when the device cannot do WebAuthn, the user can sign in with email + password + TOTP. Password hashing: Argon2id with parameters `memory=64MiB, iterations=3, parallelism=1`, server-side pepper rotated annually.

### 3.4 Sessions

- Short-lived access tokens (15 min, JWT, Ed25519-signed) + opaque refresh tokens (30 d) stored in the client keychain.
- Refresh binds to the device id and the user-agent hash. Suspicious rotation (impossible-travel heuristics) invalidates the chain and forces a step-up.
- Server-side session revocation: `DELETE /identity/sessions/{id}` is immediate; the access-token blacklist lives in Redis for the remaining 15 min.

### 3.5 Account recovery (A10, server-backed recovery of the vault key)

- The passphrase stays on the device. The server **never** stores it.
- At sign-up we offer the user a **Shamir split** of a *vault-wrap key* (not the passphrase-derived key) into three shares: one stays on the primary device, one is stored encrypted under a server-side HSM-held envelope key, one is given to the user as a printable recovery sheet.
- To recover, the user signs in with the passkey or email+TOTP, reconstructs two of the three shares, and re-derives the wrap key. The wrap key unseals the ciphertext payload copy that the server holds.
- This is explicitly opt-in. The UI must spell out that the printable sheet is *the* backup.

---

## 4. Sync service (multi-device, zero-knowledge)

### 4.1 Model

Treat the client state as an **event log**. Every create / update / archive produces an immutable event with:

- `event_id` (ULID, client-generated)
- `account_id`
- `device_id`
- `created_at` (client clock, hybrid logical clock piggyback)
- `payload` — the encrypted serialized record, AES-GCM under a per-account **content key**
- `payload_type` — a non-secret tag (`asset`, `liability`, `event`, `valuation`, `attachment_ref`, `goal`, `contact`, `beneficiary`, `reminder`, `document_meta`, `fx_rate`, `schedule`)
- `prev_hashes` — Merkle-chained hash of the previous events this device observed

The server stores the events verbatim. It cannot read `payload` because it never has the content key. It uses `payload_type` for routing and quota accounting.

### 4.2 Conflict resolution

- Per-record "last-write-wins by hybrid logical clock" for scalar fields.
- Append-only invariants for the ledger: `LedgerEvent` entries can never be deleted server-side. Reversals are appended; original IDs stay.
- Beneficiary totals are validated client-side before encrypting and pushing; the server rejects events whose `payload_type = beneficiary_batch` when the declared total basis points exceed 10,000 (this requires the client to emit a short plaintext integrity metric alongside the ciphertext).

### 4.3 Content key lifecycle

- A per-account content key is derived from the vault-wrap key (§3.5). Rotation happens on passphrase change: the new content key is pushed and the old key is marked `rotated_at`.
- Server stores the key-wrapped envelope so a new device can bootstrap without the user re-entering history.
- Rotation does **not** re-encrypt past events. Past events stay readable with the old content key, which lives on the primary device until the user confirms rotation success.

### 4.4 Transport

- TLS 1.3 only. HSTS preload.
- Mutual pinning of the server certificate inside the Flutter client (plus a one-shot rotation window).
- Request signing (`Signature-Input: @method @path content-digest`) tied to the current session key so replay is bounded.

### 4.5 Attachment sync

- The client encrypts attachments locally (already shipped in 0.4). Uploads go to S3-compatible object storage via a signed URL issued by the sync service.
- The server never sees the key; it only sees opaque bytes, a size and the SHA-256 the client already records. The hash gives us integrity checking without decrypting.
- Quota: default 2 GB per account, higher tiers in §8.

### 4.6 Offline

- The client queues events in a local outbox table.
- Flush order: identity → vault state → ledger → attachments.
- Attachments are flushable in parallel and resumable; each chunk is independently uploaded with a content-range header.

---

## 5. Server-side ciphertext data model

Normalised Postgres schema (ciphertext fields are `bytea`):

```sql
accounts (
  id uuid primary key,
  email citext unique,
  phone text,
  display_name_cipher bytea,     -- optional, only if user opted in
  created_at timestamptz,
  status text check (status in ('pending','active','locked','closed'))
);

passkeys (
  id uuid primary key,
  account_id uuid references accounts,
  credential_id bytea,
  public_key bytea,
  sign_count bigint,
  transports text[],
  created_at timestamptz,
  last_used_at timestamptz
);

sessions (
  id uuid primary key,
  account_id uuid references accounts,
  device_id uuid,
  refresh_hash bytea,
  expires_at timestamptz,
  revoked_at timestamptz
);

vault_envelopes (
  account_id uuid primary key references accounts,
  wrapped_content_key bytea,      -- wrapped under the vault wrap key
  shamir_share_cipher bytea,      -- our share, HSM-sealed
  rotated_at timestamptz,
  version int
);

events (
  id ulid primary key,
  account_id uuid references accounts,
  device_id uuid,
  payload_type text,
  payload bytea,
  prev_hash bytea,
  created_at timestamptz
);
create index on events (account_id, created_at);

attachment_blobs (
  id uuid primary key,
  account_id uuid references accounts,
  bucket_key text unique,
  size_bytes bigint,
  sha256 bytea,
  uploaded_at timestamptz
);

audit_entries (
  id ulid primary key,
  account_id uuid references accounts,
  actor_kind text,
  action text,
  resource text,
  context_cipher bytea,
  prev_hash bytea,
  hash bytea,
  created_at timestamptz
);
```

The `prev_hash` / `hash` columns on `audit_entries` form a Merkle chain. We publish the tip hash into a transparency log weekly (§9).

---

## 6. FX feed service (F feature-set)

### 6.1 Providers

Primary: Open Exchange Rates or exchangerate.host — 1-minute granularity for majors, hourly for exotics. UGX is quoted against USD, EUR, GBP, KES and TZS at minimum.

Fallback: Bank of Uganda daily reference rate. Scraped from the official PDF with a hash check and a human-review alert.

### 6.2 Shape

- `GET /fx/rates?base=UGX&as_of=2026-11-07` → signed list of `(currency, ugxPerUnit, asOf, source)`. Signed because the client wants to attribute historical conversions.
- Rates are cached per user with a 30-minute TTL, and the client falls back to the user's manually entered `FxRate` table when the server is unreachable (already modelled in `domain/models.dart`).

### 6.3 Compliance

- No personal data flows into this service. It's pure market data, publicly priced.

---

## 7. Account aggregation / bank feeds

### 7.1 Open-banking landscape in Uganda

As of 2026-11 there is no national open-banking mandate. Practical options:

- **Stanbic (Standard Bank group)** publishes a partner API.
- **Centenary Bank** exposes account summaries through the Flutterwave Partner API.
- **Mobile Money (MTN MoMo, Airtel Money)** offers transaction history to approved partners.
- Private aggregators (e.g. Mono, Okra) now cover UGX accounts at a few banks.

### 7.2 Architecture

- Aggregation service holds **per-provider connectors** behind one unified read API. Each connector normalises the provider's quirks into our `LedgerEvent` + `WealthAsset` domain.
- The service never writes to the user's bank. Read-only mandates only.
- Credentials with the provider live in a KMS-sealed secret. The user's device never sees provider-level tokens.
- Users consent per connection (`Scope`, `Expiry`, `Permitted-datum`). Revocation is one-tap.

### 7.3 Data path

1. User links a provider via OAuth consent in a bundled web view.
2. Aggregation service pulls transactions nightly, deduplicates by provider reference, and emits events into the sync service **as if they came from the user's primary device**. The emit is tagged `payload_type = ledger_import` so the client can surface them as imports.
3. The user approves or rejects the imported events on-device before they affect net worth; this keeps the "user-entered value" invariant from §4 of the UI spec.

---

## 8. Payments and billing

### 8.1 Processor choice

- **Flutterwave** for Uganda card + mobile money.
- **Stripe** as a secondary for international card-holders.
- **Paystack** backup; multi-processor failover reduces checkout abandonment.

### 8.2 Subscription tiers (placeholder, not priced yet)

| Tier | Attachment quota | Multi-device | Audit retention | Price (TBD) |
|---|---|---|---|---|
| Free | 100 MB | 1 | 90 days | UGX 0 |
| Heritage | 2 GB | 3 | 3 years | TBD |
| Family | 10 GB | 5 | 7 years | TBD |

### 8.3 Compliance

- PCI-DSS SAQ-A path: cards never touch our servers. Flutterwave / Stripe host the card input.
- Receipts are emailed. Invoices can be downloaded as PDF from the account settings.

---

## 9. Audit service

### 9.1 Scope

Covers **server-visible actions**: sign-in, session refresh, passkey enrolment, consent change, attachment upload, bank-connection authorise/revoke, billing event. Encrypted-payload events are logged by hash only (opaque).

### 9.2 Integrity

- Append-only Postgres table (see §5) with per-account Merkle chain.
- Nightly tip-of-chain publication to a transparency log we operate; weekly snapshot anchored to a third-party notary (e.g. opentimestamps).
- Readable by the user from `GET /audit/entries`. The client renders them under `I11 DataSyncStatusScreen` once the service exists.

---

## 10. Scheduled notifications

The 0.4 client already uses `flutter_local_notifications` for on-device scheduling. The server adds:

- **Reminders replicate across devices**: when device A marks a reminder complete, device B dismisses its local notification.
- **Push via FCM / APNs** for reminders that fire while the client process is dead. Payload: only the alert id (opaque); the client expands it against its local state so no plaintext leaks via the push channel.
- Subscription-tier gating: free tier retains local notifications only. Paid tiers get push.

---

## 11. Compliance checklist

- **Uganda Data Protection and Privacy Act, 2019.** Register with the Personal Data Protection Office. Publish a data-processing notice. Honour data-subject access and deletion within 7 business days.
- **GDPR adjacency.** Many users have EU ties; align with GDPR Articles 15, 16, 17, 20.
- **FCDO sanctions screening** on new sign-ups.
- **PCI-DSS SAQ-A** (see §8).
- **ISO 27001** target for year 2 after launch.
- **Independent penetration test** before every major release; last report linked from the status page.
- **Bug bounty** on a managed platform (HackerOne or Intigriti) after MVP.

---

## 12. Client-side surface

The Flutter client introduces a `SyncService` abstraction in `lib/data/sync.dart`. The current build ships only `NoopSyncService` so every screen still truthfully says "Not connected". When the backend lands we bind a `RemoteSyncService` that calls `/sync/events` / `/sync/attachments` without any other UI rewrite.

- `SyncStatus { disconnected, connecting, ready, syncing, error, offline }`.
- `SyncService.status` is a `ValueListenable<SyncStatus>`.
- `SyncService.sync()` is a no-op in the Noop impl; the real impl posts the outbox and pulls new events since a cursor.
- `DataSyncStatusScreen` subscribes to the status and renders it honestly. No status says "Ready" until the service exists and an integration test proves a round-trip.

---

## 13. Phased rollout

| Phase | Months | Deliverable | UI surfaces unlocked |
|---|---|---|---|
| 0.5 | 1–3 | Identity, sessions, passkey enrolment, encrypted event sync (text records only), audit log | A06, A09, A10, A11, multi-device sign-in |
| 0.6 | 4–5 | Attachment sync, Shamir recovery, server-backed reminders & push | A08 real, I11 live status, cross-device reminders |
| 0.7 | 6 | FX service | Correct historical FX conversions on reports |
| 0.8 | 7–9 | Payments & subscription enforcement | I05 Subscription real, attachment quota enforcement |
| 0.9 | 10–11 | Bank aggregation (Stanbic + MoMo + Mono) | Transactions auto-import workflow |
| 1.0 | 12 | Compliance certifications + independent pen-test | "Verified" badge in SecurityCenter |

Each phase is cut only after a documented round-trip test from the Flutter CI against a staging stack.

---

## 14. Open questions

1. **Shamir sheet UX.** Where does the user store the printable sheet? Do we offer a bank-grade safe deposit guide? A Qr-encoded version?
2. **MoMo transaction granularity.** Older MoMo tokens batch transactions; some fields the client needs (merchant, FX margin) are not exposed. Do we require the user to annotate manually or deprioritise MoMo?
3. **Shared / joint portfolios.** The 0.4 domain is single-owner. Adding joint ownership changes the sync key model (per-share keys? per-portfolio?). Decision needed before 0.9.
4. **Regulated advice.** The app does not give advice. Any analytics we surface server-side (allocation drift, historical returns) must remain descriptive, not prescriptive. Formal legal review required before marketing copy changes.
5. **Deletion vs tombstoning.** Hard-deleting ciphertext events breaks the Merkle chain. Likely answer: keep tombstones forever; users requesting Article 17 erasure trigger a full account rekey + rewrite.

---

## 15. References

- **Uganda Data Protection and Privacy Act, 2019** (laws.go.ug publication).
- **NIST SP 800-63B** — passkey-and-password guidance.
- **WebAuthn Level 3** — W3C recommendation.
- **RFC 8949 / COSE, RFC 9052** — key wrapping formats.
- **OpenID Connect Core 1.0** — identity flows.
- **PSD2 open-banking patterns** — adapted; no EU regulator applies directly.
- **Signal Protocol** — informed the zero-knowledge sync design but we do not need the full double-ratchet since content keys are per-account, not per-conversation.

---

## 16. Non-goals

- Investment advice, order execution or custody.
- Real-time quote streaming (we batch; manual valuations stay the default).
- KYC-regulated financial products (money transmission, remittance). The service remains a personal record-keeping tool.
- Shared access between multiple accounts (deferred; see §14.3).
