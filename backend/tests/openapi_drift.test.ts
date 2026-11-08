import { describe, expect, it, beforeAll, afterAll } from 'vitest';
import { startHarness, type Harness } from './support/harness.js';
import { buildOpenApi } from '../src/http/openapi.js';

let harness: Harness;

beforeAll(async () => {
  harness = await startHarness();
}, 120_000);

afterAll(async () => {
  await harness.teardown();
});

/**
 * Drift guard: every protected route the Fastify app registers must have
 * a documented entry in the hand-written OpenAPI schema. Catches
 * additions that forget to update docs/openapi.ts. Routes that are
 * explicitly transport-infrastructure (no OpenAPI value) are listed in
 * TRANSPORT_ONLY and skipped.
 */
const TRANSPORT_ONLY = new Set<string>([
  '/healthz',
  '/openapi.json',
]);

describe('OpenAPI schema drift', () => {
  it('documents every live route', () => {
    const spec = buildOpenApi(harness.config);
    const declared = new Set(
      Object.keys((spec['paths'] as Record<string, unknown>) ?? {}),
    );
    const live = (harness.app as unknown as { liveRoutes: Set<string> }).liveRoutes;
    expect(live.size, 'app exposed no live routes').toBeGreaterThan(0);
    const normalise = (p: string) => p.replace(/:([^/]+)/g, '{$1}');
    const missing: string[] = [];
    for (const path of live) {
      if (TRANSPORT_ONLY.has(path)) continue;
      const openapiPath = normalise(path);
      if (!declared.has(openapiPath)) missing.push(openapiPath);
    }
    expect(missing, `missing in OpenAPI: ${missing.join(', ')}`).toEqual([]);
  });
});
