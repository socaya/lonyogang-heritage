import 'dart:math' as math;
import 'models.dart';

/// Ownership is measured in basis points, 10,000 = 100%.
/// Rounded down to whole UGX so values are deterministic and auditable.
int ownedValue(WealthAsset asset) {
  if (asset.ownershipBps < 0 || asset.ownershipBps > 10000) {
    throw ArgumentError.value(asset.ownershipBps, 'ownershipBps', 'Must be 0..10000');
  }
  if (asset.valueUgx < 0) throw ArgumentError.value(asset.valueUgx, 'valueUgx');
  return ((BigInt.from(asset.valueUgx) * BigInt.from(asset.ownershipBps)) ~/
      BigInt.from(10000)).toInt();
}

int grossOwnedAssets(Iterable<WealthAsset> assets) =>
    assets.where((a) => !a.archived).fold<int>(0, (s, a) => s + ownedValue(a));

int totalDebt(Iterable<WealthDebt> debts) =>
    debts.fold<int>(0, (s, d) => s + d.balanceUgx);

int netWorth(Iterable<WealthAsset> assets, Iterable<WealthDebt> debts) =>
    grossOwnedAssets(assets) - totalDebt(debts);

int propertyEquity(WealthAsset asset, Iterable<WealthDebt> debts) {
  final linked = debts.where((d) => d.linkedAssetId == asset.id)
      .fold<int>(0, (s, d) => s + d.balanceUgx);
  return ownedValue(asset) - linked;
}

Map<AssetKind, int> allocation(Iterable<WealthAsset> assets) {
  final result = {for (final kind in AssetKind.values) kind: 0};
  for (final asset in assets.where((a) => !a.archived)) {
    result[asset.kind] = result[asset.kind]! + ownedValue(asset);
  }
  return result;
}

int amountFor(Iterable<WealthEntry> entries, EntryType type, {DateTime? from, DateTime? to}) =>
    entries.where((e) => e.type == type &&
        (from == null || !e.occurredAt.isBefore(from)) &&
        (to == null || e.occurredAt.isBefore(to)))
      .fold<int>(0, (s, e) => s + e.amountUgx);

int netOperatingCashFlow(Iterable<WealthEntry> entries, {DateTime? from, DateTime? to}) =>
    amountFor(entries, EntryType.income, from: from, to: to) -
    amountFor(entries, EntryType.expense, from: from, to: to);

/// Portfolio entries are independent journal records. They never silently
/// modify a manually reported holding balance or a property's valuation.
bool valuationIsStale(WealthAsset asset, DateTime asOf) {
  final days = asOf.difference(asset.valuedAt).inDays;
  final maxAge = switch (asset.kind) {
    AssetKind.property => 365,
    AssetKind.investment => 31,
    AssetKind.saving => 31,
    AssetKind.other => 365,
  };
  return days > maxAge;
}

/// Annualised money-weighted return from dated cash flows.
/// Required convention: invested amounts are negative, terminal value positive.
/// Bisection is used only when a valid sign bracket exists; null means not estimable.
double? xirr(List<({DateTime date, double amount})> cashFlows) {
  if (cashFlows.length < 2) return null;
  final flows = [...cashFlows]..sort((a, b) => a.date.compareTo(b.date));
  if (!flows.any((v) => v.amount < 0) || !flows.any((v) => v.amount > 0)) return null;
  final first = flows.first.date;
  double npv(double rate) {
    var sum = 0.0;
    for (final f in flows) {
      final years = f.date.difference(first).inDays / 365.25;
      sum += f.amount / math.pow(1 + rate, years);
    }
    return sum;
  }
  double low = -0.999, high = 10.0;
  var fLow = npv(low);
  final fHigh = npv(high);
  if (!fLow.isFinite || !fHigh.isFinite || fLow * fHigh > 0) return null;
  for (var i = 0; i < 180; i++) {
    final mid = (low + high) / 2;
    final fMid = npv(mid);
    if (fMid.abs() < 0.000001) return mid;
    if (fMid * fLow > 0) {
      low = mid; fLow = fMid;
    } else { high = mid; }
  }
  return (low + high) / 2;
}


