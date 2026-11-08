import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  InvalidPushTokenError,
  PushService,
  type PushTransport,
  type PushMessage,
} from '../src/services/push.js';
import { startHarness, type Harness } from './support/harness.js';

let harness: Harness;

beforeAll(async () => {
  harness = await startHarness();
}, 120_000);

afterAll(async () => {
  await harness.teardown();
});

/**
 * Fake transport that raises InvalidPushTokenError on the first send,
 * returns normally on the second. Confirms that the PushService drops
 * the dead token row on the first failure so the second send's
 * `attempted` count reflects pruning.
 */
class _ThrowThenSucceed implements PushTransport {
  readonly name: 'fcm' | 'apns';
  deliveries = 0;
  constructor(name: 'fcm' | 'apns') {
    this.name = name;
  }
  async send(_token: string, _message: PushMessage): Promise<void> {
    this.deliveries += 1;
    if (this.deliveries === 1) {
      throw new InvalidPushTokenError('dead');
    }
  }
}

describe('push token pruning', () => {
  it('drops a token row after InvalidPushTokenError and stops retrying it',
    async () => {
      // Need a signed-in account to hang push_tokens off.
      const email = `push-${Date.now()}@example.com`;
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

      // Direct service call: register a token for this account.
      await harness.services.push.registerToken({
        accountId,
        deviceId: '00000000-0000-0000-0000-000000000090',
        platform: 'fcm',
        token: 'dead-token-xyz',
      });

      // Re-register with our throwing transport so the service drops
      // the row on the first send attempt.
      const svc = new PushService(harness.pool as any, harness.services.audit);
      const throwing = new _ThrowThenSucceed('fcm');
      svc.register(throwing);

      const first = await svc.send({
        accountId,
        title: 'Hello',
        body: 'There',
        alertId: 'a1',
      });
      expect(first.attempted).toBe(1);
      expect(first.delivered).toBe(0);
      expect(first.pruned).toBe(1);

      // After the pruning, there should be nothing left to deliver.
      const second = await svc.send({
        accountId,
        title: 'Hello',
        body: 'There',
        alertId: 'a2',
      });
      expect(second.attempted).toBe(0);
    });
});
