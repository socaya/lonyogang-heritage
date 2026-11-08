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
 * End-to-end coverage for the per-entity REST surface at /resources/:kind.
 * Confirms that CRUD round-trips, counts update, and optimistic
 * concurrency returns 409 version_conflict when the client holds a stale
 * expectedVersion.
 */
describe('resources REST layer', () => {
  async function authed(email: string) {
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
        deviceId: '00000000-0000-0000-0000-000000000080',
      },
    });
    return signIn.json<{ accessToken: string }>().accessToken;
  }

  it('PUT upserts, GET reads, DELETE tombstones, counts stay honest', async () => {
    const accessToken = await authed(`res-${Date.now()}@example.com`);
    const h = { authorization: `Bearer ${accessToken}` };

    // Nothing yet.
    const empty = await harness.app.inject({
      method: 'GET',
      url: '/resources',
      headers: h,
    });
    expect(empty.json<{ counts: Record<string, number> }>().counts).toEqual({});

    // Upsert an asset.
    const put1 = await harness.app.inject({
      method: 'PUT',
      url: '/resources/asset/plot-1',
      headers: h,
      payload: {
        ciphertext: Buffer.from('ciphertext-v1').toString('base64'),
        integrity: { ownership_bps: 10000 },
        deviceId: '00000000-0000-0000-0000-000000000080',
      },
    });
    expect(put1.statusCode).toBe(200);
    expect(put1.json<{ version: number }>().version).toBe(1);

    // List now has one entry.
    const list = await harness.app.inject({
      method: 'GET',
      url: '/resources/asset',
      headers: h,
    });
    expect(list.json<{ resources: unknown[] }>().resources).toHaveLength(1);

    // Upsert again with correct expectedVersion → version 2.
    const put2 = await harness.app.inject({
      method: 'PUT',
      url: '/resources/asset/plot-1',
      headers: h,
      payload: {
        ciphertext: Buffer.from('ciphertext-v2').toString('base64'),
        integrity: { ownership_bps: 10000 },
        deviceId: '00000000-0000-0000-0000-000000000080',
        expectedVersion: 1,
      },
    });
    expect(put2.json<{ version: number }>().version).toBe(2);

    // Upsert with stale expectedVersion → 409.
    const conflict = await harness.app.inject({
      method: 'PUT',
      url: '/resources/asset/plot-1',
      headers: h,
      payload: {
        ciphertext: Buffer.from('ciphertext-v3').toString('base64'),
        deviceId: '00000000-0000-0000-0000-000000000080',
        expectedVersion: 1,
      },
    });
    expect(conflict.statusCode).toBe(409);
    expect(conflict.json<{ error: string }>().error).toBe('version_conflict');

    // DELETE tombstones; subsequent GET returns 404.
    const del = await harness.app.inject({
      method: 'DELETE',
      url: '/resources/asset/plot-1',
      headers: h,
      payload: { deviceId: '00000000-0000-0000-0000-000000000080' },
    });
    expect(del.statusCode).toBe(204);
    const after = await harness.app.inject({
      method: 'GET',
      url: '/resources/asset/plot-1',
      headers: h,
    });
    expect(after.statusCode).toBe(404);
  });

  it('paginates with hasMore + nextSince so clients can drain large sets',
      async () => {
    const accessToken = await authed(`page-${Date.now()}@example.com`);
    const h = { authorization: `Bearer ${accessToken}` };
    for (let i = 0; i < 3; i += 1) {
      const put = await harness.app.inject({
        method: 'PUT',
        url: `/resources/ledger_event/evt-${i}`,
        headers: h,
        payload: {
          ciphertext: Buffer.from(`ciphertext-${i}`).toString('base64'),
          deviceId: '00000000-0000-0000-0000-000000000083',
        },
      });
      expect(put.statusCode).toBe(200);
    }
    const first = await harness.app.inject({
      method: 'GET',
      url: '/resources/ledger_event?limit=2',
      headers: h,
    });
    const firstBody = first.json<{ resources: unknown[]; hasMore: boolean; nextSince: string | null }>();
    expect(firstBody.resources).toHaveLength(2);
    expect(firstBody.hasMore).toBe(true);
    expect(firstBody.nextSince).not.toBeNull();

    const second = await harness.app.inject({
      method: 'GET',
      url: `/resources/ledger_event?limit=2&since=${encodeURIComponent(firstBody.nextSince!)}`,
      headers: h,
    });
    const secondBody = second.json<{ resources: unknown[]; hasMore: boolean }>();
    // One row left after the first two.
    expect(secondBody.resources).toHaveLength(1);
    expect(secondBody.hasMore).toBe(false);
  });

  it('DELETE /resources/:kind tombstones every live row in one call',
      async () => {
    const accessToken = await authed(`bulk-${Date.now()}@example.com`);
    const h = { authorization: `Bearer ${accessToken}` };
    for (let i = 0; i < 3; i += 1) {
      await harness.app.inject({
        method: 'PUT',
        url: `/resources/alert_dismissal/key-${i}`,
        headers: h,
        payload: {
          ciphertext: Buffer.from(`c-${i}`).toString('base64'),
          deviceId: '00000000-0000-0000-0000-000000000084',
        },
      });
    }
    const beforeClear = await harness.app.inject({
      method: 'GET',
      url: '/resources/alert_dismissal',
      headers: h,
    });
    expect(
      beforeClear.json<{ resources: unknown[] }>().resources,
    ).toHaveLength(3);

    const clear = await harness.app.inject({
      method: 'DELETE',
      url: '/resources/alert_dismissal',
      headers: h,
      payload: { deviceId: '00000000-0000-0000-0000-000000000084' },
    });
    expect(clear.statusCode).toBe(200);
    expect(clear.json<{ cleared: number }>().cleared).toBe(3);

    const afterClear = await harness.app.inject({
      method: 'GET',
      url: '/resources/alert_dismissal',
      headers: h,
    });
    expect(
      afterClear.json<{ resources: unknown[] }>().resources,
    ).toHaveLength(0);
  });

  it('rejects an oversized ciphertext up front', async () => {
    const accessToken = await authed(`big-${Date.now()}@example.com`);
    const h = { authorization: `Bearer ${accessToken}` };
    const huge = Buffer.alloc(400 * 1024, 65).toString('base64');
    const put = await harness.app.inject({
      method: 'PUT',
      url: '/resources/asset/giant',
      headers: h,
      payload: {
        ciphertext: huge,
        deviceId: '00000000-0000-0000-0000-000000000082',
      },
    });
    expect(put.statusCode).toBe(400);
  });

  it('includeDeleted surfaces tombstoned rows for forensic queries', async () => {
    const accessToken = await authed(`tomb-${Date.now()}@example.com`);
    const h = { authorization: `Bearer ${accessToken}` };
    await harness.app.inject({
      method: 'PUT',
      url: '/resources/goal/g1',
      headers: h,
      payload: {
        ciphertext: Buffer.from('c').toString('base64'),
        deviceId: '00000000-0000-0000-0000-000000000081',
      },
    });
    await harness.app.inject({
      method: 'DELETE',
      url: '/resources/goal/g1',
      headers: h,
      payload: { deviceId: '00000000-0000-0000-0000-000000000081' },
    });
    const visible = await harness.app.inject({
      method: 'GET',
      url: '/resources/goal',
      headers: h,
    });
    expect(visible.json<{ resources: unknown[] }>().resources).toHaveLength(0);
    const all = await harness.app.inject({
      method: 'GET',
      url: '/resources/goal?includeDeleted=true',
      headers: h,
    });
    expect(all.json<{ resources: unknown[] }>().resources).toHaveLength(1);
  });
});
