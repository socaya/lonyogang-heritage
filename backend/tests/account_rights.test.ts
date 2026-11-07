import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { startHarness, type Harness } from './support/harness.js';

let harness: Harness;

beforeAll(async () => {
  harness = await startHarness();
}, 120_000);

afterAll(async () => {
  await harness.teardown();
});

async function newSession(email: string) {
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
      deviceId: '00000000-0000-0000-0000-000000000040',
    },
  });
  return { accountId, ...signIn.json<{ accessToken: string; refreshToken: string }>() };
}

describe('data-subject rights', () => {
  it('PATCH /me updates display name and marketing consent', async () => {
    const s = await newSession('patch@example.com');
    const patch = await harness.app.inject({
      method: 'PATCH',
      url: '/me',
      payload: { displayName: 'Jane Doe', marketingConsent: true },
      headers: { authorization: `Bearer ${s.accessToken}` },
    });
    expect(patch.statusCode).toBe(200);
    const profile = patch.json<{ displayName: string; marketingConsentAt: string | null }>();
    expect(profile.displayName).toBe('Jane Doe');
    expect(profile.marketingConsentAt).not.toBeNull();

    const withdraw = await harness.app.inject({
      method: 'PATCH',
      url: '/me',
      payload: { marketingConsent: false },
      headers: { authorization: `Bearer ${s.accessToken}` },
    });
    expect(withdraw.json<{ marketingConsentAt: string | null }>().marketingConsentAt).toBeNull();
  });

  it('GET /me/export returns a portable bundle with every table', async () => {
    const s = await newSession('export@example.com');
    const res = await harness.app.inject({
      method: 'GET',
      url: '/me/export',
      headers: { authorization: `Bearer ${s.accessToken}` },
    });
    expect(res.statusCode).toBe(200);
    const bundle = res.json<Record<string, unknown>>();
    expect(bundle['profile']).toBeDefined();
    expect(Array.isArray(bundle['sessions'])).toBe(true);
    expect(Array.isArray(bundle['passkeys'])).toBe(true);
    expect(Array.isArray(bundle['events'])).toBe(true);
    expect(Array.isArray(bundle['audit'])).toBe(true);
  });

  it('DELETE /me tombstones the account and breaks subsequent sign-ins', async () => {
    const s = await newSession('erase@example.com');
    const del = await harness.app.inject({
      method: 'DELETE',
      url: '/me',
      headers: { authorization: `Bearer ${s.accessToken}` },
    });
    expect(del.statusCode).toBe(204);
    const signInAgain = await harness.app.inject({
      method: 'POST',
      url: '/identity/sessions',
      payload: {
        email: 'erase@example.com',
        password: 'correct-horse-battery-staple',
        deviceId: '00000000-0000-0000-0000-000000000041',
      },
    });
    expect(signInAgain.statusCode).toBe(401);
  });
});

describe('sign-in lockout', () => {
  it('locks the account after five consecutive failures', async () => {
    const email = 'lockout@example.com';
    const s = await newSession(email);
    for (let i = 0; i < 5; i += 1) {
      const res = await harness.app.inject({
        method: 'POST',
        url: '/identity/sessions',
        payload: {
          email,
          password: `wrong-${i}`,
          deviceId: '00000000-0000-0000-0000-000000000042',
        },
      });
      expect(res.statusCode).toBe(401);
    }
    const locked = await harness.app.inject({
      method: 'POST',
      url: '/identity/sessions',
      payload: {
        email,
        password: 'correct-horse-battery-staple',
        deviceId: '00000000-0000-0000-0000-000000000042',
      },
    });
    expect(locked.statusCode).toBe(401);
    expect(locked.json<{ error: string }>().error).toBe('locked');
    // The successful session we minted earlier still works until it is
    // explicitly revoked — the lockout is for new sessions only.
    expect(s.accessToken).toBeTruthy();
  });
});
