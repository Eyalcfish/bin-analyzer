import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bin_analyzer/main.dart';

void main() {
  testWidgets('BinAnalyzerApp smoke test & UI rendering with mouse hit testing', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const BinAnalyzerApp());
    await tester.pumpAndSettle();

    // Verify main components are present
    expect(find.text('Snippets DB'), findsOneWidget);
    expect(find.text('Assembly (.s)'), findsOneWidget);
    expect(find.text('Machine Code & Opcodes'), findsOneWidget);
    expect(find.text('Side-by-Side Comparison'), findsOneWidget);
    expect(find.text('Compile ASM'), findsOneWidget);
    expect(find.text('Build Binary...'), findsOneWidget);

    // Compile code
    await tester.tap(find.text('Compile ASM'), warnIfMissed: false);
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // Move pointer over Assembly pane to test hit-testing
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(700, 300));
    await gesture.moveTo(const Offset(800, 400));
    await tester.pump();

    // Switch to Machine Code tab
    await tester.tap(find.text('Machine Code & Opcodes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.moveTo(const Offset(750, 350));
    await tester.pump();

    // Switch to Side-by-Side Comparison tab
    await tester.tap(find.text('Side-by-Side Comparison'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.moveTo(const Offset(750, 450));
    await tester.pump();

    // Open CPU Capabilities Dialog
    final cpuFeaturesButton = find.textContaining('CPU Features');
    expect(cpuFeaturesButton, findsOneWidget);
    await tester.tap(cpuFeaturesButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify CPU Capabilities dialog builds cleanly without assertions
    expect(find.textContaining('CPU Capabilities & ISA Extensions'), findsOneWidget);
    expect(find.text('AVX-512 Foundation (F)'), findsOneWidget);

    // Close Dialog
    await tester.tap(find.text('Apply & Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Open Snippets DB Drawer
    await tester.tap(find.text('Snippets DB'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify Drawer builds cleanly without assertions
    expect(find.text('C Snippet Database'), findsOneWidget);
  });
}
