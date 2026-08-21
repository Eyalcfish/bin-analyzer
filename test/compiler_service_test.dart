import 'package:flutter_test/flutter_test.dart';
import 'package:bin_analyzer/models/cpu_capability.dart';
import 'package:bin_analyzer/services/compiler_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CompilerService Unit & Integration Tests', () {
    final compiler = CompilerService();

    test('Compiles C code to AMD64 Assembly and Machine Code with -O2', () async {
      const code = '''
int add_numbers(int a, int b) {
\treturn a + b;
}
''';

      final result = await compiler.compile(
        sourceCode: code,
        arch: TargetArch.amd64,
        optLevel: OptimizationLevel.O2,
      );

      expect(result.success, isTrue);
      expect(result.rawAssembly.isNotEmpty, isTrue);
      expect(result.filteredAssembly.isNotEmpty, isTrue);
      expect(result.instructions.isNotEmpty, isTrue);
      expect(result.codeSizeBytes, greaterThan(0));
      expect(result.instructionCount, greaterThan(0));

      // Disassembly should contain lea or add and ret
      expect(
        result.instructions.any((i) => i.mnemonic.contains('lea') || i.mnemonic.contains('add')),
        isTrue,
      );
      expect(
        result.instructions.any((i) => i.mnemonic.contains('ret')),
        isTrue,
      );
    });

    test('Compiles with AVX-512 flags and verifies vector instructions', () async {
      const code = '''
void vec_add(float* a, float* b, float* c, int n) {
\tfor (int i = 0; i < n; i++) {
\t\tc[i] = a[i] + b[i];
\t}
}
''';

      final result = await compiler.compile(
        sourceCode: code,
        arch: TargetArch.amd64,
        optLevel: OptimizationLevel.O3,
        cpuFlags: ['-mavx512f', '-mavx512vl'],
      );

      expect(result.success, isTrue);
      expect(result.codeSizeBytes, greaterThan(0));
      // Should contain vaddps or vector op
      expect(
        result.rawDisassembly.contains('vaddps') || result.rawDisassembly.contains('xmm') || result.rawDisassembly.contains('zmm'),
        isTrue,
      );
    });

    test('Compiles ARM64 target', () async {
      const code = '''
int mul_add(int a, int b, int c) {
\treturn a * b + c;
}
''';

      final result = await compiler.compile(
        sourceCode: code,
        arch: TargetArch.arm64,
        optLevel: OptimizationLevel.O2,
      );

      expect(result.success, isTrue);
      expect(result.instructions.isNotEmpty, isTrue);
      expect(result.codeSizeBytes, greaterThan(0));
      // ARM64 should contain madd / ret
      expect(
        result.rawDisassembly.contains('madd') || result.rawDisassembly.contains('ret'),
        isTrue,
      );
    });

    test('Handles compilation syntax error gracefully', () async {
      const invalidCode = '''
int broken( {
\treturn ;
''';

      final result = await compiler.compile(
        sourceCode: invalidCode,
        arch: TargetArch.amd64,
        optLevel: OptimizationLevel.O0,
      );

      expect(result.success, isFalse);
      expect(result.exitCode, isNonZero);
      expect(result.stderr.isNotEmpty, isTrue);
    });
  });
}
