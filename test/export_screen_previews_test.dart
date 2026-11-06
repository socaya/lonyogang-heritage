import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lonyogang_heritage/core/design.dart';
import 'package:lonyogang_heritage/data/portfolio_store.dart';
import 'package:lonyogang_heritage/domain/models.dart';
import 'package:lonyogang_heritage/presentation/analysis_screens.dart';
import 'package:lonyogang_heritage/presentation/legacy_screens.dart';
import 'package:lonyogang_heritage/presentation/onboarding_screens.dart';
import 'package:lonyogang_heritage/presentation/security_screens.dart';
import 'package:lonyogang_heritage/presentation/wealth_screens.dart';

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
    final flutterRoot=Platform.environment['FLUTTER_ROOT'];
    expect(flutterRoot,isNotNull,reason:'Flutter SDK path required for screenshot fonts');
    final font=File('$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf');
    expect(font.existsSync(),isTrue,reason:'Roboto font not found in Flutter SDK');
    final iconFont=File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    expect(iconFont.existsSync(),isTrue,reason:'Flutter Material icon font is unavailable');
    await tester.runAsync(() async {
      final robotoBytes=font.readAsBytesSync();
      final iconsBytes=iconFont.readAsBytesSync();
      final robotoLoader=FontLoader('Roboto')
        ..addFont(Future<ByteData>.value(ByteData.sublistView(robotoBytes)));
      final iconLoader=FontLoader('MaterialIcons')
        ..addFont(Future<ByteData>.value(ByteData.sublistView(iconsBytes)));
      await robotoLoader.load();
      await iconLoader.load();
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
    const draft=CreateAccountDraft(
      fullName:'Example Owner',email:'owner@example.com',phone:'+256 700 123 456');
    final pages=<(String,Widget)>[
      ('01-create-account-step-1',const CreateAccountStep1Screen()),
      ('02-create-account-step-2',const CreateAccountStep2Screen(draft:draft)),
      // OTP verification intentionally omitted from the pixel export: its
      // periodic resend-cooldown timer prevents tester.pumpAndSettle from
      // resolving. The screen is covered by the onboarding widget tests.
      ('04-recover-account',const RecoverAccountScreen()),
      ('05-portfolio-setup',PortfolioSetupScreen(store:store)),
      ('06-not-found',const NotFoundScreen(attemptedTarget:'/legacy-record')),
      ('07-unlock-screen',UnlockScreen(store:store)),
      ('08-encryption-setup',EncryptionSetupScreen(store:store)),
      ('09-allocation',AllocationScreen(store:store)),
      ('10-fx-rates',FxRatesScreen(store:store)),
      ('11-scheduled-contributions',ScheduledContributionsScreen(store:store)),
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
        MaterialApp(theme:LG.theme.copyWith(textTheme:LG.theme.textTheme.apply(fontFamily:'Roboto'),
          primaryTextTheme:LG.theme.primaryTextTheme.apply(fontFamily:'Roboto')),
          debugShowCheckedModeBanner:false,home:page.$2)));
      await tester.pumpAndSettle();
      final boundary=tester.renderObject<RenderRepaintBoundary>(find.byKey(repaintKey));
      await tester.runAsync(()async{
        final image=await boundary.toImage(pixelRatio:3);
        try{
          final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
          expect(bytes,isNotNull);
          final destination='${dir.path}/${page.$1}.png';
          await File(destination).writeAsBytes(bytes!.buffer.asUint8List());
        }finally{image.dispose();}
      });
    }
    expect(dir.listSync().whereType<File>().length,pages.length);
  },timeout:const Timeout(Duration(minutes:8)),tags:'visual-export');
}
