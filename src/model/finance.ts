export type AssetKind = 'investment' | 'property' | 'savings' | 'other';
export type ValuationSource = 'owner-estimate' | 'statement' | 'independent-appraisal';
export type Asset = {
  id: string;
  kind: AssetKind;
  name: string;
  institution?: string;
  category?: string;
  location?: string;
  currency: 'UGX';
  grossValue: number;
  ownerShare: number; // [0, 1]. Gross asset valuation is owner-attributable for summaries.
  valuedOn: string; // ISO date
  valuationSource: ValuationSource;
  cost?: number;
  incomePerMonth?: number;
  notes?: string;
};
export type Liability = {
  id: string;
  name: string;
  amount: number;
  asOf: string;
  linkedAssetId?: string;
  rate?: number;
};
export type LedgerEntry = {
  id: string; description: string; account: string; amount: number;
  date: string; kind: 'income' | 'expense' | 'transfer'; assetId?: string;
};
export type WealthSnapshot = {
  investments: number; properties: number; savings: number; other: number;
  grossAssets: number; debts: number; netWorth: number; totalLiquid: number;
};
export function sumWealth(assets: Asset[], liabilities: Liability[]): WealthSnapshot {
  const sums = { investment: 0, property: 0, savings: 0, other: 0 };
  for (const asset of assets) {
    if (!Number.isFinite(asset.grossValue) || asset.grossValue < 0 || !Number.isFinite(asset.ownerShare) || asset.ownerShare < 0 || asset.ownerShare > 1) continue;
    sums[asset.kind] += asset.grossValue * asset.ownerShare;
  }
  // Debt is subtracted exactly once, including mortgages linked to real estate.
  const debts = liabilities.reduce((total, debt) => total + (Number.isFinite(debt.amount) && debt.amount > 0 ? debt.amount : 0), 0);
  const grossAssets = sums.investment + sums.property + sums.savings + sums.other;
  return {
    investments: sums.investment, properties: sums.property, savings: sums.savings, other: sums.other,
    grossAssets, debts, netWorth: grossAssets - debts, totalLiquid: sums.savings,
  };
}
export function fmtUGX(value: number, compact = false): string {
  if (!Number.isFinite(value)) return 'UGX —';
  const sign = value < 0 ? '−' : '';
  const v = Math.abs(value);
  if (compact && v >= 1e9) return `${sign}UGX ${(v / 1e9).toFixed(2)}B`;
  if (compact && v >= 1e6) return `${sign}UGX ${(v / 1e6).toFixed(2)}M`;
  if (compact && v >= 1e3) return `${sign}UGX ${(v / 1e3).toFixed(1)}K`;
  return `${sign}UGX ${Math.round(v).toLocaleString('en-US')}`;
}
export function parseUGX(value: string): number | null {
  const cleaned = value.replace(/[,\s]/g, '');
  if (!/^\d+(\.\d{1,2})?$/.test(cleaned)) return null;
  const amount = Number(cleaned);
  return Number.isSafeInteger(Math.round(amount)) && amount >= 0 ? amount : null;
}
export function valuationAgeDays(isoDate: string, today = new Date()): number | null {
  const date = new Date(`${isoDate}T00:00:00Z`);
  if (Number.isNaN(date.getTime())) return null;
  return Math.max(0, Math.floor((today.getTime() - date.getTime()) / 86400000));
}
