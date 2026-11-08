import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { startHarness, type Harness } from './support/harness.js';
import { ulid } from 'ulid';

let harness: Harness;

beforeAll(async () => {
  harness = await startHarness();
}, 120_000);

afterAll(async () => {
  await harness.teardown();
});

async function session(email: string) {
  const signup = await harness.app.inject({
    method: 'POST',
    url: '/identity/accounts',
    payload: {
      email,
      password: 'correct-horse-battery-staple',
      phone: '+256700123456',
    },
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
  await harness.app.inject({
    method: 'POST',
    url: '/identity/accounts/verify',
    payload: {
      accountId,
      channel: 'phone',
      code: harness.otp.latestCode(accountId, 'phone'),
    },
  });
  const signIn = await harness.app.inject({
    method: 'POST',
    url: '/identity/sessions',
    payload: {
      email,
      password: 'correct-horse-battery-staple',
      deviceId: '00000000-0000-0000-0000-000000000010',
    },
  });
  const tokens = signIn.json<{ accessToken: string; refreshToken: string }>();
  return { accountId, ...tokens };
}

describe('sync service', () => {
  it('ingests events idempotently and pulls them back for the same account', async () => {
    const s = await session('sync@example.com');
    const auth = { authorization: `Bearer ${s.accessToken}` };
    const eventId = ulid();
    const body = {
      events: [
        {
          id: eventId,
          deviceId: '00000000-0000-0000-0000-000000000010',
          payloadType: 'asset',
          payload: Buffer.from('ciphertext-1').toString('base64'),
          prevHash: null,
          integrity: { ownership_bps: 10_000 },
        },
      ],
    };
    const first = await harness.app.inject({
      method: 'POST',
      url: '/sync/events',
      payload: body,
      headers: auth,
    });
    expect(first.statusCode).toBe(200);
    expect(first.json<{ inserted: number }>().inserted).toBe(1);
    const second = await harness.app.inject({
      method: 'POST',
      url: '/sync/events',
      payload: body,
      headers: auth,
    });
    expect(second.json<{ inserted: number }>().inserted).toBe(0);
    const pull = await harness.app.inject({
      method: 'GET',
      url: '/sync/events',
      headers: auth,
    });
    const { events } = pull.json<{ events: { id: string; payload: string }[] }>();
    expect(events).toHaveLength(1);
    expect(events[0]!.id).toBe(eventId);
    expect(Buffer.from(events[0]!.payload, 'base64').toString('utf8')).toBe('ciphertext-1');
  });

  it('rejects beneficiary batches whose combined_bps exceeds 100%', async () => {
    const s = await session('bene@example.com');
    const bad = await harness.app.inject({
      method: 'POST',
      url: '/sync/events',
      payload: {
        events: [
          {
            id: ulid(),
            deviceId: '00000000-0000-0000-0000-000000000010',
            payloadType: 'beneficiary_batch',
            payload: Buffer.from('cipher').toString('base64'),
            prevHash: null,
            integrity: { combined_bps: 11_000 },
          },
        ],
      },
      headers: { authorization: `Bearer ${s.accessToken}` },
    });
    expect(bad.statusCode).toBe(422);
  });

  it('isolates events across accounts', async () => {
    const s1 = await session('iso-1@example.com');
    const s2 = await session('iso-2@example.com');
    await harness.app.inject({
      method: 'POST',
      url: '/sync/events',
      payload: {
        events: [
          {
            id: ulid(),
            deviceId: '00000000-0000-0000-0000-000000000011',
            payloadType: 'ledger_event',
            payload: Buffer.from('a').toString('base64'),
            integrity: { amount_ugx: 1000 },
          },
        ],
      },
      headers: { authorization: `Bearer ${s1.accessToken}` },
    });
    const otherAccountPull = await harness.app.inject({
      method: 'GET',
      url: '/sync/events',
      headers: { authorization: `Bearer ${s2.accessToken}` },
    });
    expect(otherAccountPull.json<{ events: unknown[] }>().events).toHaveLength(0);
  });

  it('upserts and reads back the vault envelope', async () => {
    const s = await session('env@example.com');
    const put = await harness.app.inject({
      method: 'PUT',
      url: '/sync/envelope',
      payload: {
        wrappedContentKey: Buffer.from('wrapped-key-material').toString('base64'),
        version: 2,
      },
      headers: { authorization: `Bearer ${s.accessToken}` },
    });
    expect(put.statusCode).toBe(204);
    const get = await harness.app.inject({
      method: 'GET',
      url: '/sync/envelope',
      headers: { authorization: `Bearer ${s.accessToken}` },
    });
    expect(get.statusCode).toBe(200);
    const payload = get.json<{ wrappedContentKey: string; version: number }>();
    expect(payload.version).toBe(2);
    expect(Buffer.from(payload.wrappedContentKey, 'base64').toString('utf8')).toBe('wrapped-key-material');
  });
});
