import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:bin_analyzer/models/cpu_capability.dart';
import 'package:bin_analyzer/models/lab_experiment.dart';
import 'package:bin_analyzer/providers/executable_provider.dart';
import 'package:bin_analyzer/providers/explorer_provider.dart';
import 'package:bin_analyzer/providers/lab_provider.dart';
import 'package:bin_analyzer/screens/lab_screen.dart';

void main() {
  group('LabProvider Comparison Mode Unit Tests', () {
    test('Toggles comparison mode and creates baseline snippet if null', () {
      final provider = LabProvider();
      expect(provider.isComparisonMode, isFalse);

      provider.toggleComparisonMode(true);
      expect(provider.isComparisonMode, isTrue);
      expect(provider.baselineSnippet, isNotNull);

      provider.toggleComparisonMode(false);
      expect(provider.isComparisonMode, isFalse);
    });

    test('Swaps Code A and Code B snippets', () {
      final provider = LabProvider();
      provider.setBaselineCode('mov rax, 111');
      provider.setSnippetCode('mov rax, 222');

      provider.swapSnippets();

      expect(provider.baselineSnippet?.code, contains('222'));
      expect(provider.modifiedSnippet.code, contains('111'));
    });

    test('Clones Baseline to Modified and vice versa', () {
      final provider = LabProvider();
      provider.setBaselineCode('mov rax, 999');
      provider.cloneBaselineToModified();
      expect(provider.modifiedSnippet.code, equals('mov rax, 999'));

      provider.setSnippetCode('mov rbx, 888');
      provider.cloneModifiedToBaseline();
      expect(provider.baselineSnippet?.code, equals('mov rbx, 888'));
    });
  });

  testWidgets('LabScreen renders Dual Compare button and toggles dual editor layout', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final labProvider = LabProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ExplorerProvider()),
          ChangeNotifierProvider(create: (_) => ExecutableProvider()),
          ChangeNotifierProvider.value(value: labProvider),
        ],
        child: const MaterialApp(
          home: LabScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial Single Editor mode
    expect(find.text('Dual Compare: OFF'), findsOneWidget);
    expect(find.text('Snippet Editor (Modify Instructions)'), findsOneWidget);

    // Click Dual Compare Button
    await tester.tap(find.text('Dual Compare: OFF'));
    await tester.pumpAndSettle();

    // Verify Dual Comparison Workbench UI
    expect(find.text('Dual Compare: ON'), findsOneWidget);
    expect(find.text('Dual Code Workbench'), findsOneWidget);
    expect(find.text('Code A (Baseline)'), findsOneWidget);
    expect(find.text('Code B (Variant)'), findsOneWidget);
    expect(find.text('Swap A ↔ B'), findsOneWidget);
    expect(find.text('Copy A → B'), findsOneWidget);
  });
}
