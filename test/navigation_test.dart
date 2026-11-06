import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lonyogang_heritage/main.dart';
import 'package:lonyogang_heritage/data/portfolio_store.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(()=>SharedPreferences.setMockInitialValues({}));

  testWidgets('Welcome starts with empty portfolio and offers demo explicitly',(tester)async{
    final store=PortfolioStore();await store.load();
    await tester.pumpWidget(LonyoGangApp(store:store));
    await tester.pumpAndSettle();
    expect(find.text('Create local portfolio'),findsOneWidget);
    expect(find.text('Explore with sample data'),findsOneWidget);
  });

  testWidgets('Dashboard and portfolio tabs render the persisted wealth',(tester)async{
    final store=PortfolioStore();await store.loadDemo();
    await tester.pumpWidget(LonyoGangApp(store:store));
    await tester.pumpAndSettle();
    expect(find.text('TOTAL NET WORTH'),findsOneWidget);
    await tester.tap(find.text('Portfolio').last);
    await tester.pumpAndSettle();
    expect(find.text('Your portfolio'),findsOneWidget);
    expect(find.text('Rental Property'),findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    expect(find.text('Add to your wealth'),findsOneWidget);
    expect(find.text('Investment'),findsOneWidget);
  });
}
