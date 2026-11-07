import 'package:flutter_test/flutter_test.dart';
import 'package:lonyogang_heritage/data/portfolio_store.dart';
import 'package:lonyogang_heritage/domain/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Firing a schedule posts a ledger event and advances the next-fire date',
      () async {
    final store = PortfolioStore();
    await store.load();
    final schedule = ScheduledContribution(
        id: 's1',
        name: 'Monthly SACCO',
        amountUgx: 100000,
        frequency: ContributionFrequency.monthly,
        nextFire: DateTime(2026, 11, 1));
    await store.upsertSchedule(schedule);
    await store.fireSchedule(schedule, at: DateTime(2026, 11, 2));

    expect(store.state.events.single.kind, EventKind.contribution);
    expect(store.state.events.single.amountUgx, 100000);
    final advanced = store.state.scheduled.single;
    expect(advanced.nextFire.isAfter(schedule.nextFire), isTrue);
    expect(advanced.lastFired, isNotNull);
  });

  test('FX rates reject 3-letter codes shorter than 3 characters', () async {
    final store = PortfolioStore();
    await store.load();
    await expectLater(
        store.upsertFxRate(FxRate(
            currency: 'XX', ugxPerUnit: 1, asOf: DateTime(2026, 1, 1))),
        throwsArgumentError);
  });

  test('Target weights cap at 10,000 basis points', () async {
    final store = PortfolioStore();
    await store.load();
    await expectLater(
        store.setTargetWeight('asset', 20000), throwsArgumentError);
    await store.setTargetWeight('asset', 5000);
    expect(store.state.targetWeightsBps['asset'], 5000);
    await store.setTargetWeight('asset', 0);
    expect(store.state.targetWeightsBps.containsKey('asset'), isFalse);
  });

  test('Importing a schema-2 JSON round-trips scheduled contributions', () async {
    final a = PortfolioStore();
    await a.load();
    await a.upsertSchedule(ScheduledContribution(
        id: 's1',
        name: 'Rent',
        amountUgx: 500000,
        frequency: ContributionFrequency.quarterly,
        nextFire: DateTime(2027, 2, 1)));
    final json = a.exportJson();
    final b = PortfolioStore();
    await b.load();
    await b.importJson(json);
    expect(b.state.scheduled.single.name, 'Rent');
    expect(b.state.scheduled.single.frequency,
        ContributionFrequency.quarterly);
  });
}
