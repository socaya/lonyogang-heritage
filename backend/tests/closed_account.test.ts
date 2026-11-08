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
 * A closed account's sign-in path must return the generic bad_credentials
 * error. Returning `account_closed` (or any status-specific message) lets
 * an attacker probe which emails belonged to real users, violating the
 * same enumeration contract the password-reset path already honours.
 */
describe('closed account sign-in', () => {
  it('returns bad_credentials, not an existence signal', async () => {
    const email = `closer-${Date.now()}@example.com`;

    // Create + verify + close.
    const signup = await harness.app.inject({
      method: 'POST',
      url: '/identity/accounts',
      payload: { email, password: 'long-enough-passphrase-9' },
    });
    expect(signup.statusCode).toBe(201);
    const accountId = (signup.json() as { accountId: string }).accountId;
    const code = harness.otp.latestCode(accountId, 'email')!;
    const verify = await harness.app.inject({
      method: 'POST',
      url: '/identity/accounts/verify',
      payload: { accountId, channel: 'email', code },
    });
    expect(verify.statusCode).toBe(200);

    await harness.services.account.eraseAccount(accountId);

    const attempt = await harness.app.inject({
      method: 'POST',
      url: '/identity/sessions',
      payload: {
        email,
        password: 'long-enough-passphrase-9',
        deviceId: '00000000-0000-0000-0000-000000000090',
      },
    });
    expect(attempt.statusCode).toBe(401);
    const body = attempt.json() as { error: string };
    expect(body.error).toBe('bad_credentials');
  });
});
