import 'package:flutter_test/flutter_test.dart';
import 'package:lonyogang_heritage/domain/finance.dart';
import 'package:lonyogang_heritage/domain/models.dart';

void main() {
  test('TWR is null for single-point series', () {
    final series = [
      ValuedCashflow(at: DateTime(2024, 1, 1), valueUgx: 100000),
    ];
    expect(timeWeightedReturn(series), isNull);
  });

  test('TWR equals simple appreciation when there are no cashflows', () {
    final r = timeWeightedReturn([
      ValuedCashflow(at: DateTime(2024, 1, 1), valueUgx: 100),
      ValuedCashflow(at: DateTime(2025, 1, 1), valueUgx: 120),
    ]);
    expect(r, isNotNull);
    expect(r!, closeTo(0.20, 1e-3));
  });

  test('TWR neutralises an external contribution', () {
    // Period 1: start 1000, end 1600 with a 500 contribution at period end.
    // Growth of invested capital = (1600 - 500) / 1000 = 1.10.
    // Period 2: 1760 / 1600 = 1.10. Chain = 1.21 over 1 year => ~21%.
    final r = timeWeightedReturn([
      ValuedCashflow(at: DateTime(2024, 1, 1), valueUgx: 1000),
      ValuedCashflow(
          at: DateTime(2024, 7, 1), valueUgx: 1600, externalFlowUgx: 500),
      ValuedCashflow(at: DateTime(2025, 1, 1), valueUgx: 1760),
    ]);
    expect(r, isNotNull);
    expect(r!, closeTo(0.21, 1e-2));
  });

  test('XIRR returns a reasonable rate for a simple series', () {
    final flows = [
      XirrCashflow(DateTime(2024, 1, 1), -1000),
      XirrCashflow(DateTime(2025, 1, 1), 1100),
    ];
    final r = xirr(flows);
    expect(r, isNotNull);
    expect(r!, closeTo(0.10, 1e-3));
  });

  test('XIRR is null when there is no sign change', () {
    final flows = [
      XirrCashflow(DateTime(2024, 1, 1), 1000),
      XirrCashflow(DateTime(2025, 1, 1), 1100),
    ];
    expect(xirr(flows), isNull);
  });

  test('convertToUgx picks the freshest rate not after the asOf date', () {
    final rates = [
      FxRate(currency: 'USD', ugxPerUnit: 3800, asOf: DateTime(2024, 1, 1)),
      FxRate(currency: 'USD', ugxPerUnit: 3900, asOf: DateTime(2024, 6, 1)),
      FxRate(currency: 'USD', ugxPerUnit: 4000, asOf: DateTime(2025, 1, 1)),
    ];
    expect(
        convertToUgx(10, 'USD', DateTime(2024, 7, 1), rates), 39000);
    expect(
        convertToUgx(10, 'USD', DateTime(2025, 2, 1), rates), 40000);
    expect(convertToUgx(10, 'ZZZ', DateTime(2025, 1, 1), rates), isNull);
    expect(convertToUgx(5, 'UGX', DateTime(2025, 1, 1), rates), 5);
  });

  test('allocation drift reports basis-point gaps between target and actual',
      () {
    final now = DateTime(2025, 1, 1);
    final assets = [
      WealthAsset(
          id: 'a',
          name: 'A',
          kind: AssetKind.investment,
          valueUgx: 60,
          valuedAt: now),
      WealthAsset(
          id: 'b',
          name: 'B',
          kind: AssetKind.savings,
          valueUgx: 40,
          valuedAt: now),
    ];
    final drifts = allocationDrift(assets, {'a': 5000, 'b': 5000});
    expect(drifts.length, 2);
    expect(drifts.firstWhere((x) => x.assetId == 'a').actualBps, 6000);
    expect(drifts.firstWhere((x) => x.assetId == 'a').driftBps, 1000);
    expect(drifts.firstWhere((x) => x.assetId == 'b').driftBps, -1000);
  });

  test('dueSchedules only includes active schedules with a passed next fire',
      () {
    final now = DateTime(2025, 1, 15);
    final schedules = [
      ScheduledContribution(
          id: '1',
          name: 'Due',
          amountUgx: 100,
          frequency: ContributionFrequency.monthly,
          nextFire: DateTime(2025, 1, 10)),
      ScheduledContribution(
          id: '2',
          name: 'Future',
          amountUgx: 100,
          frequency: ContributionFrequency.monthly,
          nextFire: DateTime(2025, 2, 10)),
      ScheduledContribution(
          id: '3',
          name: 'Paused',
          amountUgx: 100,
          frequency: ContributionFrequency.monthly,
          nextFire: DateTime(2025, 1, 10),
          active: false),
    ];
    final due = dueSchedules(schedules, now);
    expect(due.length, 1);
    expect(due.single.id, '1');
  });

  test('assetReturns needs at least two valuations', () {
    final asset = WealthAsset(
        id: 'x',
        name: 'Fund',
        kind: AssetKind.investment,
        valueUgx: 1100,
        valuedAt: DateTime(2025, 1, 1));
    final one = [
      ValuationRecord(
          id: 'v1',
          assetId: 'x',
          fullValueUgx: 1000,
          asOf: DateTime(2024, 1, 1),
          source: 'own'),
    ];
    expect(assetReturns(asset, one, const [], DateTime(2025, 1, 1)).hasAny,
        isFalse);
  });
}
