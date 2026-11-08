import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lonyogang_heritage/core/design.dart';
import 'package:lonyogang_heritage/data/portfolio_store.dart';
import 'package:lonyogang_heritage/presentation/components.dart';
import 'package:lonyogang_heritage/presentation/onboarding_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpPhone(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(theme: LG.theme, home: child));
    await tester.pumpAndSettle();
  }

  group('Input plausibility helpers', () {
    test('isLikelyEmail rejects obvious junk', () {
      expect(isLikelyEmail('user@example.com'), isTrue);
      expect(isLikelyEmail('not an email'), isFalse);
      expect(isLikelyEmail('@example.com'), isFalse);
      expect(isLikelyEmail('user@local'), isFalse);
    });
    test('isLikelyName demands at least two visible characters', () {
      expect(isLikelyName('Jo'), isTrue);
      expect(isLikelyName(' x'), isFalse);
      expect(isLikelyName('  '), isFalse);
    });
    test('isLikelyPhone counts total digits across country code and body', () {
      expect(isLikelyPhone('+256 700 123 456'), isTrue);
      expect(isLikelyPhone('+256 1'), isFalse);
      expect(isLikelyPhone('+1 (650) 555-0100'), isTrue);
    });
  });

  testWidgets('Create account step 1 renders the canonical flat layout',
      (tester) async {
    await pumpPhone(tester, const CreateAccountStep1Screen());
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Mobile number'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    // Visible gated disclaimer; no claim of real account creation.
    expect(find.textContaining('No real account'), findsOneWidget);
  });

  testWidgets('Create account step 1 refuses to continue without terms accepted',
      (tester) async {
    await pumpPhone(tester, const CreateAccountStep1Screen());
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Jane Doe');
    await tester.enterText(fields.at(1), 'jane@example.com');
    await tester.enterText(fields.at(2), '700123456');
    // Terms NOT accepted
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Accept the terms'), findsOneWidget);
  });

  testWidgets('Not-found screen offers a recovery path', (tester) async {
    await pumpPhone(tester,
        const NotFoundScreen(attemptedTarget: '/does-not-exist'));
    expect(find.textContaining("couldn't find"), findsOneWidget);
    expect(find.text('Return home'), findsOneWidget);
  });

  testWidgets('Portfolio setup walks three steps and persists owner name',
      (tester) async {
    final store = PortfolioStore();
    await store.load();
    await pumpPhone(tester, PortfolioSetupScreen(store: store));
    expect(find.text('What should we call your portfolio?'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Family');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('What do you plan to track?'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Ready to begin'), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
    await tester.tap(find.text('Create portfolio'));
    await tester.pumpAndSettle();
    expect(store.state.ownerName, 'Family');
    expect(store.state.onboardingDone, isTrue);
  });
}
