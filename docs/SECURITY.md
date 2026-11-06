# LonyoGang Heritage security and privacy boundary

LonyoGang is an **offline encrypted personal record keeper**, not a regulated financial service or bank connection.

## Controls implemented
- SQLCipher database encrypts the vault and stored document BLOBs at rest.
- Random database secret stored in OS-protected keystore/keychain via flutter_secure_storage.
- Access PIN salted PBKDF2-HMAC-SHA256 verifier (150,000 iterations) in secure storage.
- Optional device biometrics using local_auth, Android USE_BIOMETRIC and FlutterFragmentActivity.
- No bank credentials, external account tokens, cloud sync or telemetry sent by app code.
- Asset valuation source, ownership share and date recorded explicitly.
- Confirmation before exporting CSV or unencrypted document shares; destructive erase asks confirmation.
- Documents capped at 12 MB and held as encrypted local records.

## Limitations
- The SQLCipher passphrase currently lives in OS-protected storage and is **not encrypted under the user's PIN**. The PIN is an application gate, not cryptographic device-compromise protection. There is no rate limiting or durable attempt throttling across app restarts.
- No cloud recovery, device-independent encrypted backup or multi-device access. Device loss or deletion may result in irreversible data loss; maintain external backups carefully.
- CSV exports and shared document copies leave encryption. These copies are not deleted from recipients or other applications when the original vault is erased.
- Beneficiary records do **not** confer inheritance rights, title or legally valid nominations. Owner estimates are not verified valuations.
- Production threat modelling, code audit, Android/iOS device QA, automated restoration tests, privacy/compliance review and release signing are outstanding. Treat this build as an MVP until those gates are complete.

Do not commit passwords, live financial records, customer files, secrets or the confidential SRS to this public GitHub repository.
