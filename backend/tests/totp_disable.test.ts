import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { authenticator } from 'otplib';
import { startHarness, type Harness } from './support/harness.js';

let harness: Harness;

beforeAll(async () => {
  harness = await startHarness();
}, 120_000);

afterAll(async () => {
  await harness.teardown();
});

/**
 * TOTP disable requires a valid current code. A stolen access token on
 * its own cannot strip the second factor off the account.
 */
describe('DELETE /identity/totp', () => {
  async function signedIn(email: string) {
    const signup = await harness.app.inject({
      method: 'POST',
      url: '/identity/accounts',
      payload: { email, password: 'correct-horse-battery-staple' },
    });
    const accountId = (signup.json() as { accountId: string }).accountId;
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
        deviceId: '00000000-0000-0000-0000-000000000085',
      },
    });
    return (signIn.json() as { accessToken: string }).accessToken;
  }

  it('rejects an invalid code and removes TOTP with a valid code', async () => {
    const token = await signedIn(`totp-${Date.now()}@example.com`);
    const h = { authorization: `Bearer ${token}` };

    const enrol = await harness.app.inject({
      method: 'POST',
      url: '/identity/totp',
      headers: h,
    });
    const secret = (enrol.json() as { secret: string }).secret;

    const bad = await harness.app.inject({
      method: 'DELETE',
      url: '/identity/totp',
      headers: h,
      payload: { code: '000000' },
    });
    expect(bad.statusCode).toBe(401);

    const code = authenticator.generate(secret);
    const good = await harness.app.inject({
      method: 'DELETE',
      url: '/identity/totp',
      headers: h,
      payload: { code },
    });
    expect(good.statusCode).toBe(204);

    // Re-enrolling after removal issues a brand-new secret.
    const enrol2 = await harness.app.inject({
      method: 'POST',
      url: '/identity/totp',
      headers: h,
    });
    expect((enrol2.json() as { secret: string }).secret).not.toBe(secret);
  });
});
