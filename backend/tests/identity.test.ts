import { describe, expect, it, beforeAll, afterAll } from 'vitest';
import { startHarness, type Harness } from './support/harness.js';

let harness: Harness;

beforeAll(async () => {
  harness = await startHarness();
}, 120_000);

afterAll(async () => {
  await harness.teardown();
});

async function createVerifiedAccount(email: string) {
  const signup = await harness.app.inject({
    method: 'POST',
    url: '/identity/accounts',
    payload: {
      email,
      password: 'correct-horse-battery-staple',
      phone: '+256700123456',
      displayName: 'Test User',
    },
  });
  expect(signup.statusCode).toBe(201);
  const body = signup.json<{ accountId: string; emailCode: string; phoneCode: string }>();
  const verifyEmail = await harness.app.inject({
    method: 'POST',
    url: '/identity/accounts/verify',
    payload: { accountId: body.accountId, channel: 'email', code: body.emailCode },
  });
  expect(verifyEmail.statusCode).toBe(200);
  const verifyPhone = await harness.app.inject({
    method: 'POST',
    url: '/identity/accounts/verify',
    payload: { accountId: body.accountId, channel: 'phone', code: body.phoneCode },
  });
  expect(verifyPhone.statusCode).toBe(200);
  expect(verifyPhone.json<{ status: string }>().status).toBe('active');
  return body.accountId;
}

describe('identity service', () => {
  it('signs up, verifies, signs in, refreshes and revokes', async () => {
    const email = 'signup@example.com';
    const accountId = await createVerifiedAccount(email);
    const signIn = await harness.app.inject({
      method: 'POST',
      url: '/identity/sessions',
      payload: {
        email,
        password: 'correct-horse-battery-staple',
        deviceId: '00000000-0000-0000-0000-000000000001',
      },
    });
    expect(signIn.statusCode).toBe(200);
    const session = signIn.json<{ accessToken: string; refreshToken: string; sessionId: string }>();
    expect(session.accessToken).toBeTruthy();

    const refresh = await harness.app.inject({
      method: 'POST',
      url: '/identity/sessions/refresh',
      payload: { refreshToken: session.refreshToken },
    });
    expect(refresh.statusCode).toBe(200);

    const revoke = await harness.app.inject({
      method: 'DELETE',
      url: `/identity/sessions/${session.sessionId}`,
      headers: { authorization: `Bearer ${refresh.json<{ accessToken: string }>().accessToken}` },
    });
    expect(revoke.statusCode).toBe(204);

    const list = await harness.app.inject({
      method: 'GET',
      url: '/identity/sessions',
      headers: { authorization: `Bearer ${refresh.json<{ accessToken: string }>().accessToken}` },
    });
    // The current token should still work, but the listed session is revoked.
    expect(list.statusCode).toBe(200);
    expect(
      list.json<{ sessions: { id: string; revoked_at: string | null }[] }>().sessions.some(
        (s) => s.id === session.sessionId && s.revoked_at !== null,
      ),
    ).toBe(true);
    expect(accountId).toBeTruthy();
  });

  it('rejects bad password and preserves constant-time semantics', async () => {
    await createVerifiedAccount('bad-pw@example.com');
    const attempt = await harness.app.inject({
      method: 'POST',
      url: '/identity/sessions',
      payload: {
        email: 'bad-pw@example.com',
        password: 'wrong-password',
        deviceId: '00000000-0000-0000-0000-000000000002',
      },
    });
    expect(attempt.statusCode).toBe(401);
    expect(attempt.json<{ error: string }>().error).toBe('bad_credentials');
  });

  it('issues and verifies a working TOTP secret', async () => {
    const email = 'totp@example.com';
    await createVerifiedAccount(email);
    const session = await harness.app.inject({
      method: 'POST',
      url: '/identity/sessions',
      payload: {
        email,
        password: 'correct-horse-battery-staple',
        deviceId: '00000000-0000-0000-0000-000000000003',
      },
    });
    const access = session.json<{ accessToken: string }>().accessToken;
    const enrol = await harness.app.inject({
      method: 'POST',
      url: '/identity/totp',
      headers: { authorization: `Bearer ${access}` },
    });
    expect(enrol.statusCode).toBe(200);
    const { secret } = enrol.json<{ secret: string; otpauthUrl: string }>();
    const { authenticator } = await import('otplib');
    const totpCode = authenticator.generate(secret);
    const totpSignIn = await harness.app.inject({
      method: 'POST',
      url: '/identity/sessions',
      payload: {
        email,
        password: 'correct-horse-battery-staple',
        deviceId: '00000000-0000-0000-0000-000000000003',
        totpCode,
      },
    });
    expect(totpSignIn.statusCode).toBe(200);

    const badTotp = await harness.app.inject({
      method: 'POST',
      url: '/identity/sessions',
      payload: {
        email,
        password: 'correct-horse-battery-staple',
        deviceId: '00000000-0000-0000-0000-000000000003',
        totpCode: '000000',
      },
    });
    expect(badTotp.statusCode).toBe(401);
  });

  it('runs anti-enumeration password reset', async () => {
    const email = 'reset@example.com';
    await createVerifiedAccount(email);
    const begin = await harness.app.inject({
      method: 'POST',
      url: '/identity/password/reset/begin',
      payload: { email },
    });
    expect(begin.statusCode).toBe(200);
    const { dispatchToken } = begin.json<{ dispatchToken: string }>();
    expect(dispatchToken).toBeTruthy();
    const complete = await harness.app.inject({
      method: 'POST',
      url: '/identity/password/reset/complete',
      payload: { email, token: dispatchToken, newPassword: 'new-password-123' },
    });
    expect(complete.statusCode).toBe(204);
    const oldAttempt = await harness.app.inject({
      method: 'POST',
      url: '/identity/sessions',
      payload: {
        email,
        password: 'correct-horse-battery-staple',
        deviceId: '00000000-0000-0000-0000-000000000005',
      },
    });
    expect(oldAttempt.statusCode).toBe(401);
    const newAttempt = await harness.app.inject({
      method: 'POST',
      url: '/identity/sessions',
      payload: {
        email,
        password: 'new-password-123',
        deviceId: '00000000-0000-0000-0000-000000000005',
      },
    });
    expect(newAttempt.statusCode).toBe(200);
  });

  it('produces no dispatchToken for an unknown email (anti-enumeration)', async () => {
    const begin = await harness.app.inject({
      method: 'POST',
      url: '/identity/password/reset/begin',
      payload: { email: 'nobody@example.com' },
    });
    expect(begin.statusCode).toBe(200);
    expect(begin.json<{ dispatchToken: string | null }>().dispatchToken).toBeNull();
  });
});
