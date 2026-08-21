import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bin_analyzer/main.dart';

void main() {
  testWidgets('BinAnalyzerApp smoke test & UI rendering', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const BinAnalyzerApp());
    await tester.pumpAndSettle();

    // Verify main components are present
    expect(find.text('Snippets DB'), findsOneWidget);
    expect(find.text('Assembly (.s)'), findsOneWidget);
    expect(find.text('Machine Code & Opcodes'), findsOneWidget);
    expect(find.text('Side-by-Side Comparison'), findsOneWidget);
    expect(find.text('Compile'), findsOneWidget);

    // Open CPU Capabilities Dialog
    final cpuFeaturesButton = find.textContaining('CPU Features');
    expect(cpuFeaturesButton, findsOneWidget);
    await tester.tap(cpuFeaturesButton);
    await tester.pumpAndSettle();

    // Verify CPU Capabilities dialog builds cleanly without assertions
    expect(find.textContaining('CPU Capabilities & ISA Extensions'), findsOneWidget);
    expect(find.text('AVX-512 Foundation (F)'), findsOneWidget);

    // Close Dialog
    await tester.tap(find.text('Apply & Close'));
    await tester.pumpAndSettle();

    // Open Snippets DB Drawer
    await tester.tap(find.text('Snippets DB'));
    await tester.pumpAndSettle();

    // Verify Drawer builds cleanly without assertions
    expect(find.text('C Snippet Database'), findsOneWidget);
  });
}
