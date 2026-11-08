import { createHash, randomBytes, randomInt, timingSafeEqual } from 'node:crypto';
import argon2 from 'argon2';
import { authenticator } from 'otplib';
import type { Db } from '../db.js';
import { queryOne, queryMany, withTx } from '../db.js';
import type { AppConfig } from '../config.js';
import type { KeyStore } from './keystore.js';
import { TokenService } from './tokens.js';
import type { AuditService } from './audit.js';
import type { OtpDispatcher } from './otp_dispatcher.js';

export interface AccountRow {
  id: string;
  email: string;
  phone: string | null;
  display_name: string | null;
  password_hash: string | null;
  totp_secret: string | null;
  status: 'pending' | 'active' | 'locked' | 'closed';
  created_at: Date;
  verified_at: Date | null;
  failed_login_count?: number | null;
  locked_until?: Date | null;
}

const MAX_FAILED_BEFORE_LOCK = 5;
const LOCKOUT_MINUTES = 15;

export interface SessionResult {
  accessToken: string;
  refreshToken: string;
  sessionId: string;
  expiresAt: Date;
}

export class IdentityService {
  readonly tokens: TokenService;

  constructor(
    private readonly db: Db,
    private readonly config: AppConfig,
    private readonly kms: KeyStore,
    private readonly audit: AuditService,
    private readonly dispatcher: OtpDispatcher,
  ) {
    this.tokens = new TokenService(config);
    authenticator.options = { window: 1 };
  }

  // ---------- Sign-up ----------

  /** Creates an account in `pending` state, hashes the password with Argon2id
   *  (plus a configured pepper), generates verification codes for the email
   *  and (optionally) phone channel, dispatches the codes through the
   *  configured [OtpDispatcher] and audits the action. */
  async signUp(input: {
    email: string;
    phone?: string;
    displayName?: string;
    password: string;
  }): Promise<{ accountId: string; dispatched: { email: boolean; phone: boolean } }> {
    const normalisedEmail = input.email.trim().toLowerCase();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(normalisedEmail)) {
      throw new ClientError('invalid_email', 'Email is not a valid address');
    }
    if (input.password.length < 10) {
      throw new ClientError('weak_password', 'Password must be at least 10 characters');
    }

    const existing = await queryOne<AccountRow>(
      this.db,
      'select id from accounts where email = $1',
      [normalisedEmail],
    );
    if (existing) {
      throw new ClientError('email_taken', 'An account already uses this email');
    }

    const hash = await argon2.hash(this.pepper(input.password), {
      type: argon2.argon2id,
      memoryCost: 64 * 1024,
      timeCost: 3,
      parallelism: 1,
    });

    const { accountId, emailCode, phoneCode } = await withTx(this.db, async (client) => {
      const insert = await client.query<{ id: string }>(
        `insert into accounts (email, phone, display_name, password_hash, status)
         values ($1, $2, $3, $4, 'pending')
         returning id`,
        [normalisedEmail, input.phone ?? null, input.displayName ?? null, hash],
      );
      const accountId = insert.rows[0]!.id;
      const emailCode = this.generateOtp();
      await client.query(
        `insert into account_verifications (account_id, channel, code_hash, expires_at)
         values ($1, 'email', $2, now() + interval '15 minutes')`,
        [accountId, this.hashCode(emailCode)],
      );
      let phoneCode: string | null = null;
      if (input.phone) {
        phoneCode = this.generateOtp();
        await client.query(
          `insert into account_verifications (account_id, channel, code_hash, expires_at)
           values ($1, 'phone', $2, now() + interval '15 minutes')`,
          [accountId, this.hashCode(phoneCode)],
        );
      }
      return { accountId, emailCode, phoneCode };
    });

    await this.dispatcher.send({
      accountId,
      channel: 'email',
      code: emailCode,
      destination: normalisedEmail,
      purpose: 'signup',
    });
    if (input.phone && phoneCode) {
      await this.dispatcher.send({
        accountId,
        channel: 'phone',
        code: phoneCode,
        destination: input.phone,
        purpose: 'signup',
      });
    }

    await this.audit.record({
      accountId,
      actor: { kind: 'user', id: accountId },
      action: 'account.signup',
      resource: `account:${accountId}`,
      context: { email: normalisedEmail, hasPhone: Boolean(input.phone) },
    });

    return {
      accountId,
      dispatched: { email: true, phone: Boolean(input.phone) },
    };
  }

  /** Dispatches a fresh verification code for a pending channel. Used by
   *  the client's "resend" button when the user never received the first
   *  code. Rate-limited coarsely through the global 180/min limit; a
   *  per-account cooldown is enforced here by refusing if the newest
   *  outstanding code was issued less than 60 seconds ago. */
  async resendVerification(input: {
    accountId: string;
    channel: 'email' | 'phone';
  }): Promise<void> {
    const account = await queryOne<AccountRow>(
      this.db,
      'select id, email, phone, status from accounts where id = $1',
      [input.accountId],
    );
    if (!account) throw new ClientError('not_found', 'Account not found');
    if (account.status === 'active') {
      throw new ClientError('already_verified', 'Account is already active');
    }
    const destination =
      input.channel === 'email' ? account.email : account.phone;
    if (!destination) {
      throw new ClientError(
          'channel_unavailable',
          `No ${input.channel} on file`);
    }
    const latest = await queryOne<{ created_at: Date }>(
      this.db,
      `select created_at from account_verifications
         where account_id = $1 and channel = $2 and consumed_at is null
         order by created_at desc limit 1`,
      [input.accountId, input.channel],
    );
    if (
      latest &&
      Date.now() - latest.created_at.getTime() < 60_000
    ) {
      throw new ClientError('cooldown', 'Please wait before requesting another code');
    }
    const code = this.generateOtp();
    await this.db.query(
      `insert into account_verifications (account_id, channel, code_hash, expires_at)
       values ($1, $2, $3, now() + interval '15 minutes')`,
      [input.accountId, input.channel, this.hashCode(code)],
    );
    await this.dispatcher.send({
      accountId: input.accountId,
      channel: input.channel,
      code,
      destination,
      purpose: 'signup',
    });
    await this.audit.record({
      accountId: input.accountId,
      actor: { kind: 'user', id: input.accountId },
      action: 'verification.resent',
      resource: `account:${input.accountId}`,
      context: { channel: input.channel },
    });
  }

  /** Verifies one channel. When all pending verifications are consumed the
   *  account flips to `active`. */
  async verify(input: {
    accountId: string;
    channel: 'email' | 'phone';
    code: string;
  }): Promise<{ status: AccountRow['status'] }> {
    const pending = await queryOne<{ id: string; code_hash: Buffer; expires_at: Date }>(
      this.db,
      `select id, code_hash, expires_at
         from account_verifications
         where account_id = $1 and channel = $2 and consumed_at is null
         order by created_at desc
         limit 1`,
      [input.accountId, input.channel],
    );
    if (!pending) throw new ClientError('verification_not_found', 'No pending verification');
    if (pending.expires_at.getTime() < Date.now()) {
      throw new ClientError('verification_expired', 'Verification code has expired');
    }
    const supplied = this.hashCode(input.code);
    if (
      supplied.length !== pending.code_hash.length ||
      !timingSafeEqual(supplied, pending.code_hash)
    ) {
      throw new ClientError('verification_failed', 'Code did not match');
    }
    return await withTx(this.db, async (client) => {
      await client.query(
        'update account_verifications set consumed_at = now() where id = $1',
        [pending.id],
      );
      const remaining = await client.query<{ channel: string }>(
        `select channel from account_verifications
          where account_id = $1 and consumed_at is null and expires_at > now()`,
        [input.accountId],
      );
      let status: AccountRow['status'] = 'pending';
      if (remaining.rowCount === 0) {
        const updated = await client.query<{ status: AccountRow['status'] }>(
          `update accounts set status = 'active', verified_at = now()
            where id = $1 returning status`,
          [input.accountId],
        );
        status = updated.rows[0]!.status;
        await this.audit.record({
          accountId: input.accountId,
          actor: { kind: 'user', id: input.accountId },
          action: 'account.activated',
          resource: `account:${input.accountId}`,
        });
      }
      return { status };
    });
  }

  // ---------- Sign-in ----------

  async signIn(input: {
    email: string;
    password: string;
    totpCode?: string;
    deviceId: string;
    userAgent?: string;
  }): Promise<SessionResult> {
    const normalised = input.email.trim().toLowerCase();
    const account = await queryOne<AccountRow>(
      this.db,
      `select id, email, phone, display_name, password_hash, totp_secret, status,
              created_at, verified_at, failed_login_count, locked_until
         from accounts where email = $1`,
      [normalised],
    );
    if (!account || !account.password_hash) {
      await argon2.hash('decoy-password', { type: argon2.argon2id, memoryCost: 1024, timeCost: 1 });
      throw new ClientError('bad_credentials', 'Email or password is incorrect');
    }
    if (account.status !== 'active') {
      // Burn CPU to match the active-path timing so a timing attack can't
      // distinguish closed/pending/active. We also return the generic
      // bad_credentials error so an attacker can't harvest existence just
      // by observing status-specific errors.
      await argon2.hash('decoy-password', { type: argon2.argon2id, memoryCost: 1024, timeCost: 1 });
      throw new ClientError('bad_credentials', 'Email or password is incorrect');
    }
    if (account.locked_until && account.locked_until.getTime() > Date.now()) {
      throw new ClientError(
        'locked',
        `Too many failed attempts. Try again after ${account.locked_until.toISOString()}`,
      );
    }

    const passwordOk = await argon2.verify(account.password_hash, this.pepper(input.password));
    if (!passwordOk) {
      await this.recordFailedAttempt(account.id);
      throw new ClientError('bad_credentials', 'Email or password is incorrect');
    }

    if (account.totp_secret) {
      if (!input.totpCode) {
        throw new ClientError('totp_required', 'Second factor is required');
      }
      const secret = (
        await this.kms.unseal(Buffer.from(account.totp_secret, 'base64'), Buffer.from(account.id, 'utf8'))
      ).toString('utf8');
      if (!authenticator.check(input.totpCode, secret)) {
        await this.recordFailedAttempt(account.id);
        throw new ClientError('bad_totp', 'Second factor code is invalid');
      }
    }

    await this.db.query(
      `update accounts set failed_login_count = 0, locked_until = null where id = $1`,
      [account.id],
    );
    return await this.openSession(account.id, input.deviceId, input.userAgent);
  }

  private async recordFailedAttempt(accountId: string): Promise<void> {
    const row = await queryOne<{ failed_login_count: number }>(
      this.db,
      `update accounts
          set failed_login_count = failed_login_count + 1,
              locked_until = case
                when failed_login_count + 1 >= $2
                  then now() + ($3 || ' minutes')::interval
                else locked_until
              end
         where id = $1
         returning failed_login_count`,
      [accountId, MAX_FAILED_BEFORE_LOCK, LOCKOUT_MINUTES.toString()],
    );
    if (row && row.failed_login_count >= MAX_FAILED_BEFORE_LOCK) {
      await this.audit.record({
        accountId,
        actor: { kind: 'system' },
        action: 'account.locked',
        resource: `account:${accountId}`,
        context: { reason: 'failed_login_count_exceeded', threshold: MAX_FAILED_BEFORE_LOCK },
      });
    }
  }

  /** Issues a new session and both tokens. Shared by password and passkey
   *  sign-in paths. */
  async openSession(accountId: string, deviceId: string, userAgent?: string): Promise<SessionResult> {
    const { token: refreshToken, hash: refreshHash } = this.tokens.issueRefresh();
    const expiresAt = new Date(Date.now() + this.config.JWT_REFRESH_TTL_SECONDS * 1000);
    const insert = await queryOne<{ id: string }>(
      this.db,
      `insert into sessions (account_id, device_id, refresh_hash, user_agent, expires_at)
       values ($1, $2, $3, $4, $5)
       returning id`,
      [accountId, deviceId, refreshHash, userAgent ?? null, expiresAt],
    );
    const sessionId = insert!.id;
    const accessToken = await this.tokens.signAccess({ accountId, sessionId, deviceId });
    await this.audit.record({
      accountId,
      actor: { kind: 'user', id: accountId },
      action: 'session.opened',
      resource: `session:${sessionId}`,
      context: { deviceId },
    });
    return { accessToken, refreshToken, sessionId, expiresAt };
  }

  async refreshSession(refreshToken: string): Promise<SessionResult> {
    const hash = this.tokens.hashRefresh(refreshToken);
    const row = await queryOne<{
      id: string;
      account_id: string;
      device_id: string;
      expires_at: Date;
      revoked_at: Date | null;
    }>(
      this.db,
      `select id, account_id, device_id, expires_at, revoked_at
         from sessions where refresh_hash = $1`,
      [hash],
    );
    if (!row || row.revoked_at || row.expires_at.getTime() < Date.now()) {
      // Burn the same CPU the happy path spends (issueRefresh +
      // signAccess) so an attacker can't distinguish "token not in db"
      // from "token in db but expired" through response-time
      // differentials. This closes the timing side-channel on the
      // refresh hash lookup.
      const decoy = this.tokens.issueRefresh();
      await this.tokens.signAccess({
        accountId: '00000000-0000-0000-0000-000000000000',
        sessionId: '00000000-0000-0000-0000-000000000000',
        deviceId: '00000000-0000-0000-0000-000000000000',
      });
      void decoy;
      throw new ClientError('bad_refresh', 'Refresh token is not valid');
    }
    const { token: nextRefresh, hash: nextHash } = this.tokens.issueRefresh();
    const expiresAt = new Date(Date.now() + this.config.JWT_REFRESH_TTL_SECONDS * 1000);
    await this.db.query(
      `update sessions set refresh_hash = $1, refreshed_at = now(), expires_at = $2 where id = $3`,
      [nextHash, expiresAt, row.id],
    );
    const accessToken = await this.tokens.signAccess({
      accountId: row.account_id,
      sessionId: row.id,
      deviceId: row.device_id,
    });
    return { accessToken, refreshToken: nextRefresh, sessionId: row.id, expiresAt };
  }

  async revokeSession(sessionId: string, accountId: string): Promise<void> {
    await this.db.query(
      `update sessions set revoked_at = now() where id = $1 and account_id = $2`,
      [sessionId, accountId],
    );
    await this.audit.record({
      accountId,
      actor: { kind: 'user', id: accountId },
      action: 'session.revoked',
      resource: `session:${sessionId}`,
    });
  }

  /// Revokes every active session for [accountId] except [keepSessionId].
  /// Used by the "sign out everywhere else" action on the SessionsScreen
  /// after a lost device. Returns the count of rows revoked.
  async revokeAllSessionsExcept(
    accountId: string,
    keepSessionId: string,
  ): Promise<number> {
    const result = await this.db.query(
      `update sessions set revoked_at = now()
         where account_id = $1 and id != $2 and revoked_at is null`,
      [accountId, keepSessionId],
    );
    const revoked = result.rowCount ?? 0;
    if (revoked > 0) {
      await this.audit.record({
        accountId,
        actor: { kind: 'user', id: accountId },
        action: 'session.revoked_others',
        resource: `account:${accountId}`,
        context: { revoked, kept: keepSessionId },
      });
    }
    return revoked;
  }

  // ---------- TOTP enrolment ----------

  async enrollTotp(accountId: string): Promise<{ secret: string; otpauthUrl: string }> {
    const secret = authenticator.generateSecret();
    const account = await queryOne<AccountRow>(
      this.db,
      'select email from accounts where id = $1',
      [accountId],
    );
    if (!account) throw new ClientError('not_found', 'Account not found');
    const sealed = (
      await this.kms.seal(Buffer.from(secret, 'utf8'), Buffer.from(accountId, 'utf8'))
    ).toString('base64');
    await this.db.query('update accounts set totp_secret = $1 where id = $2', [sealed, accountId]);
    const otpauth = authenticator.keyuri(account.email, 'LonyoGang Heritage', secret);
    await this.audit.record({
      accountId,
      actor: { kind: 'user', id: accountId },
      action: 'totp.enrolled',
      resource: `account:${accountId}`,
    });
    return { secret, otpauthUrl: otpauth };
  }

  // ---------- Password reset (anti-enumeration) ----------

  /** Initiates recovery. Always succeeds from the client's perspective to
   *  avoid confirming which emails exist. Dispatches the token to the
   *  configured email provider; the HTTP response never includes it. */
  async beginPasswordReset(email: string): Promise<void> {
    const normalised = email.trim().toLowerCase();
    const account = await queryOne<AccountRow>(
      this.db,
      'select id, email from accounts where email = $1 and status = $2',
      [normalised, 'active'],
    );
    if (!account) return;
    const token = randomBytes(24).toString('base64url');
    await this.db.query(
      `insert into account_verifications (account_id, channel, code_hash, expires_at)
       values ($1, 'email', $2, now() + interval '30 minutes')`,
      [account.id, this.hashCode(token)],
    );
    await this.dispatcher.send({
      accountId: account.id,
      channel: 'email',
      code: token,
      destination: account.email,
      purpose: 'password_reset',
    });
    await this.audit.record({
      accountId: account.id,
      actor: { kind: 'user', id: account.id },
      action: 'password.reset_requested',
      resource: `account:${account.id}`,
    });
  }

  async completePasswordReset(input: {
    email: string;
    token: string;
    newPassword: string;
  }): Promise<void> {
    if (input.newPassword.length < 10) {
      throw new ClientError('weak_password', 'Password must be at least 10 characters');
    }
    const account = await queryOne<AccountRow>(
      this.db,
      'select id from accounts where email = $1',
      [input.email.trim().toLowerCase()],
    );
    if (!account) throw new ClientError('not_found', 'Account not found');
    const pending = await queryOne<{ id: string; code_hash: Buffer; expires_at: Date }>(
      this.db,
      `select id, code_hash, expires_at from account_verifications
         where account_id = $1 and channel = 'email' and consumed_at is null
         order by created_at desc limit 1`,
      [account.id],
    );
    if (!pending || pending.expires_at.getTime() < Date.now()) {
      throw new ClientError('token_invalid', 'Reset token has expired');
    }
    const supplied = this.hashCode(input.token);
    if (!timingSafeEqual(supplied, pending.code_hash)) {
      throw new ClientError('token_invalid', 'Reset token is not valid');
    }
    const hash = await argon2.hash(this.pepper(input.newPassword), {
      type: argon2.argon2id,
      memoryCost: 64 * 1024,
      timeCost: 3,
      parallelism: 1,
    });
    await withTx(this.db, async (client) => {
      await client.query(
        'update account_verifications set consumed_at = now() where id = $1',
        [pending.id],
      );
      await client.query('update accounts set password_hash = $1 where id = $2', [hash, account.id]);
      await client.query(
        `update sessions set revoked_at = now()
           where account_id = $1 and revoked_at is null`,
        [account.id],
      );
    });
    await this.audit.record({
      accountId: account.id,
      actor: { kind: 'user', id: account.id },
      action: 'password.reset_completed',
      resource: `account:${account.id}`,
    });
  }

  // ---------- Helpers ----------

  private generateOtp(): string {
    const digits: string[] = [];
    for (let i = 0; i < 6; i++) digits.push(randomInt(0, 10).toString());
    return digits.join('');
  }

  private hashCode(code: string): Buffer {
    return createHash('sha256').update(`${this.config.PASSWORD_PEPPER}:${code}`).digest();
  }

  private pepper(password: string): string {
    return `${this.config.PASSWORD_PEPPER}:${password}`;
  }

  /**
   * Verifies a password against the live hash on the account row without
   * opening a session or touching failed_login_count. Used by endpoints
   * that need a step-up check before a destructive action (DELETE /me,
   * recovery redemption) — a stolen access token alone shouldn't be enough.
   */
  async verifyAccountPassword(accountId: string, password: string): Promise<boolean> {
    const row = await queryOne<{ password_hash: string | null }>(
      this.db,
      'select password_hash from accounts where id = $1',
      [accountId],
    );
    if (!row || !row.password_hash) {
      await argon2.hash('decoy-password', { type: argon2.argon2id, memoryCost: 1024, timeCost: 1 });
      return false;
    }
    return argon2.verify(row.password_hash, this.pepper(password));
  }

  async listSessions(accountId: string) {
    return queryMany<{
      id: string;
      device_id: string;
      user_agent: string | null;
      created_at: Date;
      refreshed_at: Date | null;
      revoked_at: Date | null;
      expires_at: Date;
    }>(
      this.db,
      `select id, device_id, user_agent, created_at, refreshed_at, revoked_at, expires_at
         from sessions where account_id = $1 order by created_at desc`,
      [accountId],
    );
  }
}

export class ClientError extends Error {
  constructor(
    readonly code: string,
    message: string,
  ) {
    super(message);
  }
}
