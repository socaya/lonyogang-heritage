import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lonyogang_heritage/core/theme.dart';
import 'package:lonyogang_heritage/ui/components.dart';

void main() {
  testWidgets('primary action is functional and uses flat UI', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      theme: LG.light,
      home: Scaffold(body: LgAction('Continue', onPressed: () { tapped = true; })),
    ));
    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    expect(tapped, true);
  });
}
