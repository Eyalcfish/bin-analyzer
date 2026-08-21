import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:bin_analyzer/providers/executable_provider.dart';
import 'package:bin_analyzer/providers/explorer_provider.dart';
import 'package:bin_analyzer/providers/lab_provider.dart';
import 'package:bin_analyzer/screens/lab_screen.dart';

void main() {
  testWidgets('LabScreen renders top toolbar, editor, register setup, and tabs', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ExplorerProvider()),
          ChangeNotifierProvider(create: (_) => ExecutableProvider()),
          ChangeNotifierProvider(create: (_) => LabProvider()),
        ],
        child: const MaterialApp(
          home: LabScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Mode Switcher
    expect(find.text('BinAnalyzer'), findsOneWidget);
    expect(find.text('The Lab (Workbench)'), findsOneWidget);
    expect(find.text('Run & Capture Registers'), findsAtLeastNWidgets(1));
    expect(find.text('Benchmark'), findsOneWidget);

    // Verify Editor Header & Initial Register Setup
    expect(find.text('Snippet Editor (Modify Instructions)'), findsOneWidget);
    expect(find.text('Initial Register Setup (Inputs)'), findsOneWidget);

    // Verify Tabs
    expect(find.text('End Register State (Verification)'), findsOneWidget);
    expect(find.text('Benchmarking & Timing'), findsOneWidget);
    expect(find.text('SIMD / Vector Registers'), findsOneWidget);
  });
}
