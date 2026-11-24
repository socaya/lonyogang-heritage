import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lonyogang_heritage/data/portfolio_store.dart';
import 'package:lonyogang_heritage/domain/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Asset CRUD is saved and restored after a fresh repository load', () async {
    final first = PortfolioStore();
    await first.load();
    await first.setOwner('A test owner');
    final asset = WealthAsset(id:'test-1',name:'Land',kind:AssetKind.property,
      valueUgx:100000000,ownershipBps:7000,valuedAt:DateTime(2026,11,1));
    await first.upsertAsset(asset);
    expect(first.totals.netWorth,70000000);
    final second = PortfolioStore();
    await second.load();
    expect(second.state.ownerName,'A test owner');
    expect(second.state.assets.single.attributableUgx,70000000);
    await second.archiveAsset(second.state.assets.single);
    expect(second.totals.netWorth,0);
  });

  test('Posted entries retain history when reversed', () async {
    final store = PortfolioStore();
    await store.load();
    final event = LedgerEvent(id:'income-1',description:'Dividend',kind:EventKind.dividend,
      amountUgx:5000,occurredAt:DateTime(2026,11,1));
    await store.postEvent(event);
    await store.reverseEvent(event);
    expect(store.state.events.length,2);
    expect(store.state.events.last.reversalOf,'income-1');
    await expectLater(store.reverseEvent(event),throwsArgumentError);
  });

  test('Imported invalid amounts are rejected without changing existing data', () async {
    final store = PortfolioStore();
    await store.load();
    await store.setOwner('Original');
    final raw = '{"schemaVersion":1,"ownerName":"Overwritten","onboardingDone":true,'
      '"assets":[{"id":"a","name":"Bad","kind":"property","valueUgx":-100,'
      '"valuedAt":"2026-01-01"}]}';
    await expectLater(store.importJson(raw),throwsFormatException);
    expect(store.state.ownerName,'Original');
  });

  test('SRS demonstration portfolio is explicitly opt-in',()async {
    final store=PortfolioStore();
    await store.load();
    expect(store.state.assets,isEmpty);
    await store.loadDemo();
    expect(store.totals.grossAssets,390000000);
    expect(store.totals.netWorth,320000000);
  });
  test('Liability principal, balance date, repayment date and archive persist', () async {
    final store = PortfolioStore();
    await store.load();
    final debt = Liability(id: 'debt-1', name: 'Loan', category: 'Mortgage',
      lender: 'Bank', accountNumber: 'REF-01', outstandingUgx: 7000000,
      principalUgx: 10000000, asOf: DateTime(2026, 10, 1),
      dueAt: DateTime(2027, 10, 1), notes: 'Statement');
    await store.upsertLiability(debt);
    await store.archiveLiability(debt);
    final reloaded = PortfolioStore();
    await reloaded.load();
    final actual = reloaded.state.liabilities.single;
    expect(actual.principalUgx, 10000000);
    expect(actual.outstandingUgx, 7000000);
    expect(actual.asOf, debt.asOf);
    expect(actual.dueAt, debt.dueAt);
    expect(actual.accountNumber, 'REF-01');
    expect(actual.archived, isTrue);
    expect(reloaded.totals.liabilities, 0);
  });
}
