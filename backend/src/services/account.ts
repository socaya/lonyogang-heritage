import type { Db } from '../db.js';
import { queryOne, queryMany, withTx } from '../db.js';
import type { AuditService } from './audit.js';
import type { AttachmentService } from './attachments.js';

export interface AccountProfile {
  id: string;
  email: string;
  phone: string | null;
  displayName: string | null;
  status: 'pending' | 'active' | 'locked' | 'closed';
  verifiedAt: Date | null;
  marketingConsentAt: Date | null;
  closedAt: Date | null;
  createdAt: Date;
}

/**
 * Data-subject-rights surface (DPPA 2019 ss. 24–28). Everything the user
 * is entitled to from their own account lives here: inspect profile, edit
 * basic fields, download a portable export, exercise erasure.
 */
export class AccountService {
  constructor(
    private readonly db: Db,
    private readonly audit: AuditService,
    private readonly attachments: AttachmentService,
  ) {}

  async getProfile(accountId: string): Promise<AccountProfile | null> {
    const row = await queryOne<{
      id: string;
      email: string;
      phone: string | null;
      display_name: string | null;
      status: AccountProfile['status'];
      verified_at: Date | null;
      marketing_consent_at: Date | null;
      closed_at: Date | null;
      created_at: Date;
    }>(
      this.db,
      `select id, email, phone, display_name, status, verified_at,
              marketing_consent_at, closed_at, created_at
         from accounts where id = $1`,
      [accountId],
    );
    if (!row) return null;
    return {
      id: row.id,
      email: row.email,
      phone: row.phone,
      displayName: row.display_name,
      status: row.status,
      verifiedAt: row.verified_at,
      marketingConsentAt: row.marketing_consent_at,
      closedAt: row.closed_at,
      createdAt: row.created_at,
    };
  }

  /** Right to correction (s. 26). Only the fields in the input are updated;
   *  omitted fields keep their previous value. Setting `marketingConsent`
   *  to false clears the timestamp (consent withdrawn). */
  async updateProfile(
    accountId: string,
    input: {
      displayName?: string | null;
      phone?: string | null;
      marketingConsent?: boolean;
    },
  ): Promise<AccountProfile> {
    const sets: string[] = [];
    const params: unknown[] = [];
    if (input.displayName !== undefined) {
      params.push(input.displayName);
      sets.push(`display_name = $${params.length}`);
    }
    if (input.phone !== undefined) {
      params.push(input.phone);
      sets.push(`phone = $${params.length}`);
    }
    if (input.marketingConsent !== undefined) {
      if (input.marketingConsent) {
        sets.push(`marketing_consent_at = coalesce(marketing_consent_at, now())`);
      } else {
        sets.push(`marketing_consent_at = null`);
      }
    }
    if (sets.length === 0) {
      const profile = await this.getProfile(accountId);
      if (!profile) throw new Error('Account not found');
      return profile;
    }
    params.push(accountId);
    await this.db.query(`update accounts set ${sets.join(', ')} where id = $${params.length}`, params);
    await this.audit.record({
      accountId,
      actor: { kind: 'user', id: accountId },
      action: 'account.updated',
      resource: `account:${accountId}`,
      context: { fields: Object.keys(input) },
    });
    const profile = await this.getProfile(accountId);
    if (!profile) throw new Error('Account disappeared mid-update');
    return profile;
  }

  /** Right of access (s. 25). Returns a portable JSON bundle containing
   *  every row keyed on the account. Ciphertext fields are included as
   *  base64 strings; we never decrypt the user's data for them. */
  async exportProfile(accountId: string): Promise<Record<string, unknown>> {
    const profile = await this.getProfile(accountId);
    if (!profile) throw new Error('Account not found');
    const asBase64 = (rows: Record<string, unknown>[], keys: string[]) =>
      rows.map((r) => {
        const out: Record<string, unknown> = { ...r };
        for (const k of keys) {
          if (Buffer.isBuffer(r[k])) out[k] = (r[k] as Buffer).toString('base64');
        }
        return out;
      });
    const sessions = await queryMany(
      this.db,
      `select id, device_id, user_agent, created_at, refreshed_at, revoked_at, expires_at
         from sessions where account_id = $1 order by created_at asc`,
      [accountId],
    );
    const passkeys = asBase64(
      await queryMany(
        this.db,
        `select id, credential_id, public_key, counter, transports, friendly_name,
                created_at, last_used_at
           from passkeys where account_id = $1 order by created_at asc`,
        [accountId],
      ),
      ['credential_id', 'public_key'],
    );
    const events = asBase64(
      await queryMany(
        this.db,
        `select id, device_id, payload_type, payload, prev_hash, hash, integrity,
                received_at, created_at
           from events where account_id = $1 order by received_at asc`,
        [accountId],
      ),
      ['payload', 'prev_hash', 'hash'],
    );
    const attachments = asBase64(
      await queryMany(
        this.db,
        `select id, bucket_key, size_bytes, sha256, mime_type, uploaded_at, created_at
           from attachment_blobs where account_id = $1 order by created_at asc`,
        [accountId],
      ),
      ['sha256'],
    );
    const bankConnections = await queryMany(
      this.db,
      `select id, provider, external_id, display_label, scopes, status,
              linked_at, revoked_at, last_sync_at
         from bank_connections where account_id = $1 order by linked_at asc`,
      [accountId],
    );
    const subscription = await queryOne(
      this.db,
      `select tier, status, current_period_end, provider, updated_at
         from subscriptions where account_id = $1`,
      [accountId],
    );
    const auditTrail = asBase64(
      await queryMany(
        this.db,
        `select id, actor_kind, actor_id, action, resource, context, prev_hash, hash, created_at
           from audit_entries where account_id = $1 order by created_at asc`,
        [accountId],
      ),
      ['prev_hash', 'hash'],
    );
    return {
      exportedAt: new Date().toISOString(),
      profile,
      sessions,
      passkeys,
      events,
      attachments,
      bankConnections,
      subscription,
      audit: auditTrail,
    };
  }

  /** Right to erasure (s. 27). Tombstones the account, revokes every
   *  session, deletes every attachment and event. Payment events are kept
   *  under legal obligation (s. 7(1)(c)) but with the account id nulled
   *  so they can't be re-associated. */
  async eraseAccount(accountId: string): Promise<void> {
    const attachments = await queryMany<{ id: string }>(
      this.db,
      'select id from attachment_blobs where account_id = $1',
      [accountId],
    );
    for (const { id } of attachments) {
      try {
        await this.attachments.delete(accountId, id);
      } catch {
        // Best-effort: we still proceed with the tombstone.
      }
    }
    await withTx(this.db, async (client) => {
      // Lock the account row so a concurrent password reset, session
      // refresh or sync write can't race the erasure to completion.
      const locked = await client.query<{ id: string }>(
        'select id from accounts where id = $1 for update',
        [accountId],
      );
      if (locked.rowCount === 0) throw new Error('Account not found');
      await client.query(
        `update sessions set revoked_at = coalesce(revoked_at, now())
           where account_id = $1`,
        [accountId],
      );
      await client.query('delete from events where account_id = $1', [accountId]);
      await client.query('delete from passkeys where account_id = $1', [accountId]);
      await client.query('delete from push_tokens where account_id = $1', [accountId]);
      await client.query('delete from bank_connections where account_id = $1', [accountId]);
      await client.query(
        `update payment_events set account_id = null where account_id = $1`,
        [accountId],
      );
      await client.query(
        `update accounts set status = 'closed', closed_at = now(), password_hash = null,
                              totp_secret = null, phone = null, display_name = null,
                              marketing_consent_at = null,
                              failed_login_count = 0, locked_until = null
             where id = $1`,
        [accountId],
      );
    });
    await this.audit.record({
      accountId,
      actor: { kind: 'user', id: accountId },
      action: 'account.erased',
      resource: `account:${accountId}`,
    });
  }
}
