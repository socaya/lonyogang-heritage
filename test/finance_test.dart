import 'package:flutter_test/flutter_test.dart';
import 'package:lonyogang_heritage/domain/models.dart';
import 'package:lonyogang_heritage/domain/finance.dart';

WealthAsset asset(String id, AssetKind kind, int value, {int ownership = 10000, bool archived = false}) =>
  WealthAsset(id: id, kind: kind, name: id, valueUgx: value, costUgx: value,
    ownershipBps: ownership, valuedAt: DateTime.utc(2026, 10, 1),
    valuationSource: ValuationSource.ownerEstimate,
    acquiredAt: DateTime.utc(2024), archived: archived);

void main() {
  final a = asset('plot', AssetKind.property, 240000000, ownership: 5000);
  final b = asset('shares', AssetKind.investment, 18000000);
  final debt = WealthDebt(id: 'm', name: 'Mortgage', balanceUgx: 40000000,
    lender: 'Lender', linkedAssetId: a.id);

  test('partial ownership influences net worth', () {
    expect(ownedValue(a), 120000000);
    expect(grossOwnedAssets([a, b]), 138000000);
    expect(netWorth([a, b], [debt]), 98000000);
  });
  test('mortgage is deducted only once', () {
    expect(propertyEquity(a, [debt]), 80000000);
    expect(netWorth([a, b], [debt]), 98000000);
  });
  test('archived asset omitted', () {
    expect(grossOwnedAssets([a, b.copyWith(archived: true)]), 120000000);
  });
  test('ownership bounds validated', () {
    expect(() => ownedValue(a.copyWith(ownershipBps: 11000)), throwsArgumentError);
  });
  test('allocation totals reconcile', () {
    expect(allocation([a, b]).values.reduce((x, y) => x + y), 138000000);
  });
  test('cash flow records do not change assets', () {
    final entry = WealthEntry(id: 'x', type: EntryType.income,
      amountUgx: 1500000, category: 'Rent', occurredAt: DateTime.utc(2026));
    expect(netOperatingCashFlow([entry]), 1500000);
    expect(ownedValue(a), 120000000);
  });
  test('date window excludes later entries', () {
    final now = WealthEntry(id: 'a', type: EntryType.expense,
      amountUgx: 3000, category: 'A', occurredAt: DateTime.utc(2026, 1, 2));
    final later = WealthEntry(id: 'b', type: EntryType.expense,
      amountUgx: 5000, category: 'B', occurredAt: DateTime.utc(2027));
    expect(amountFor([now, later], EntryType.expense, to: DateTime.utc(2027)), 3000);
  });
  test('property value freshness separately from investment', () {
    final now = DateTime.utc(2026, 12, 10);
    expect(valuationIsStale(a, now), false);
    expect(valuationIsStale(b, now), true);
  });
  test('xirr simple annual growth', () {
    final r = xirr([
      (date: DateTime.utc(2024, 1, 1), amount: -1000),
      (date: DateTime.utc(2025, 1, 1), amount: 1100),
    ]);
    expect(r, isNotNull);
    expect(r!, closeTo(0.10, 0.002));
  });
  test('xirr returns null without opposite sign cash flow', () {
    expect(xirr([(date: DateTime.utc(2024), amount: -1000)]), isNull);
  });
  test('asset database roundtrip', () {
    expect(WealthAsset.fromDb(a.toDb()).valueUgx, a.valueUgx);
    expect(WealthAsset.fromDb(a.toDb()).ownershipBps, a.ownershipBps);
  });
  test('debt database roundtrip', () {
    expect(WealthDebt.fromDb(debt.toDb()).linkedAssetId, a.id);
  });
}
