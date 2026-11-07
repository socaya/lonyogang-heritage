# LonyoGang Heritage — backend

Node 20 + TypeScript + Fastify service that implements the plan in
`../docs/ONLINE_SERVICE_PLAN.md`. Every backend-gated spec item has a real
handler here; nothing is a stub.

## What ships

- **Identity** (`POST /identity/accounts`, `/verify`, `/sessions`,
  `/sessions/refresh`, `/sessions/:id`, `/totp`, `/password/reset/*`,
  `/passkeys/*`). Argon2id passwords, Ed25519-signed JWTs, SHA-256 hashed
  refresh tokens with rotation, real WebAuthn Level 3 via
  `@simplewebauthn/server`, anti-enumeration password reset.
- **Zero-knowledge sync** (`POST /sync/events`, `GET /sync/events`,
  `PUT /sync/envelope`, `GET /sync/envelope`). Server stores ciphertext
  plus a Merkle hash chain. Plaintext integrity assertions (asset
  ownership basis points, beneficiary 100% cap, non-negative ledger
  amounts) are enforced server-side without decrypting anything.
- **Attachment relay** (`POST /sync/attachments`, `/:id/commit`,
  `GET /:id`, `DELETE /:id`). Presigned S3 upload/download URLs with
  per-account quotas and SHA-256 integrity.
- **FX feed** (`GET /fx/rates`). Pluggable provider adapters:
  `exchangerate.host`, Bank of Uganda scrape, deterministic mock. Cache
  fallback returns clearly labelled stale rows when the provider is
  unreachable.
- **Shamir recovery** (`POST /recovery/enroll`, `/redeem`). Splits the
  vault wrap key 2-of-3 across the device, server (KMS-sealed) and a
  printable sheet whose hash the server stores.
- **Bank aggregation** (`POST /bank/connections`, `/:id/sync`, …). Pluggable
  `BankProvider` interface with real Stanbic Partner API and MTN MoMo
  Collections adapters plus a deterministic mock.
- **Payments** (`POST /webhooks/flutterwave`, `/webhooks/stripe`). Real
  Stripe HMAC and Flutterwave hash signature verification; subscription
  tier updates audited.
- **Push** (`POST /push/tokens`, …). FCM HTTP v1 and APNs HTTP/2 transports
  with cached provider JWTs; dev console transport by default.
- **Audit log** (`GET /audit/entries`, `/audit/chain`). Append-only
  Merkle-chained log per account with a chain-verify endpoint for
  weekly transparency anchoring.

## Running it locally

```bash
cd backend
cp .env.example .env         # fill in JWT keys + KMS master key
docker compose up -d         # Postgres + MinIO + MailHog
pnpm install
pnpm migrate
pnpm dev
```

Generate JWT keys:

```bash
openssl genpkey -algorithm ed25519 -outform pem -out jwt-priv.pem
openssl pkey -in jwt-priv.pem -pubout -outform pem -out jwt-pub.pem
export JWT_PRIVATE_KEY_PEM="$(cat jwt-priv.pem)"
export JWT_PUBLIC_KEY_PEM="$(cat jwt-pub.pem)"
```

Generate the KMS master key:

```bash
openssl rand -base64 32    # paste into KMS_MASTER_KEY_B64
```

## Testing

```bash
pnpm test
```

The vitest suite boots a disposable Postgres container through
`testcontainers`, runs real migrations, and exercises the Fastify app via
`app.inject(...)`. Expect the first run to pull `postgres:16-alpine`.

## Security notes

- Attachments are AES-GCM encrypted on the device before upload. The server
  only ever handles opaque bytes plus the client-declared SHA-256.
- Passkeys never store biometric templates; only credential public keys
  and counters.
- Shamir shares use `shamirs-secret-sharing`; the server share is sealed
  via AES-256-GCM with the account id as AAD.
- JWTs are Ed25519-signed; refresh tokens are 32 bytes of CSPRNG output,
  SHA-256 hashed at rest.
- All sensitive actions (`account.signup`, `session.opened`,
  `recovery.enrolled`, `recovery.redeemed`, `recovery.redeem_failed`,
  `subscription.updated`, …) append to a per-account hash-chained audit
  log.

## Remaining operational work before production

- Deliver email + SMS OTP via a real provider (SES, SendGrid, Africa's
  Talking). The current code returns the generated code to the caller for
  integration tests only.
- Point the KMS adapter at AWS KMS / GCP KMS / an HSM instead of the
  local AES-256-GCM envelope.
- Register the Uganda DPPA 2019 controller notice and publish the data
  processing policy.
- Wire the weekly transparency anchor job (opentimestamps / a notary
  service) to publish `audit_entries` tip hashes.
- Load-test and tune the rate-limit configuration.
