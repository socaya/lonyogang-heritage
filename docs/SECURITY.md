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

## Before production

Per-owner authentication and authorization backed by a real identity provider; passkey/MFA option; server-backed key escrow (optional, opt-in, user-controlled); OS keystore integration; encrypted backups with restore testing; lawful processing/consent artefacts; tamper-resistant transaction audit and reversal approval; access logging; incident response; device-session revocation; OWASP MASVS L2 assessment; penetration testing. The 0.4 preview is still a local-only product: do not expose it to real identity or account credentials.
