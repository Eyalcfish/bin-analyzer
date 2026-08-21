import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:bin_analyzer/providers/executable_provider.dart';
import 'package:bin_analyzer/screens/executable_screen.dart';

void main() {
  testWidgets('ExecutableScreen renders top toolbar, overview card, sections table, and disassembly', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final provider = ExecutableProvider();
    await provider.loadExecutableBytes(
      Uint8List.fromList([0x90, 0x90, 0xC3]),
      fileName: 'test_sample.bin',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ExecutableProvider>.value(value: provider),
        ],
        child: const MaterialApp(
          home: ExecutableScreen(),
        ),
      ),
    );

    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // Verify top toolbar components
    expect(find.text('BinAnalyzer'), findsOneWidget);
    expect(find.text('C Source Compiler'), findsOneWidget);
    expect(find.text('Executable Analyzer'), findsOneWidget);
    expect(find.text('Open Binary File...'), findsOneWidget);
    expect(find.text('Compile from C...'), findsOneWidget);

    // Verify tabs
    expect(find.text('Sections & Segments'), findsOneWidget);
    expect(find.text('Functions & Symbols'), findsOneWidget);
    expect(find.text('Disassembly'), findsOneWidget);
    expect(find.text('Machine Code (Hex)'), findsOneWidget);
  });
}
