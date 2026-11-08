import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lonyogang_heritage/core/design.dart';
import 'package:lonyogang_heritage/data/portfolio_store.dart';
import 'package:lonyogang_heritage/domain/models.dart';
import 'package:lonyogang_heritage/presentation/wealth_screens.dart';
import 'package:lonyogang_heritage/presentation/legacy_screens.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(()=>SharedPreferences.setMockInitialValues({}));

  Future<void> pumpPhone(WidgetTester tester,Widget screen)async{
    tester.view.physicalSize=const Size(1080,2400);
    tester.view.devicePixelRatio = 2;
    addTearDown((){
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(theme:LG.theme,home:screen));
    await tester.pumpAndSettle();
  }

  testWidgets('Financial position shows the owner-adjusted demo net worth',(tester)async{
    final store=PortfolioStore();await store.loadDemo();
    await pumpPhone(tester,WealthStatementScreen(store:store));
    expect(find.text('Financial position'),findsOneWidget);
    expect(find.text('UGX 320,000,000'),findsWidgets);
    expect(find.textContaining('recorded balances'),findsOneWidget);
  });

  testWidgets('Documents screen explains the encrypted-at-rest attachment policy',(tester)async{
    final store=PortfolioStore();await store.load();
    await pumpPhone(tester,DocumentsScreen(store:store));
    expect(find.text('Documents & records'),findsOneWidget);
    expect(find.textContaining('per-file key'),findsOneWidget);
    expect(find.text('No document records'),findsOneWidget);
  });

  testWidgets('Legacy planning is clearly non-binding',(tester)async{
    final store=PortfolioStore();await store.load();
    await pumpPhone(tester,BeneficiariesScreen(store:store));
    expect(find.text('Legacy planning'),findsOneWidget);
    expect(find.textContaining('do not grant access'),findsOneWidget);
  });

  testWidgets('Alert inbox displays the locally sourced overdue items',(tester)async{
    final store=PortfolioStore();await store.load();
    await store.addReminder(ReminderRecord(id:'r1',title:'Renew insurance',
      dueAt:DateTime(2020,1,1)));
    await pumpPhone(tester,NotificationsCenterScreen(store:store));
    expect(find.text('Notifications'),findsOneWidget);
    expect(find.text('Renew insurance'),findsOneWidget);
    expect(find.textContaining('Overdue'),findsOneWidget);
  });

  testWidgets('Billing preview never claims that payment processing is connected',(tester)async{
    await pumpPhone(tester,const SubscriptionScreen());
    expect(find.text('Subscription & billing'),findsOneWidget);
    expect(find.textContaining('Payments are not connected'),findsOneWidget);
    expect(find.text('Not available'),findsOneWidget);
  });
}
