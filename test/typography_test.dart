import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/design.dart';
import '../lib/presentation/widgets.dart';
import '../lib/presentation/components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled typefaces and licences are present', () async {
    for(final family in ['Manrope','Inter']) {
      final font=await rootBundle.load('assets/fonts/$family-Variable.ttf');
      expect(font.lengthInBytes,greaterThan(10000));
      final license=await rootBundle.loadString('assets/fonts/$family-OFL.txt');
      expect(license,contains('SIL OPEN FONT LICENSE'));
    }
  });

  test('both themes use the approved typography hierarchy', () {
    for(final theme in [LG.theme,LG.darkTheme]) {
      final text=theme.textTheme;
      expect(text.headlineMedium?.fontFamily,LG.displayFont);
      expect(text.headlineMedium?.fontSize,28);
      expect(text.titleMedium?.fontWeight,FontWeight.w600);
      expect(text.bodyMedium?.fontFamily,LG.uiFont);
      expect(text.bodyMedium?.fontSize,15);
      expect(text.labelLarge?.fontWeight,FontWeight.w600);
      expect(text.displaySmall?.fontFeatures,LG.financialFeatures);
    }
  });

  for(final width in [320.0,390.0,430.0]) {
    for(final scale in [1.0,1.3,2.0]) {
      testWidgets('financial values remain visible at $width dp and $scale text scale',(tester) async {
        tester.view.physicalSize=Size(width,800);
        tester.view.devicePixelRatio=1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(theme:LG.theme,home:Builder(builder:(context)=>MediaQuery(
          data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(scale)),
          child:AppPage(children:[
            const PageHeading('Financial position'),
            SoftCard(color:LG.navy,child:Text('UGX 320,000,000',style:LG.financialStyle(context,color:Colors.white))),
            const InfoLabel(label:'Outstanding principal',value:'UGX 123,456,789,012'),
          ]),
        ))));
        expect(tester.takeException(),isNull);
        expect(find.text('UGX 320,000,000'),findsOneWidget);
        final text=tester.widget<Text>(find.text('UGX 320,000,000'));
        expect(text.style?.fontFamily,LG.displayFont);
        expect(text.style?.fontFeatures,LG.financialFeatures);
        expect(text.maxLines,isNull);
      });
    }
  }
}
