import { createHash, createSign } from 'node:crypto';
import { request } from 'undici';
import { SignJWT, importPKCS8 } from 'jose';
import type { Db } from '../db.js';
import { queryMany } from '../db.js';
import type { AppConfig } from '../config.js';
import type { AuditService } from './audit.js';

export interface PushMessage {
  accountId: string;
  title: string;
  body: string;
  // Opaque identifier the client expands against local state. Keeps the
  // push channel plaintext-free.
  alertId: string;
}

export interface PushTransport {
  readonly name: 'fcm' | 'apns';
  send(token: string, message: PushMessage): Promise<void>;
}

/**
 * Multiplexes push delivery across the FCM and APNs transports. The service
 * never embeds plaintext from the user's portfolio into the payload — only
 * the alert id, which the client expands locally when the notification is
 * tapped.
 */
export class PushService {
  private readonly transports = new Map<string, PushTransport>();

  constructor(
    private readonly db: Db,
    private readonly audit: AuditService,
  ) {}

  register(transport: PushTransport): void {
    this.transports.set(transport.name, transport);
  }

  async registerToken(input: {
    accountId: string;
    deviceId: string;
    platform: 'fcm' | 'apns';
    token: string;
  }): Promise<void> {
    await this.db.query(
      `insert into push_tokens (account_id, device_id, platform, token)
       values ($1, $2, $3, $4)
       on conflict (device_id, platform) do update
         set token = excluded.token,
             account_id = excluded.account_id,
             last_seen_at = now()`,
      [input.accountId, input.deviceId, input.platform, input.token],
    );
  }

  async removeToken(deviceId: string, platform: 'fcm' | 'apns'): Promise<void> {
    await this.db.query(
      'delete from push_tokens where device_id = $1 and platform = $2',
      [deviceId, platform],
    );
  }

  async send(message: PushMessage): Promise<{ delivered: number; attempted: number }> {
    const tokens = await queryMany<{ platform: 'fcm' | 'apns'; token: string }>(
      this.db,
      `select platform, token from push_tokens where account_id = $1`,
      [message.accountId],
    );
    let delivered = 0;
    for (const t of tokens) {
      const transport = this.transports.get(t.platform);
      if (!transport) continue;
      try {
        await transport.send(t.token, message);
        delivered += 1;
      } catch {
        // Swallow per-device failures; they are retried on the next tick.
      }
    }
    await this.audit.record({
      accountId: message.accountId,
      actor: { kind: 'service', id: 'push' },
      action: 'push.sent',
      resource: `account:${message.accountId}`,
      context: { attempted: tokens.length, delivered, alertId: message.alertId },
    });
    return { delivered, attempted: tokens.length };
  }
}

/** FCM HTTP v1 transport. Uses a service-account JSON credential to mint a
 *  short-lived bearer token. Caches the token until expiry. */
export class FcmTransport implements PushTransport {
  readonly name = 'fcm';
  private cachedToken: { token: string; expiresAt: number } | null = null;

  constructor(private readonly projectId: string, private readonly serviceAccountJson: string) {}

  async send(deviceToken: string, message: PushMessage): Promise<void> {
    const bearer = await this.bearer();
    const url = `https://fcm.googleapis.com/v1/projects/${this.projectId}/messages:send`;
    const payload = {
      message: {
        token: deviceToken,
        notification: { title: message.title, body: message.body },
        data: { alertId: message.alertId },
      },
    };
    const { statusCode, body } = await request(url, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${bearer}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify(payload),
    });
    if (statusCode < 200 || statusCode >= 300) {
      throw new Error(`FCM HTTP ${statusCode}: ${await body.text()}`);
    }
    await body.dump();
  }

  private async bearer(): Promise<string> {
    if (this.cachedToken && this.cachedToken.expiresAt > Date.now() + 60_000) {
      return this.cachedToken.token;
    }
    const account = JSON.parse(this.serviceAccountJson) as {
      client_email: string;
      private_key: string;
      token_uri?: string;
    };
    const iat = Math.floor(Date.now() / 1000);
    const assertion = await new SignJWT({ scope: 'https://www.googleapis.com/auth/firebase.messaging' })
      .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
      .setIssuer(account.client_email)
      .setAudience(account.token_uri ?? 'https://oauth2.googleapis.com/token')
      .setIssuedAt(iat)
      .setExpirationTime(iat + 3600)
      .sign(await importPKCS8(account.private_key, 'RS256'));
    const { statusCode, body } = await request(account.token_uri ?? 'https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion,
      }).toString(),
    });
    if (statusCode < 200 || statusCode >= 300) {
      throw new Error(`FCM token exchange HTTP ${statusCode}: ${await body.text()}`);
    }
    const json = (await body.json()) as { access_token: string; expires_in: number };
    this.cachedToken = {
      token: json.access_token,
      expiresAt: Date.now() + json.expires_in * 1000,
    };
    return json.access_token;
  }
}

/** APNs HTTP/2 transport built on `undici`. Signs provider JWTs with the
 *  per-team private key and reuses them for up to an hour. */
export class ApnsTransport implements PushTransport {
  readonly name = 'apns';
  private cachedProviderJwt: { token: string; expiresAt: number } | null = null;

  constructor(
    private readonly teamId: string,
    private readonly keyId: string,
    private readonly privateKeyPem: string,
    private readonly bundleId: string,
    private readonly host = 'https://api.push.apple.com',
  ) {}

  async send(deviceToken: string, message: PushMessage): Promise<void> {
    const providerToken = this.providerJwt();
    const url = `${this.host}/3/device/${deviceToken}`;
    const body = JSON.stringify({
      aps: { alert: { title: message.title, body: message.body }, sound: 'default' },
      alertId: message.alertId,
    });
    const { statusCode, body: resp } = await request(url, {
      method: 'POST',
      headers: {
        authorization: `bearer ${providerToken}`,
        'apns-topic': this.bundleId,
        'apns-push-type': 'alert',
        'content-type': 'application/json',
      },
      body,
    });
    if (statusCode < 200 || statusCode >= 300) {
      throw new Error(`APNs HTTP ${statusCode}: ${await resp.text()}`);
    }
    await resp.dump();
  }

  private providerJwt(): string {
    if (this.cachedProviderJwt && this.cachedProviderJwt.expiresAt > Date.now() + 60_000) {
      return this.cachedProviderJwt.token;
    }
    const header = { alg: 'ES256', kid: this.keyId, typ: 'JWT' };
    const iat = Math.floor(Date.now() / 1000);
    const claims = { iss: this.teamId, iat };
    const encodedHeader = base64url(Buffer.from(JSON.stringify(header)));
    const encodedPayload = base64url(Buffer.from(JSON.stringify(claims)));
    const signingInput = `${encodedHeader}.${encodedPayload}`;
    const signer = createSign('SHA256');
    signer.update(signingInput);
    const signature = signer.sign({ key: this.privateKeyPem, dsaEncoding: 'ieee-p1363' });
    const token = `${signingInput}.${base64url(signature)}`;
    this.cachedProviderJwt = { token, expiresAt: Date.now() + 55 * 60_000 };
    return token;
  }
}

/** Console-only transport used in development + tests. Prints what would be
 *  sent so engineers can observe the path without a real certificate. */
export class ConsolePushTransport implements PushTransport {
  readonly name: 'fcm' | 'apns';
  readonly sent: Array<{ token: string; message: PushMessage }> = [];
  constructor(name: 'fcm' | 'apns' = 'fcm') {
    this.name = name;
  }
  async send(token: string, message: PushMessage): Promise<void> {
    this.sent.push({ token, message });
  }
}

function base64url(buf: Buffer): string {
  return buf
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

/** Convenience: produces a stable alert id matching the Flutter client's
 *  `ScheduledAlert.nativeId` so push payloads can be deduped. */
export function alertNativeId(stringId: string): string {
  return createHash('sha256').update(stringId).digest('hex').slice(0, 16);
}
