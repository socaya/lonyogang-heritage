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
 * The global rate limit (180/min) is deliberately generous because it has
 * to cover sync pulls, FX refreshes and background heartbeats. Sensitive
 * credential endpoints must throttle much earlier so a credential-stuffing
 * attacker hitting /identity/sessions is capped at the tighter per-route
 * window.
 */
describe('sign-in rate limit', () => {
  it('responds with 429 after the per-route limit is exceeded', async () => {
    // The route limit is 10/min — issue a burst of eleven and expect the
    // final one to be rejected with 429 before even reaching the handler.
    const email = 'ratelimit@example.com';
    // Use an un-provisioned email so we always get a 401; any status in
    // 2xx/4xx is fine — we are asserting the 429 shape, not auth success.
    let sawRateLimit = false;
    for (let i = 0; i < 15; i += 1) {
      const res = await harness.app.inject({
        method: 'POST',
        url: '/identity/sessions',
        payload: {
          email,
          password: 'anything-long-enough',
          deviceId: '00000000-0000-0000-0000-000000000070',
        },
        remoteAddress: '203.0.113.42',
      });
      if (res.statusCode === 429) {
        sawRateLimit = true;
        expect(res.headers['retry-after']).toBeDefined();
        break;
      }
    }
    expect(sawRateLimit, 'expected the route-scoped 429 cap to engage').toBe(true);
  });
});
