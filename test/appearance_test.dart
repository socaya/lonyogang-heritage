import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/core/appearance.dart';
import '../lib/core/design.dart';
import '../lib/presentation/appearance_screen.dart';
import '../lib/presentation/components.dart';
import '../lib/presentation/widgets.dart';

double contrast(Color a,Color b){
  final x=a.computeLuminance(),y=b.computeLuminance();
  return ((x>y?x:y)+.05)/((x>y?y:x)+.05);
}

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(()=>SharedPreferences.setMockInitialValues({}));
  test('appearance persists across controller instances',() async{
    final first=AppearanceController();
    await first.load();
    expect(first.mode,ThemeMode.light);
    for(final mode in ThemeMode.values){
      await first.setMode(mode);
      final restored=AppearanceController();
      await restored.load();
      expect(restored.mode,mode);
      restored.dispose();
    }
    first.dispose();
  });
  test('unknown stored appearance falls back to light',()async{
    SharedPreferences.setMockInitialValues({AppearanceController.preferenceKey:'invalid'});
    final controller=AppearanceController();
    await controller.load();
    expect(controller.mode,ThemeMode.light);
    controller.dispose();
  });
  test('primary and secondary text satisfy normal text contrast',(){
    for(final pair in [(LG.navy,LG.canvas),(LG.navy,LG.white),(LG.muted,LG.white),(LG.muted,LG.canvas),(LG.darkInk,LG.darkCanvas),(LG.darkInk,LG.darkSurface),(LG.darkMuted,LG.darkSurface),(LG.darkMuted,LG.darkCanvas),(LG.navy,LG.darkGold),(LG.darkNegative,LG.darkSurface)]){
      expect(contrast(pair.$1,pair.$2),greaterThanOrEqualTo(4.5),reason:'Contrast for ${pair.$1} on ${pair.$2}');
    }
  });
  testWidgets('appearance selection updates theme and survives reload',(tester)async{
    final controller=AppearanceController();
    await controller.load();
    await tester.pumpWidget(AppearanceScope(controller:controller,child:ListenableBuilder(listenable:controller,builder:(context,_)=>MaterialApp(
      theme:LG.theme,darkTheme:LG.darkTheme,themeMode:controller.mode,home:const AppearanceScreen(),
    ))));
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(controller.mode,ThemeMode.dark);
    final context=tester.element(find.byType(AppearanceScreen));
    expect(Theme.of(context).brightness,Brightness.dark);
    expect(tester.takeException(),isNull);
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(AppearanceScreen))).brightness,Brightness.light);
    final restored=AppearanceController();
    await restored.load();
    expect(restored.mode,ThemeMode.light);
    await tester.pumpWidget(const SizedBox.shrink());
    restored.dispose();
    controller.dispose();
  });
  for(final mode in [ThemeMode.light,ThemeMode.dark]){
    testWidgets('shared surfaces render in ${mode.name}',(tester)async{
      await tester.pumpWidget(MaterialApp(theme:LG.theme,darkTheme:LG.darkTheme,themeMode:mode,home:AppPage(children:[
        const PageHeading('Financial position',subtitle:'Recorded values'),
        const SoftCard(child:InfoLabel(label:'Net worth',value:'UGX 320,000,000')),
        LGFilterChip(label:'All assets',selected:true,onTap:(){}),
        const SecurityNotice(title:'Privacy',message:'Local data protection'),
      ])));
      expect(tester.takeException(),isNull);
      expect(find.text('UGX 320,000,000'),findsOneWidget);
    });
  }
}
