# Security boundary — Flutter 0.4.0

## What is now protected

- The persisted portfolio payload is AES-GCM 256-bit authenticated encryption when the user enables a passphrase.
- The symmetric key is derived with PBKDF2-HMAC-SHA-256 and 120,000 iterations over a 16-byte per-vault salt.
- Document attachments are encrypted on write, hashed with SHA-256 for integrity, and decrypted on demand into a per-call temp file.
- Biometric unlock (when the device supports it) stores a device-scoped wrapped passphrase alongside the metadata. It is additive to the passphrase, not a replacement for it.
- The passphrase is never persisted; only a non-reversible fingerprint (HMAC-SHA-256 of the derived key with a fixed string) is kept so a user can be told their input was wrong without revealing the key.

## Clear limitations

- `shared_preferences` continues to host the metadata and the ciphertext. That is intentional: on a non-rooted device the preferences file is in the app sandbox, but a determined attacker with root access could still copy the ciphertext and brute-force the passphrase. Strong passphrases matter.
- There is no server-side recovery. A lost passphrase is unrecoverable from the device alone. Keep an unencrypted JSON export in a safe physical place.
- Attachments are protected at rest by the vault key, but once the user taps "Decrypt and preview" the plaintext briefly lives in the OS temp directory; `open_filex` hands that file to a third-party viewer which may cache it.
- The biometric stash uses a device-scoped secret derived from the metadata salt. This is strictly weaker than an OS keystore and should be replaced by platform-channel integration with Android Keystore / iOS Secure Enclave before production.

## Backend hardening in the 0.4 preview

The optional online service applies the same posture:

- Credential-sensitive endpoints have tight per-route rate limits: `/identity/sessions` 10/min, `/identity/sessions/refresh` 30/min, `/identity/password/reset/begin` 5/hour, `DELETE /me` 3/hour, `/recovery/redeem` 5/hour. The global cap stays at 180/min for sync traffic.
- `DELETE /me` and `/recovery/redeem` require the current password in the body on top of a valid access token. A stolen token on its own cannot erase an account or unseal recovery material.
- Passkey `authenticationOptions` never returns an `allowCredentials` list tied to an email, so an attacker cannot probe the endpoint to enumerate account existence. The authenticator's own resident credential list resolves the correct key, and `verifyAuthentication` derives the accountId from the credential id presented back to us.
- A closed account's sign-in returns the generic `bad_credentials` error plus a decoy Argon2 hash to match the active-path timing. No status-specific error leaks the fact that the email once existed.
- `AccountService.eraseAccount` takes a `SELECT FOR UPDATE` on the row so a concurrent password reset or sync write cannot race the tombstone.
- The audit Merkle chain hashes a canonical JSON with sorted keys. A verifier recomputing the hash from row data lands on the same bytes the writer saw, so a chain tampering attempt cannot hide behind JSON ordering.
- Push transports raise `InvalidPushTokenError` on FCM 404 / `UNREGISTERED` and APNs 410 / `BadDeviceToken`; `PushService.send` deletes the dead row so a bad token isn't retried on every tick.
- Payment webhooks are idempotent at the HTTP layer via a `webhook_idempotency(provider, external_ref)` table; a provider retry after our 5xx cannot double-apply a tier change.
- `FxService` opens a 60s circuit breaker after three consecutive provider failures and serves stale cache during the open window so a dead upstream cannot stall `/fx/rates`.
- Attachment quotas follow the subscription tier (free 100 MB, heritage 2 GB, legacy 10 GB) and are enforced on presign — a downgrade shrinks quota on the next upload.
- `AggregationService.sync` calls the provider's `describe()` first and marks the connection `reauth_required` on failure, so an expired bank token cannot leave the row half-synced.

## Before production

Per-owner authentication and authorization backed by a real identity provider; passkey/MFA option; server-backed key escrow (optional, opt-in, user-controlled); OS keystore integration; encrypted backups with restore testing; lawful processing/consent artefacts; tamper-resistant transaction audit and reversal approval; access logging; incident response; device-session revocation; OWASP MASVS L2 assessment; penetration testing. The 0.4 preview is still a local-only product: do not expose it to real identity or account credentials.
