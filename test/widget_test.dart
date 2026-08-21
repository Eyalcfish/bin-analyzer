import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bin_analyzer/main.dart';

void main() {
  testWidgets('BinAnalyzerApp smoke test & UI rendering', (WidgetTester tester) async {
    // Set desktop window resolution for test environment
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
  });
}
