# Security boundary

Alpha is **offline demonstration-only**. `shared_preferences` is not appropriate for confidential portfolio records without OS-backed encryption and a threat model. The app intentionally offers no real password, passkey, biometric account validation or bank integration. JSON exports go to system clipboard with a warning. Credentials and real identities must not be entered.

Before production: per-owner authentication and authorization, key management, encrypted DB, secure backups and restore, lawful processing/consent, tamper-resistant transaction audit and reversal approval, access logging, incident response, device session revocation, OWASP MASVS assessment and penetration testing.
