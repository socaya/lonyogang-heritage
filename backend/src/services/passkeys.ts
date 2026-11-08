import { randomBytes } from 'node:crypto';
import {
  generateRegistrationOptions,
  verifyRegistrationResponse,
  generateAuthenticationOptions,
  verifyAuthenticationResponse,
} from '@simplewebauthn/server';
import type { AppConfig } from '../config.js';

// @simplewebauthn/server v10 ships its typed response shapes inline; the
// public surface we need is the string-tagged JSON object the client sends.
type AuthenticationResponseJSON = Parameters<typeof verifyAuthenticationResponse>[0]['response'];
type RegistrationResponseJSON = Parameters<typeof verifyRegistrationResponse>[0]['response'];
type AuthenticatorTransportFuture = NonNullable<
  NonNullable<Parameters<typeof generateAuthenticationOptions>[0]['allowCredentials']>[number]['transports']
>[number];
import type { Db } from '../db.js';
import { queryMany, queryOne, withTx } from '../db.js';
import type { AuditService } from './audit.js';

interface ChallengeRow {
  id: string;
  account_id: string | null;
  challenge: Buffer;
  expires_at: Date;
}

interface PasskeyRow {
  id: string;
  account_id: string;
  credential_id: Buffer;
  public_key: Buffer;
  counter: string | number;
  transports: string[];
  friendly_name: string | null;
}

export class PasskeyService {
  constructor(
    private readonly db: Db,
    private readonly config: AppConfig,
    private readonly audit: AuditService,
  ) {}

  async registrationOptions(accountId: string, friendlyName?: string) {
    const existing = await queryMany<{ credential_id: Buffer; transports: string[] }>(
      this.db,
      'select credential_id, transports from passkeys where account_id = $1',
      [accountId],
    );
    const options = await generateRegistrationOptions({
      rpID: this.config.RP_ID,
      rpName: this.config.RP_NAME,
      userID: new TextEncoder().encode(accountId),
      userName: friendlyName ?? accountId,
      attestationType: 'none',
      authenticatorSelection: {
        residentKey: 'preferred',
        userVerification: 'preferred',
      },
      excludeCredentials: existing.map((e) => ({
        id: e.credential_id.toString('base64url'),
        transports: (e.transports as unknown) as AuthenticatorTransportFuture[] | undefined,
      })),
    });
    await this.persistChallenge(accountId, Buffer.from(options.challenge, 'base64url'), 'registration');
    return options;
  }

  async finishRegistration(input: {
    accountId: string;
    response: RegistrationResponseJSON;
    friendlyName?: string;
  }): Promise<{ credentialId: string }> {
    const challenge = await this.consumeChallenge(input.accountId, 'registration');
    const verification = await verifyRegistrationResponse({
      response: input.response,
      expectedChallenge: challenge.toString('base64url'),
      expectedOrigin: this.config.RP_ORIGIN,
      expectedRPID: this.config.RP_ID,
      requireUserVerification: false,
    });
    if (!verification.verified || !verification.registrationInfo) {
      throw new Error('Passkey registration did not verify');
    }
    const info = verification.registrationInfo as unknown as {
      credentialID: string;
      credentialPublicKey: Uint8Array;
      counter: number;
      aaguid?: string;
      credentialDeviceType?: string;
      credentialBackedUp?: boolean;
    };
    const credentialIdBuf = Buffer.from(info.credentialID, 'base64url');
    const publicKeyBuf = Buffer.from(info.credentialPublicKey);
    await this.db.query(
      `insert into passkeys (account_id, credential_id, public_key, counter, transports, aaguid, friendly_name)
       values ($1, $2, $3, $4, $5, $6, $7)`,
      [
        input.accountId,
        credentialIdBuf,
        publicKeyBuf,
        info.counter,
        input.response.response.transports ?? [],
        info.aaguid ?? null,
        input.friendlyName ?? null,
      ],
    );
    await this.audit.record({
      accountId: input.accountId,
      actor: { kind: 'user', id: input.accountId },
      action: 'passkey.registered',
      resource: `passkey:${credentialIdBuf.toString('base64url')}`,
    });
    return { credentialId: credentialIdBuf.toString('base64url') };
  }

  async authenticationOptions(accountEmail?: string) {
    let allowCredentials:
      | { id: string; transports?: AuthenticatorTransportFuture[] }[]
      | undefined;
    let accountId: string | null = null;
    if (accountEmail) {
      const account = await queryOne<{ id: string }>(
        this.db,
        'select id from accounts where email = $1',
        [accountEmail.trim().toLowerCase()],
      );
      if (account) {
        accountId = account.id;
        const creds = await queryMany<{ credential_id: Buffer; transports: string[] }>(
          this.db,
          'select credential_id, transports from passkeys where account_id = $1',
          [account.id],
        );
        allowCredentials = creds.map((c) => ({
          id: c.credential_id.toString('base64url'),
          transports: (c.transports as unknown) as AuthenticatorTransportFuture[],
        }));
      }
    }
    const options = await generateAuthenticationOptions({
      rpID: this.config.RP_ID,
      allowCredentials,
      userVerification: 'preferred',
    });
    await this.persistChallenge(accountId, Buffer.from(options.challenge, 'base64url'), 'authentication');
    return options;
  }

  /** Finalises an authentication response. Returns the matching account id
   *  so the identity service can open a session. */
  async verifyAuthentication(input: {
    response: AuthenticationResponseJSON;
  }): Promise<{ accountId: string; credentialId: string }> {
    const credentialId = Buffer.from(input.response.id, 'base64url');
    const passkey = await queryOne<PasskeyRow>(
      this.db,
      `select id, account_id, credential_id, public_key, counter, transports, friendly_name
         from passkeys where credential_id = $1`,
      [credentialId],
    );
    if (!passkey) throw new Error('No matching passkey registered');
    const challenge = await this.consumeChallengeForAccount(passkey.account_id, 'authentication');
    const verification = await verifyAuthenticationResponse({
      response: input.response,
      expectedChallenge: challenge.toString('base64url'),
      expectedOrigin: this.config.RP_ORIGIN,
      expectedRPID: this.config.RP_ID,
      authenticator: {
        credentialID: passkey.credential_id.toString('base64url'),
        credentialPublicKey: new Uint8Array(passkey.public_key),
        counter: Number(passkey.counter),
        transports: (passkey.transports as unknown) as AuthenticatorTransportFuture[] | undefined,
      },
      requireUserVerification: false,
    } as unknown as Parameters<typeof verifyAuthenticationResponse>[0]);
    if (!verification.verified) throw new Error('Passkey assertion did not verify');
    await this.db.query(
      `update passkeys set counter = $1, last_used_at = now() where id = $2`,
      [verification.authenticationInfo.newCounter, passkey.id],
    );
    await this.audit.record({
      accountId: passkey.account_id,
      actor: { kind: 'user', id: passkey.account_id },
      action: 'passkey.authenticated',
      resource: `passkey:${credentialId.toString('base64url')}`,
    });
    return { accountId: passkey.account_id, credentialId: credentialId.toString('base64url') };
  }

  async remove(accountId: string, credentialIdB64url: string): Promise<void> {
    const credentialId = Buffer.from(credentialIdB64url, 'base64url');
    const result = await this.db.query(
      'delete from passkeys where account_id = $1 and credential_id = $2',
      [accountId, credentialId],
    );
    if (result.rowCount === 0) throw new Error('Passkey not found');
    await this.audit.record({
      accountId,
      actor: { kind: 'user', id: accountId },
      action: 'passkey.removed',
      resource: `passkey:${credentialIdB64url}`,
    });
  }

  async listForAccount(accountId: string) {
    return queryMany<PasskeyRow & { created_at: Date; last_used_at: Date | null }>(
      this.db,
      `select id, credential_id, public_key, counter, transports, friendly_name, account_id,
              created_at, last_used_at
         from passkeys where account_id = $1 order by created_at desc`,
      [accountId],
    );
  }

  private async persistChallenge(
    accountId: string | null,
    challenge: Buffer,
    kind: 'registration' | 'authentication',
  ): Promise<void> {
    await this.db.query(
      `insert into webauthn_challenges (account_id, challenge, kind, expires_at)
       values ($1, $2, $3, now() + interval '5 minutes')`,
      [accountId, challenge, kind],
    );
  }

  private async consumeChallenge(
    accountId: string,
    kind: 'registration' | 'authentication',
  ): Promise<Buffer> {
    return withTx(this.db, async (client) => {
      const existing = await client.query<ChallengeRow>(
        `select id, account_id, challenge, expires_at from webauthn_challenges
          where account_id = $1 and kind = $2 and expires_at > now()
          order by created_at desc limit 1 for update skip locked`,
        [accountId, kind],
      );
      if (existing.rowCount === 0) throw new Error('No active WebAuthn challenge');
      const row = existing.rows[0]!;
      await client.query('delete from webauthn_challenges where id = $1', [row.id]);
      return row.challenge;
    });
  }

  private async consumeChallengeForAccount(
    accountId: string,
    kind: 'registration' | 'authentication',
  ): Promise<Buffer> {
    return withTx(this.db, async (client) => {
      const existing = await client.query<ChallengeRow>(
        `select id, challenge from webauthn_challenges
          where (account_id = $1 or account_id is null) and kind = $2 and expires_at > now()
          order by created_at desc limit 1 for update skip locked`,
        [accountId, kind],
      );
      if (existing.rowCount === 0) throw new Error('No active WebAuthn challenge');
      const row = existing.rows[0]!;
      await client.query('delete from webauthn_challenges where id = $1', [row.id]);
      return row.challenge;
    });
  }

  randomChallenge(): Buffer {
    return randomBytes(32);
  }
}
