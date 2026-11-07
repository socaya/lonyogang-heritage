/**
 * Record of Processing Activities (RoPA) rows. One entry per distinct
 * processing activity we carry out under the Uganda Data Protection and
 * Privacy Act, 2019. `pnpm ropa` renders this list into docs/RoPA.csv for
 * the DPO file.
 */
export interface RopaRow {
  activity: string;
  purpose: string;
  lawfulBasis: string;
  dataCategories: string;
  recipients: string;
  retention: string;
  crossBorder: string;
  sourceTables: string[];
}

export const ROPA_ACTIVITIES: RopaRow[] = [
  {
    activity: 'Account registration and OTP verification',
    purpose: 'Create the owner profile and verify the email + phone channels',
    lawfulBasis: 'Contract (s. 7(1)(b))',
    dataCategories: 'Email, phone, display name, password hash, OTP hash',
    recipients: 'SendGrid (email), Africa\'s Talking (SMS)',
    retention: 'Account lifetime (OTP hash: 30 minutes)',
    crossBorder: 'SendGrid US (SCC addendum), Africa\'s Talking KE (EAC adequacy)',
    sourceTables: ['accounts', 'account_verifications'],
  },
  {
    activity: 'Password and TOTP authentication',
    purpose: 'Grant authenticated access to the account',
    lawfulBasis: 'Contract (s. 7(1)(b))',
    dataCategories: 'Password hash (Argon2id + pepper), TOTP seed (KMS sealed)',
    recipients: 'None',
    retention: 'Account lifetime; wiped on erasure',
    crossBorder: 'None',
    sourceTables: ['accounts'],
  },
  {
    activity: 'Session issuance and refresh',
    purpose: 'Maintain authenticated device sessions',
    lawfulBasis: 'Contract (s. 7(1)(b))',
    dataCategories: 'Device id, user agent, SHA-256 refresh hash',
    recipients: 'None',
    retention: '30 days or until revoked',
    crossBorder: 'None',
    sourceTables: ['sessions'],
  },
  {
    activity: 'Passkey registration and authentication',
    purpose: 'Provide phishing-resistant sign-in',
    lawfulBasis: 'Consent (s. 7(1)(a)) + Contract',
    dataCategories: 'Credential id, public key, counter, transports',
    recipients: 'None',
    retention: 'Account lifetime',
    crossBorder: 'None',
    sourceTables: ['passkeys', 'webauthn_challenges'],
  },
  {
    activity: 'Zero-knowledge vault sync',
    purpose: 'Replicate encrypted portfolio events across the user\'s devices',
    lawfulBasis: 'Contract (s. 7(1)(b))',
    dataCategories: 'AES-GCM ciphertext, payload type tag, Merkle hash, device id',
    recipients: 'None',
    retention: 'Account lifetime; purged on erasure',
    crossBorder: 'Primary region GCP europe-west1 (PDPO approved)',
    sourceTables: ['events', 'vault_envelopes'],
  },
  {
    activity: 'Encrypted attachment storage',
    purpose: 'Keep user-uploaded documents available across devices',
    lawfulBasis: 'Contract (s. 7(1)(b))',
    dataCategories: 'AES-GCM ciphertext, SHA-256 digest, size, MIME type',
    recipients: 'Primary S3-compatible object storage; ClamAV when configured',
    retention: 'Account lifetime; purged on erasure or user removal',
    crossBorder: 'Same region as the primary database',
    sourceTables: ['attachment_blobs'],
  },
  {
    activity: 'Merkle-chained audit log and transparency anchoring',
    purpose: 'Tamper-evident record of sensitive actions',
    lawfulBasis: 'Legitimate interest (s. 7(1)(e))',
    dataCategories: 'Actor id, action label, resource label, context metadata',
    recipients: 'OpenTimestamps public calendars receive 32-byte digests only',
    retention: 'Account lifetime',
    crossBorder: 'Hashes only, no PII',
    sourceTables: ['audit_entries', 'transparency_anchors'],
  },
  {
    activity: 'Shamir vault-key recovery',
    purpose: 'Allow recovery of a lost device without plaintext at rest',
    lawfulBasis: 'Consent (s. 7(1)(a))',
    dataCategories: 'KMS-sealed server share, hash of printable share',
    recipients: 'None',
    retention: 'Until user disables recovery or account closes',
    crossBorder: 'None',
    sourceTables: ['vault_envelopes'],
  },
  {
    activity: 'Bank aggregation',
    purpose: 'Import user-authorised transactions into the ledger',
    lawfulBasis: 'Consent (s. 7(1)(a))',
    dataCategories: 'Provider token (KMS sealed), per-transaction metadata',
    recipients: 'Stanbic Bank, MTN MoMo (depending on user choice)',
    retention: 'Until the user revokes the connection',
    crossBorder: 'Provider region (typically UG or KE)',
    sourceTables: ['bank_connections', 'bank_transactions'],
  },
  {
    activity: 'Subscription and payment processing',
    purpose: 'Charge subscribers, maintain billing records',
    lawfulBasis: 'Contract (s. 7(1)(b)) + Legal obligation (s. 7(1)(c))',
    dataCategories: 'Processor reference ids, tier label, period end',
    recipients: 'Flutterwave (UG), Stripe (US) depending on user region',
    retention: '7 years (tax)',
    crossBorder: 'Flutterwave UG, Stripe US (DPF)',
    sourceTables: ['subscriptions', 'payment_events'],
  },
  {
    activity: 'Push notification delivery',
    purpose: 'Surface near-due reminders to the user\'s devices',
    lawfulBasis: 'Consent (s. 7(1)(a))',
    dataCategories: 'Device push token, opaque alert id',
    recipients: 'Google FCM, Apple APNs',
    retention: 'Rolling 90-day inactive window',
    crossBorder: 'FCM US / APNs US (DPF)',
    sourceTables: ['push_tokens'],
  },
  {
    activity: 'FX rate caching',
    purpose: 'Display UGX conversions on dated balances',
    lawfulBasis: 'Legitimate interest (s. 7(1)(e))',
    dataCategories: 'Public market data only',
    recipients: 'exchangerate.host, Bank of Uganda',
    retention: '12 months',
    crossBorder: 'Public market data',
    sourceTables: ['fx_rates_cache'],
  },
];
