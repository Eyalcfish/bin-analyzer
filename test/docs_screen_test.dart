import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bin_analyzer/models/cpu_capability.dart';
import 'package:bin_analyzer/screens/docs_screen.dart';
import 'package:bin_analyzer/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    const jsonSpec = '''
{
  "version": "1.0",
  "instructions": [
    {
      "id": "ui_test_vaddps",
      "mnemonic": "vaddps",
      "operands": "zmm1, zmm2, zmm3/m512",
      "arch": "amd64",
      "isa_extension": "AVX512F",
      "category": "Vector / SIMD",
      "opcode_encoding": "EVEX.512.66.0F.W0 58 /r",
      "opcode_prefix": "EVEX (4-byte prefix: 0x62)",
      "summary": "Add Packed Single-Precision Floating-Point Values (512-bit)",
      "description": "Performs element-wise addition of 16 single-precision floating-point numbers.",
      "affected_flags": "None",
      "vector_length": "512 bits (16 x float32)",
      "source_db": "Intel Spec"
    },
    {
      "id": "ui_test_csel",
      "mnemonic": "csel",
      "operands": "xd, xn, xm, cond",
      "arch": "arm64",
      "isa_extension": "Base",
      "category": "Control Flow",
      "opcode_encoding": "0x9a800000",
      "opcode_prefix": "Fixed 32-bit",
      "summary": "Conditional Select",
      "description": "Selects register value based on condition code.",
      "affected_flags": "None",
      "vector_length": "Scalar 64-bit",
      "source_db": "ARM A64 Spec"
    }
  ]
}
''';
    await DatabaseService.instance.importInstructionsFromJson(jsonSpec, clearFirst: true);
  });

  testWidgets('DocsScreen renders search bar, filters, cards, and detail modal', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: DocsScreen(),
      ),
    );

    // Wait for real-world SQLite async queries to complete
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pump();

    // Verify screen title and action buttons
    expect(find.text('Hardware ISA & Opcode Documentation'), findsOneWidget);
    expect(find.text('Import JSON File'), findsOneWidget);

    // Verify instructions rendered
    expect(find.text('vaddps'), findsOneWidget);
    expect(find.text('csel'), findsOneWidget);

    // Click on instruction card to open detail modal
    await tester.tap(find.text('vaddps'));
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();

    // Verify detail dialog is rendered
    expect(find.text('MACHINE OPCODES & BYTE ENCODING'), findsOneWidget);
    expect(find.text('EVEX.512.66.0F.W0 58 /r'), findsOneWidget);
    expect(find.text('SYNTAX & OPERANDS'), findsOneWidget);

    // Close detail dialog
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();

    // Test Search Filter
    await tester.enterText(find.byType(TextField).first, 'csel');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('csel'), findsOneWidget);
    expect(find.text('vaddps'), findsNothing);
  });

  testWidgets('DocsScreen opens with initialArch and initialIsa filters pre-applied', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: DocsScreen(
          initialArch: TargetArch.amd64,
          initialIsa: 'AVX512F',
        ),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pump();

    // Verify AVX512F instructions match and other arch instructions are filtered out
    expect(find.text('vaddps'), findsOneWidget);
    expect(find.text('csel'), findsNothing);
  });
}
