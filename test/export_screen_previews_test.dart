import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lonyogang_heritage/core/design.dart';
import 'package:lonyogang_heritage/data/portfolio_store.dart';
import 'package:lonyogang_heritage/domain/models.dart';
import 'package:lonyogang_heritage/presentation/wealth_screens.dart';
import 'package:lonyogang_heritage/presentation/legacy_screens.dart';

/// Widget images at 360x800 logical points and 3x output = 1080x2400 PNG.
/// Only fictional records are used; not screenshots of a connected account.
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  testWidgets('Render extended screens for visual acceptance',(tester)async{
    tester.view.physicalSize=const Size(1080,2400);
    tester.view.devicePixelRatio=3;
    addTearDown((){
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store=PortfolioStore();await store.loadDemo();
    await store.upsertBeneficiary(const BeneficiaryRecord(
      id:'demo-beneficiary',name:'Example Beneficiary',relationship:'Family',intendedShareBps:5000));
    await store.upsertDocument(DocumentRecord(id:'demo-document',title:'Example insurance policy',
      category:'Insurance',expiresAt:DateTime.now().add(const Duration(days:40))));
    await store.addReminder(ReminderRecord(id:'demo-reminder',
      title:'Review sample valuation',dueAt:DateTime.now().add(const Duration(days:10))));
    await store.postEvent(LedgerEvent(id:'demo-rent',description:'Sample rental receipt',
      kind:EventKind.rent,amountUgx:2500000,assetId:'property-rental',occurredAt:DateTime.now()));
    await store.postEvent(LedgerEvent(id:'demo-cost',description:'Sample property maintenance',
      kind:EventKind.expense,amountUgx:400000,assetId:'property-rental',occurredAt:DateTime.now()));
    final sample=store.state.assets.firstWhere((a)=>a.id=='property-rental');
    final pages=<(String,Widget)>[
      ('20-financial-position',WealthStatementScreen(store:store)),
      ('21-financial-holdings',InvestmentOverviewScreen(store:store)),
      ('22-portfolio-search',PortfolioSearchScreen(store:store)),
      ('23-cash-flow',CashFlowScreen(store:store)),
      ('24-rental-income',RentalIncomeScreen(store:store)),
      ('25-valuation-history',ValuationHistoryScreen(store:store,asset:sample)),
      ('26-new-valuation',ValuationForm(store:store,asset:sample)),
      ('27-document-index',DocumentsScreen(store:store)),
      ('28-new-document',DocumentFormScreen(store:store)),
      ('29-legacy-planning',BeneficiariesScreen(store:store)),
      ('30-new-beneficiary',BeneficiaryFormScreen(store:store)),
      ('31-notification-center',NotificationsCenterScreen(store:store)),
      ('32-notification-preferences',NotificationPreferencesScreen(store:store)),
      ('33-profile',ProfileScreen(store:store)),
      ('34-security-center',SecurityCenterScreen(store:store)),
      ('35-subscription',const SubscriptionScreen()),
      ('36-archived-records',ArchivedRecordsScreen(store:store)),
      ('37-help-center',const HelpCenterScreen()),
      ('38-about',const AboutScreen()),
    ];
    final dir=Directory('build/ui-previews');
    if(!dir.existsSync())dir.createSync(recursive:true);
    for(final page in pages){
      final repaintKey=GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key:repaintKey,child:
        MaterialApp(theme:LG.theme,debugShowCheckedModeBanner:false,home:page.$2)));
      await tester.pumpAndSettle();
      final boundary=tester.renderObject<RenderRepaintBoundary>(find.byKey(repaintKey));
      final image=await boundary.toImage(pixelRatio:3);
      try{
        final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
        expect(bytes,isNotNull);
        final destination=dir.path+'/'+page.$1+'.png';
        await File(destination).writeAsBytes(bytes!.buffer.asUint8List());
      }finally{image.dispose();}
    }
    expect(dir.listSync().whereType<File>().length,pages.length);
  },timeout:const Timeout(Duration(minutes:8)));
}
