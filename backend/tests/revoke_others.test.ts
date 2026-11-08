import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { startHarness, type Harness } from './support/harness.js';

let harness: Harness;

beforeAll(async () => {
  harness = await startHarness();
}, 120_000);

afterAll(async () => {
  await harness.teardown();
});

/**
 * POST /identity/sessions/revoke-others revokes every live session for
 * the authenticated account except the one on the calling token. This
 * is the "sign out everywhere else" surface after a lost device.
 */
describe('revoke-others', () => {
  async function authed(email: string, deviceId: string) {
    const signup = await harness.app.inject({
      method: 'POST',
      url: '/identity/accounts',
      payload: { email, password: 'correct-horse-battery-staple' },
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
        deviceId,
      },
    });
    return {
      accountId,
      ...signIn.json<{ accessToken: string; sessionId: string }>(),
    };
  }

  it('revokes other sessions but keeps the caller alive', async () => {
    const email = `revoke-${Date.now()}@example.com`;
    const first = await authed(email, '00000000-0000-0000-0000-000000000090');
    const second = await harness.app.inject({
      method: 'POST',
      url: '/identity/sessions',
      payload: {
        email,
        password: 'correct-horse-battery-staple',
        deviceId: '00000000-0000-0000-0000-000000000091',
      },
    });
    expect(second.statusCode).toBe(200);
    const third = await harness.app.inject({
      method: 'POST',
      url: '/identity/sessions',
      payload: {
        email,
        password: 'correct-horse-battery-staple',
        deviceId: '00000000-0000-0000-0000-000000000092',
      },
    });
    expect(third.statusCode).toBe(200);

    // From the first session, nuke everyone else.
    const nuke = await harness.app.inject({
      method: 'POST',
      url: '/identity/sessions/revoke-others',
      headers: { authorization: `Bearer ${first.accessToken}` },
    });
    expect(nuke.statusCode).toBe(200);
    expect(nuke.json<{ revoked: number }>().revoked).toBe(2);

    // The first session still works.
    const firstMe = await harness.app.inject({
      method: 'GET',
      url: '/me',
      headers: { authorization: `Bearer ${first.accessToken}` },
    });
    expect(firstMe.statusCode).toBe(200);

    // The other two refresh tokens must be dead.
    const secondRefresh = await harness.app.inject({
      method: 'POST',
      url: '/identity/sessions/refresh',
      payload: {
        refreshToken:
          (second.json<{ refreshToken: string }>()).refreshToken,
      },
    });
    expect(secondRefresh.statusCode).toBe(401);
  });

  it('a second call reports 0 revoked when nothing else is live', async () => {
    const email = `revoke-solo-${Date.now()}@example.com`;
    const first = await authed(email, '00000000-0000-0000-0000-000000000093');
    const first1 = await harness.app.inject({
      method: 'POST',
      url: '/identity/sessions/revoke-others',
      headers: { authorization: `Bearer ${first.accessToken}` },
    });
    expect(first1.json<{ revoked: number }>().revoked).toBe(0);
  });
});
