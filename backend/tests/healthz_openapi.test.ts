import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { startHarness, type Harness } from './support/harness.js';
import { buildOpenApi } from '../src/http/openapi.js';

let harness: Harness;

beforeAll(async () => {
  harness = await startHarness();
}, 120_000);

afterAll(async () => {
  await harness.teardown();
});

describe('healthz', () => {
  it('reports database as ok and surfaces per-check latency', async () => {
    const res = await harness.app.inject({ method: 'GET', url: '/healthz' });
    expect([200, 503]).toContain(res.statusCode);
    const body = res.json<{
      status: string;
      dpoContact: string;
      version: string;
      checks: Record<string, { status: string; latencyMs: number }>;
    }>();
    expect(body.dpoContact).toBe('privacy@lonyogang.com');
    expect(body.checks['database']?.status).toBe('ok');
    expect(body.checks['kms']?.status).toBe('ok');
    expect(body.checks['objectStorage']).toBeDefined();
    // objectStorage runs against a non-existent MinIO in the test harness,
    // so it's expected to be `degraded` (not fatal).
    expect(['ok', 'degraded']).toContain(body.checks['objectStorage']!.status);
  });
});

describe('openapi.json', () => {
  it('serves the OpenAPI 3.1 schema', async () => {
    const res = await harness.app.inject({ method: 'GET', url: '/openapi.json' });
    expect(res.statusCode).toBe(200);
    const spec = res.json<Record<string, unknown>>();
    expect(spec['openapi']).toBe('3.1.0');
    const paths = spec['paths'] as Record<string, unknown>;
    for (const required of [
      '/identity/accounts',
      '/identity/sessions',
      '/sync/events',
      '/audit/entries',
      '/audit/anchors',
      '/fx/rates',
      '/recovery/enroll',
      '/billing/subscription',
    ]) {
      expect(paths[required], `missing path ${required}`).toBeDefined();
    }
  });

  it('builds a stable schema object from the config', () => {
    const spec = buildOpenApi(harness.config);
    expect(((spec['info'] as Record<string, unknown>)['title'] as string)).toContain('LonyoGang');
  });
});
