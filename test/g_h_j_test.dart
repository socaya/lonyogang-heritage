import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lonyogang_heritage/core/design.dart';
import 'package:lonyogang_heritage/data/portfolio_store.dart';
import 'package:lonyogang_heritage/domain/models.dart';
import 'package:lonyogang_heritage/presentation/detail_screens.dart';
import 'package:lonyogang_heritage/presentation/forms.dart';
import 'package:lonyogang_heritage/presentation/legacy_screens.dart';
import 'package:lonyogang_heritage/presentation/onboarding_screens.dart';
import 'package:lonyogang_heritage/presentation/screens.dart';
import 'package:lonyogang_heritage/presentation/widgets.dart';
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

  group('G02 wealth goal editing', () {
    testWidgets('Edit form pre-populates fields and rejects saved > target',
        (tester) async {
      final store = PortfolioStore();
      await store.load();
      const existing = WealthGoal(
          id: 'g1', name: 'Land purchase', targetUgx: 10_000_000, savedUgx: 2_000_000);
      await store.addGoal(existing);
      await pumpPhone(tester, GoalForm(store: store, existing: existing));
      expect(find.text('Edit goal'), findsOneWidget);
      // Set saved > target and expect rejection.
      final moneyFields = find.byType(TextFormField);
      await tester.enterText(moneyFields.at(2), '20000000');
      await tester.tap(find.text('Save goal'));
      await tester.pumpAndSettle();
      expect(find.textContaining('cannot exceed the target'), findsOneWidget);
      expect(store.state.goals.single.savedUgx, 2_000_000);
    });
  });

  group('G09 document detail', () {
    testWidgets('Renders metadata and offers an attach entry point',
        (tester) async {
      final store = PortfolioStore();
      await store.load();
      const doc = DocumentRecord(
          id: 'd1',
          title: 'Rental lease',
          category: 'Property',
          notes: 'Original kept in safe');
      await store.upsertDocument(doc);
      await pumpPhone(
          tester, DocumentDetailScreen(store: store, document: doc));
      expect(find.text('Rental lease'), findsAtLeast(1));
      expect(find.text('Original kept in safe'), findsOneWidget);
      expect(find.text('Attach encrypted file'), findsOneWidget);
      expect(find.text('Edit metadata'), findsOneWidget);
    });
  });

  group('H02 notification detail route', () {
    test('buildLocalAlerts produces an entry for overdue reminders', () {
      final state = PortfolioState(reminders: [
        ReminderRecord(
            id: 'r1',
            title: 'Pay rates',
            dueAt: DateTime(2020, 1, 1))
      ], notificationOptions: const NotificationOptions());
      final alerts = buildLocalAlerts(state, DateTime(2026, 11, 7));
      expect(alerts.length, 1);
      expect(alerts.first.source, LocalAlertSource.reminder);
      expect(alerts.first.urgent, isTrue);
    });

    testWidgets('Notification detail shows the alert source and open CTA',
        (tester) async {
      final store = PortfolioStore();
      await store.load();
      final alert = LocalAlert(
          source: LocalAlertSource.staleValuation,
          sourceId: 'missing-asset',
          title: 'Old asset',
          detail: 'Recorded value is more than 12 months old',
          icon: Icons.update_rounded,
          urgent: false,
          occurrence: DateTime(2024, 1, 1));
      await pumpPhone(tester,
          NotificationDetailScreen(store: store, alert: alert));
      expect(find.text('Old asset'), findsAtLeast(1));
      expect(find.text('Open source record'), findsOneWidget);
      expect(find.text('Stale valuation'), findsAtLeast(1));
    });
  });

  group('J06 stale valuation marker', () {
    testWidgets('AssetTile shows a Stale pill when valued more than a year ago',
        (tester) async {
      final asset = WealthAsset(
          id: 'a',
          name: 'Ancient fund',
          kind: AssetKind.investment,
          valueUgx: 100000,
          valuedAt: DateTime.now().subtract(const Duration(days: 500)));
      await pumpPhone(
          tester,
          Scaffold(
              body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AssetTile(asset: asset, onTap: () {}))));
      expect(find.text('Stale'), findsOneWidget);
    });

    testWidgets('Fresh asset does not show the Stale pill', (tester) async {
      final asset = WealthAsset(
          id: 'b',
          name: 'Fresh fund',
          kind: AssetKind.investment,
          valueUgx: 100000,
          valuedAt: DateTime.now());
      await pumpPhone(
          tester,
          Scaffold(
              body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AssetTile(asset: asset, onTap: () {}))));
      expect(find.text('Stale'), findsNothing);
    });
  });

  group('A06 sign-in prototype', () {
    testWidgets('Sign-in screen is explicitly a design preview',
        (tester) async {
      await pumpPhone(tester, const SignInScreen());
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.textContaining('design preview'), findsAtLeast(1));
      expect(find.text('Use passkey (not available)'), findsOneWidget);
    });
  });

  group('B06 home recent activity', () {
    testWidgets('HomeRecentActivity hides itself when there are no events',
        (tester) async {
      final store = PortfolioStore();
      await store.load();
      await pumpPhone(
          tester, Scaffold(body: HomeRecentActivity(store: store)));
      expect(find.text('Recent activity'), findsNothing);
    });

    testWidgets('HomeRecentActivity lists the most recent non-reversed entry',
        (tester) async {
      final store = PortfolioStore();
      await store.load();
      await store.postEvent(LedgerEvent(
          id: 'e1',
          description: 'SACCO interest',
          kind: EventKind.interest,
          amountUgx: 10000,
          occurredAt: DateTime(2026, 11, 1)));
      await pumpPhone(
          tester, Scaffold(body: HomeRecentActivity(store: store)));
      expect(find.text('Recent activity'), findsOneWidget);
      expect(find.text('SACCO interest'), findsOneWidget);
    });
  });
}

