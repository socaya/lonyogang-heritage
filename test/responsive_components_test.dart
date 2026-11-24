import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/presentation/widgets.dart';
import '../lib/presentation/components.dart';

void main() {
  test('responsive page gutter follows approved design breakpoints', () {
    expect(pageGutter(320),16);
    expect(pageGutter(390),20);
    expect(pageGutter(430),24);
    expect(pageInsets(1000).left,104);
  });

  for(final width in [320.0,390.0,430.0,800.0]){
    for(final scale in [1.0,1.3,2.0]){
      testWidgets('shared layout fits width $width at text scale $scale',(tester) async {
        tester.view.physicalSize=Size(width,800);
        tester.view.devicePixelRatio=1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(home:Builder(builder:(context)=>MediaQuery(
          data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(scale)),
          child:AppPage(children:[
            PageHeading('Financial position',subtitle:'Recorded portfolio and liabilities',trailing:TextButton(onPressed:(){},child:const Text('Export report'))),
            const FormFieldBlock(title:'Outstanding principal including recorded adjustments',required:true,child:TextField()),
            const InfoLabel(label:'Ownership-adjusted value',value:'UGX 123,456,789,012'),
            LGFilterChip(label:'All assets',selected:true,onTap:(){}),
          ]),
        ))));
        expect(tester.takeException(),isNull);
        expect(tester.getSize(find.byType(LGFilterChip)).height,greaterThanOrEqualTo(48));
      });
    }
  }
}
