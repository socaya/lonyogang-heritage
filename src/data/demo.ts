import type { Asset, Liability, LedgerEntry } from '../model/finance';
/** Illustrative fixture data only. Never interpret as bank-connected or verified holdings. */
export const demoAssets: Asset[] = [
  { id: 'inv-1', kind: 'investment', name: 'Unit Trust Portfolio', institution: 'Investment account', category: 'Unit trusts', currency: 'UGX', grossValue: 138500000, ownerShare: 1, valuedOn: '2026-10-31', valuationSource: 'statement', cost: 126000000 },
  { id: 'inv-2', kind: 'investment', name: 'Government Treasury Bonds', institution: 'Securities portfolio', category: 'Treasury bonds', currency: 'UGX', grossValue: 105000000, ownerShare: 1, valuedOn: '2026-10-31', valuationSource: 'statement', cost: 99000000 },
  { id: 'property-1', kind: 'property', name: 'Rental House — Gulu', location: 'Gulu, Uganda', category: 'Residential rental', currency: 'UGX', grossValue: 175000000, ownerShare: 1, valuedOn: '2026-09-30', valuationSource: 'owner-estimate', cost: 150000000, incomePerMonth: 2500000 },
  { id: 'property-2', kind: 'property', name: 'Land — Namave', location: 'Wakiso, Uganda', category: 'Land', currency: 'UGX', grossValue: 45000000, ownerShare: 0.6, valuedOn: '2026-08-15', valuationSource: 'owner-estimate', cost: 28000000 },
  { id: 'savings-1', kind: 'savings', name: 'Fixed Deposit', institution: 'Savings account', category: 'Fixed deposit', currency: 'UGX', grossValue: 40000000, ownerShare: 1, valuedOn: '2026-10-31', valuationSource: 'statement' },
  { id: 'savings-2', kind: 'savings', name: 'SACCO Savings', institution: 'Member account', category: 'SACCO', currency: 'UGX', grossValue: 18000000, ownerShare: 1, valuedOn: '2026-10-31', valuationSource: 'statement' },
  { id: 'other-1', kind: 'other', name: 'Vehicle', category: 'Vehicle', currency: 'UGX', grossValue: 11500000, ownerShare: 1, valuedOn: '2026-10-01', valuationSource: 'owner-estimate' },
];
export const demoLiabilities: Liability[] = [
  { id: 'loan-1', name: 'Rental property mortgage', amount: 39000000, linkedAssetId: 'property-1', asOf: '2026-10-31', rate: 13.5 },
  { id: 'loan-2', name: 'Personal loan', amount: 8450000, asOf: '2026-10-31', rate: 15 },
];
export const demoLedger: LedgerEntry[] = [
  { id: 'tx-1', description: 'Rental income received', account: 'Rental House — Gulu', amount: 2500000, date: '2026-11-02', kind: 'income', assetId: 'property-1' },
  { id: 'tx-2', description: 'Unit trust contribution', account: 'Unit Trust Portfolio', amount: -5000000, date: '2026-11-01', kind: 'transfer', assetId: 'inv-1' },
  { id: 'tx-3', description: 'Maintenance expense', account: 'Rental House — Gulu', amount: -750000, date: '2026-10-24', kind: 'expense', assetId: 'property-1' },
  { id: 'tx-4', description: 'Bond coupon received', account: 'Government Treasury Bonds', amount: 1200000, date: '2026-10-20', kind: 'income', assetId: 'inv-2' },
];
