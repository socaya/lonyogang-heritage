import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lonyogang_heritage/core/design.dart';
import 'package:lonyogang_heritage/data/portfolio_store.dart';
import 'package:lonyogang_heritage/domain/finance.dart';
import 'package:lonyogang_heritage/domain/models.dart';
import 'package:lonyogang_heritage/presentation/account_screens.dart';
import 'package:lonyogang_heritage/presentation/analysis_screens.dart';
import 'package:lonyogang_heritage/presentation/detail_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpPhone(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(theme: LG.theme, home: child));
    await tester.pumpAndSettle();
  }

  group('Wealth history (pure domain)', () {
    test('returns empty when fewer than two valuation dates exist', () {
      final a = WealthAsset(
          id: 'a',
          name: 'A',
          kind: AssetKind.investment,
          valueUgx: 1000,
          valuedAt: DateTime(2025, 1, 1));
      expect(wealthHistory([a], const [], const []), isEmpty);
    });

    test('aggregates per-asset valuations into dated net-worth points', () {
      final a = WealthAsset(
          id: 'a',
          name: 'A',
          kind: AssetKind.investment,
          valueUgx: 2000,
          valuedAt: DateTime(2025, 6, 1));
      final v1 = ValuationRecord(
          id: 'v1',
          assetId: 'a',
          fullValueUgx: 1000,
          asOf: DateTime(2024, 1, 1),
          source: 'own');
      final v2 = ValuationRecord(
          id: 'v2',
          assetId: 'a',
          fullValueUgx: 1500,
          asOf: DateTime(2024, 12, 1),
          source: 'own');
      final debts = [
        Liability(
            id: 'd',
            name: 'Loan',
            outstandingUgx: 400,
            asOf: DateTime(2025, 1, 1)),
      ];
      final snapshots = wealthHistory([a], debts, [v1, v2]);
      expect(snapshots.length, 3);
      expect(snapshots.first.at, DateTime(2024, 1, 1));
      expect(snapshots.first.grossAssetsUgx, 1000);
      expect(snapshots.first.netWorthUgx, 600);
      expect(snapshots.last.grossAssetsUgx, 2000);
      expect(snapshots.last.netWorthUgx, 1600);
    });

    test('ignores archived assets and debts', () {
      final a = WealthAsset(
          id: 'a',
          name: 'A',
          kind: AssetKind.investment,
          valueUgx: 2000,
          valuedAt: DateTime(2025, 6, 1),
          archived: true);
      final v1 = ValuationRecord(
          id: 'v1',
          assetId: 'a',
          fullValueUgx: 1000,
          asOf: DateTime(2024, 1, 1),
          source: 'own');
      expect(wealthHistory([a], const [], [v1]), isEmpty);
    });
  });

  testWidgets(
      'Historical trend screen offers an honest empty state when data is sparse',
      (tester) async {
    final store = PortfolioStore();
    await store.load();
    await pumpPhone(tester, HistoricalTrendScreen(store: store));
    expect(find.text('Not enough history yet'), findsOneWidget);
  });

  testWidgets(
      'Transaction detail offers a Reverse action that appends a reversal entry',
      (tester) async {
    final store = PortfolioStore();
    await store.load();
    final event = LedgerEvent(
        id: 'e1',
        description: 'Dividend received',
        kind: EventKind.dividend,
        amountUgx: 1000,
        occurredAt: DateTime(2026, 6, 1));
    await store.postEvent(event);
    await pumpPhone(
        tester, TransactionDetailScreen(store: store, event: event));
    expect(find.text('Dividend received'), findsAtLeast(1));
    // Confirm reverse flow writes a compensating entry.
    await tester.tap(find.text('Reverse this entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Append reversal'));
    await tester.pumpAndSettle();
    expect(store.state.events.length, 2);
    expect(store.state.events.last.kind, EventKind.reversal);
    expect(store.state.events.last.reversalOf, 'e1');
  });

  testWidgets('Data sync status shows local-only state and encryption off',
      (tester) async {
    final store = PortfolioStore();
    await store.load();
    await store.setOwner('Owner');
    await pumpPhone(tester, DataSyncStatusScreen(store: store));
    expect(find.text('Data & sync'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('Not connected'), findsAtLeast(1));
    expect(find.textContaining('cleartext'), findsOneWidget);
  });

  testWidgets('Local reset wipes state and leaves the vault disabled',
      (tester) async {
    final store = PortfolioStore();
    await store.load();
    await store.loadDemo();
    expect(store.state.assets, isNotEmpty);
    await store.resetLocal();
    expect(store.state.assets, isEmpty);
    expect(store.state.liabilities, isEmpty);
    expect(store.vault.hasPassphrase, isFalse);
    expect(store.state.ownerName, '');
    expect(store.isDemo, isFalse);
  });
}
