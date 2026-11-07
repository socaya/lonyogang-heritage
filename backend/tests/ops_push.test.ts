import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { startHarness, type Harness } from './support/harness.js';
import { ConsolePushTransport } from '../src/services/push.js';
import { ROPA_ACTIVITIES } from '../src/services/ropa.js';

let harness: Harness;
let transport: ConsolePushTransport;

beforeAll(async () => {
  harness = await startHarness();
  transport = new ConsolePushTransport('fcm');
  // Swap in the recording transport so we can assert on what would be sent.
  (harness.services.push as unknown as { transports: Map<string, unknown> }).transports.set(
    'fcm',
    transport,
  );
  // Provision an ops secret on the running server.
  (harness.app as unknown as { opsSecret: string }).opsSecret = 'ops-shared-secret';
}, 120_000);

afterAll(async () => {
  await harness.teardown();
});

async function authed(email: string) {
  const signup = await harness.app.inject({
    method: 'POST',
    url: '/identity/accounts',
    payload: { email, password: 'correct-horse-battery-staple', phone: '+256700123456' },
  });
  const { accountId } = signup.json<{ accountId: string }>();
  await harness.app.inject({
    method: 'POST',
    url: '/identity/accounts/verify',
    payload: {
      accountId,
      channel: 'email',
      code: harness.otp.latestCode(accountId, 'email'),
    },
  });
  const signIn = await harness.app.inject({
    method: 'POST',
    url: '/identity/sessions',
    payload: {
      email,
      password: 'correct-horse-battery-staple',
      deviceId: '00000000-0000-0000-0000-000000000050',
    },
  });
  return { accountId, accessToken: signIn.json<{ accessToken: string }>().accessToken };
}

describe('POST /ops/push/send', () => {
  it('requires the shared ops secret', async () => {
    const res = await harness.app.inject({
      method: 'POST',
      url: '/ops/push/send',
      payload: {
        accountId: '00000000-0000-0000-0000-000000000000',
        title: 't',
        body: 'b',
        alertId: 'a',
      },
    });
    expect(res.statusCode).toBe(401);
  });

  it('sends a push payload through the configured transport', async () => {
    const { accountId, accessToken } = await authed('push@example.com');
    await harness.app.inject({
      method: 'POST',
      url: '/push/tokens',
      payload: {
        deviceId: '00000000-0000-0000-0000-000000000050',
        platform: 'fcm',
        token: 'test-device-token',
      },
      headers: { authorization: `Bearer ${accessToken}` },
    });
    transport.sent.length = 0;
    const res = await harness.app.inject({
      method: 'POST',
      url: '/ops/push/send',
      payload: { accountId, title: 'New reminder', body: 'Review documents', alertId: 'alert-1' },
      headers: { 'x-ops-token': 'ops-shared-secret' },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json<{ delivered: number; attempted: number }>();
    expect(body.attempted).toBe(1);
    expect(body.delivered).toBe(1);
    expect(transport.sent).toHaveLength(1);
    expect(transport.sent[0]?.message.alertId).toBe('alert-1');
  });
});

describe('RoPA registry', () => {
  it('declares a lawful basis for every activity', () => {
    for (const activity of ROPA_ACTIVITIES) {
      expect(activity.lawfulBasis).toMatch(/s\. 7|Contract|Consent|Legitimate|Legal/);
    }
  });

  it('covers every primary schema table at least once', () => {
    const covered = new Set(ROPA_ACTIVITIES.flatMap((a) => a.sourceTables));
    for (const table of [
      'accounts',
      'sessions',
      'passkeys',
      'events',
      'attachment_blobs',
      'audit_entries',
      'vault_envelopes',
      'bank_connections',
      'subscriptions',
      'push_tokens',
      'fx_rates_cache',
    ]) {
      expect(covered.has(table), `missing table ${table}`).toBe(true);
    }
  });
});
