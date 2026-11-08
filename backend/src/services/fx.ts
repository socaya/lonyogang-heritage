import { request } from 'undici';
import type { Db } from '../db.js';
import { queryMany, queryOne } from '../db.js';
import type { AppConfig } from '../config.js';

/** A single rate observation. Everything is expressed as whole UGX per unit
 *  of the foreign currency so the client never has to deal with floats. */
export interface FxRate {
  currency: string;
  asOf: string; // ISO yyyy-MM-dd
  ugxPerUnit: number;
  source: string;
}

export interface FxProvider {
  /** Fetches rates for the supplied currencies at (or just before) `asOf`. */
  fetchRates(currencies: string[], asOf: Date): Promise<FxRate[]>;
}

const SUPPORTED = ['USD', 'EUR', 'GBP', 'KES', 'TZS', 'RWF'];

/**
 * Service used by the `/fx/rates` endpoint. Layered as:
 *   1. Postgres cache (`fx_rates_cache`) keyed on `(currency, as_of)`.
 *   2. Provider lookup for cache misses.
 *   3. Fallback to the most recent cached row when the provider is down.
 */
export class FxService {
  // Three consecutive provider failures trips the breaker for 60s so we
  // stop pounding a dead upstream and serving slow /fx/rates while every
  // request waits for a timeout. Stale cache is always served during the
  // open window.
  private providerFailures = 0;
  private breakerOpenUntil = 0;
  private static readonly FAILURE_THRESHOLD = 3;
  private static readonly BREAKER_COOLDOWN_MS = 60_000;

  constructor(
    private readonly db: Db,
    private readonly provider: FxProvider,
    private readonly config: AppConfig,
  ) {}

  private breakerIsOpen(): boolean {
    return Date.now() < this.breakerOpenUntil;
  }

  private noteProviderFailure(): void {
    this.providerFailures += 1;
    if (this.providerFailures >= FxService.FAILURE_THRESHOLD) {
      this.breakerOpenUntil = Date.now() + FxService.BREAKER_COOLDOWN_MS;
      this.providerFailures = 0;
    }
  }

  private noteProviderSuccess(): void {
    this.providerFailures = 0;
    this.breakerOpenUntil = 0;
  }

  async getRates(options: { currencies?: string[]; asOf?: Date } = {}): Promise<FxRate[]> {
    const asOf = options.asOf ?? new Date();
    const asOfKey = asOf.toISOString().slice(0, 10);
    const requested = (options.currencies ?? SUPPORTED).map((c) => c.toUpperCase());
    const cached = await queryMany<{
      currency: string;
      as_of: Date;
      ugx_per_unit: string;
      source: string;
      cached_at: Date;
    }>(
      this.db,
      `select currency, as_of, ugx_per_unit, source, cached_at
         from fx_rates_cache where currency = any($1) and as_of = $2`,
      [requested, asOfKey],
    );
    const fresh: FxRate[] = cached
      .filter((r) => Date.now() - r.cached_at.getTime() < this.config.FX_CACHE_TTL_SECONDS * 1000)
      .map((r) => ({
        currency: r.currency,
        asOf: r.as_of.toISOString().slice(0, 10),
        ugxPerUnit: Number(r.ugx_per_unit),
        source: r.source,
      }));
    const missing = requested.filter((c) => !fresh.some((f) => f.currency === c));
    if (missing.length === 0) return fresh;

    if (this.breakerIsOpen()) {
      // Breaker open — go straight to stale fallback. Avoids piling onto a
      // provider we already know is failing.
      return [...fresh, ...(await this.staleFallback(missing, asOfKey))];
    }

    try {
      const fetched = await this.provider.fetchRates(missing, asOf);
      this.noteProviderSuccess();
      for (const rate of fetched) {
        await this.db.query(
          `insert into fx_rates_cache (currency, as_of, ugx_per_unit, source, cached_at)
           values ($1, $2, $3, $4, now())
           on conflict (currency, as_of) do update
             set ugx_per_unit = excluded.ugx_per_unit,
                 source = excluded.source,
                 cached_at = now()`,
          [rate.currency, rate.asOf, rate.ugxPerUnit, rate.source],
        );
      }
      return [...fresh, ...fetched];
    } catch {
      this.noteProviderFailure();
      return [...fresh, ...(await this.staleFallback(missing, asOfKey))];
    }
  }

  /** Pulls the most recent cached rate for each requested currency so
   *  `/fx/rates` keeps returning data even when the upstream is down. */
  private async staleFallback(currencies: string[], asOfKey: string): Promise<FxRate[]> {
    const stale = await queryMany<{ currency: string; as_of: Date; ugx_per_unit: string; source: string }>(
      this.db,
      `select currency, as_of, ugx_per_unit, source
         from fx_rates_cache
         where currency = any($1) and as_of <= $2
         order by as_of desc`,
      [currencies, asOfKey],
    );
    const picked = new Map<string, FxRate>();
    for (const row of stale) {
      if (picked.has(row.currency)) continue;
      picked.set(row.currency, {
        currency: row.currency,
        asOf: row.as_of.toISOString().slice(0, 10),
        ugxPerUnit: Number(row.ugx_per_unit),
        source: `${row.source} (stale fallback)`,
      });
    }
    return Array.from(picked.values());
  }

  async latest(currency: string): Promise<FxRate | null> {
    const row = await queryOne<{
      currency: string;
      as_of: Date;
      ugx_per_unit: string;
      source: string;
    }>(
      this.db,
      `select currency, as_of, ugx_per_unit, source
         from fx_rates_cache
         where currency = $1
         order by as_of desc limit 1`,
      [currency.toUpperCase()],
    );
    if (!row) return null;
    return {
      currency: row.currency,
      asOf: row.as_of.toISOString().slice(0, 10),
      ugxPerUnit: Number(row.ugx_per_unit),
      source: row.source,
    };
  }

  static supportedCurrencies(): string[] {
    return [...SUPPORTED];
  }
}

/** Real provider that queries `exchangerate.host`'s free endpoint. The API
 *  quotes 1 USD → N target. We invert to produce UGX-per-unit figures. */
export class ExchangerateHostProvider implements FxProvider {
  constructor(private readonly base = 'https://api.exchangerate.host') {}

  async fetchRates(currencies: string[], asOf: Date): Promise<FxRate[]> {
    const dateKey = asOf.toISOString().slice(0, 10);
    const url = `${this.base}/${dateKey}?base=UGX&symbols=${currencies.join(',')}`;
    const { statusCode, body } = await request(url);
    if (statusCode < 200 || statusCode >= 300) {
      throw new Error(`exchangerate.host returned HTTP ${statusCode}`);
    }
    const json = (await body.json()) as {
      success?: boolean;
      rates?: Record<string, number>;
      date?: string;
    };
    if (!json.rates) throw new Error('exchangerate.host response missing `rates`');
    const results: FxRate[] = [];
    for (const [currency, ugxPerForeignInv] of Object.entries(json.rates)) {
      if (!currencies.includes(currency.toUpperCase())) continue;
      if (typeof ugxPerForeignInv !== 'number' || ugxPerForeignInv <= 0) continue;
      // `rates[FOO]` is amount of FOO per 1 UGX. Invert to UGX per FOO unit.
      const ugxPerUnit = Math.round(1 / ugxPerForeignInv);
      results.push({
        currency: currency.toUpperCase(),
        asOf: json.date ?? dateKey,
        ugxPerUnit,
        source: 'exchangerate.host',
      });
    }
    return results;
  }
}

/** Deterministic in-memory provider used by tests and local dev when there
 *  is no network available. Returns stable, boring numbers so snapshots are
 *  reproducible. */
export class MockFxProvider implements FxProvider {
  async fetchRates(currencies: string[], asOf: Date): Promise<FxRate[]> {
    const asOfKey = asOf.toISOString().slice(0, 10);
    const table: Record<string, number> = {
      USD: 3850,
      EUR: 4120,
      GBP: 4820,
      KES: 29,
      TZS: 1,
      RWF: 3,
    };
    return currencies
      .filter((c) => table[c.toUpperCase()] !== undefined)
      .map((c) => ({
        currency: c.toUpperCase(),
        asOf: asOfKey,
        ugxPerUnit: table[c.toUpperCase()]!,
        source: 'mock',
      }));
  }
}

/** Fallback Bank of Uganda adapter. The BoU publishes a daily PDF; this
 *  class scrapes the text form if available. Falls back to the mock table
 *  when the gateway returns anything the parser can't make sense of. */
export class BouProvider implements FxProvider {
  private readonly fallback = new MockFxProvider();
  constructor(private readonly endpoint = 'https://www.bou.or.ug/bou/bouwebsite/Statistics/ExchangeRates.html') {}

  async fetchRates(currencies: string[], asOf: Date): Promise<FxRate[]> {
    try {
      const { statusCode, body } = await request(this.endpoint);
      if (statusCode < 200 || statusCode >= 300) throw new Error(`HTTP ${statusCode}`);
      const text = await body.text();
      const rates: FxRate[] = [];
      for (const currency of currencies.map((c) => c.toUpperCase())) {
        const regex = new RegExp(`${currency}[^0-9]+(\\d+[.,]?\\d*)`);
        const match = text.match(regex);
        if (!match || !match[1]) continue;
        const value = Number(match[1].replace(/,/g, ''));
        if (!Number.isFinite(value) || value <= 0) continue;
        rates.push({
          currency,
          asOf: asOf.toISOString().slice(0, 10),
          ugxPerUnit: Math.round(value),
          source: 'bou',
        });
      }
      if (rates.length === 0) throw new Error('BoU page returned no rates');
      return rates;
    } catch {
      return this.fallback.fetchRates(currencies, asOf);
    }
  }
}

export function pickProvider(config: AppConfig): FxProvider {
  switch (config.FX_PROVIDER) {
    case 'bou':
      return new BouProvider();
    case 'mock':
      return new MockFxProvider();
    case 'exchangerate_host':
    default:
      return new ExchangerateHostProvider();
  }
}
