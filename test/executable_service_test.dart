import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bin_analyzer/models/cpu_capability.dart';
import 'package:bin_analyzer/models/executable_binary.dart';
import 'package:bin_analyzer/services/compiler_service.dart';
import 'package:bin_analyzer/services/executable_service.dart';

void main() {
  group('ExecutableService & Binary Compiler Tests', () {
    final compilerService = CompilerService();
    final execService = ExecutableService.instance;

    const sampleC = '''
int multiply_add(int a, int b, int c) {
    return a * b + c;
}

int main() {
    int res = multiply_add(3, 4, 5);
    return res;
}
''';

    test('Compiles C code to Windows PE (.exe) binary and parses PE headers', () async {
      final compResult = await compilerService.compileToBinaryFile(
        sourceCode: sampleC,
        format: BinaryOutputFormat.peExe,
        arch: TargetArch.amd64,
        optLevel: OptimizationLevel.O2,
      );

      expect(compResult.success, isTrue);
      expect(compResult.fileSizeBytes, greaterThan(0));

      final binary = await execService.analyzeExecutableFile(compResult.outputPath);
      expect(binary.header.format, equals(ExecutableFormat.pe));
      expect(binary.header.arch, equals(TargetArch.amd64));
      expect(binary.header.bitness, equals(64));
      expect(binary.sections.isNotEmpty, isTrue);
      expect(binary.sections.any((s) => s.name.contains('text')), isTrue);
      expect(binary.instructions.isNotEmpty, isTrue);
    });

    test('Compiles C code to Linux ELF (.elf) binary and parses ELF headers', () async {
      final compResult = await compilerService.compileToBinaryFile(
        sourceCode: sampleC,
        format: BinaryOutputFormat.elfBinary,
        arch: TargetArch.amd64,
        optLevel: OptimizationLevel.O2,
      );

      expect(compResult.success, isTrue);
      expect(compResult.fileSizeBytes, greaterThan(0));

      final binary = await execService.analyzeExecutableFile(compResult.outputPath);
      expect(binary.header.format, equals(ExecutableFormat.elf));
      expect(binary.header.arch, equals(TargetArch.amd64));
      expect(binary.sections.isNotEmpty, isTrue);
      expect(binary.sections.any((s) => s.name.contains('.text') || s.name.contains('sec_')), isTrue);
    });

    test('Compiles C code to macOS Mach-O (.macho) binary and parses Mach-O headers', () async {
      final compResult = await compilerService.compileToBinaryFile(
        sourceCode: sampleC,
        format: BinaryOutputFormat.machOBinary,
        arch: TargetArch.amd64,
        optLevel: OptimizationLevel.O2,
      );

      expect(compResult.success, isTrue);
      expect(compResult.fileSizeBytes, greaterThan(0));

      final binary = await execService.analyzeExecutableFile(compResult.outputPath);
      expect(binary.header.format, equals(ExecutableFormat.macho));
      expect(binary.sections.isNotEmpty, isTrue);
    });

    test('Applies binary byte patch and mutates byte buffer & instruction model', () async {
      final rawBytes = Uint8List.fromList([0x90, 0x90, 0x90, 0x90, 0xC3]);
      final binary = await execService.analyzeExecutableBytes(rawBytes, fileName: 'test.bin');

      final patch = BinaryPatch(
        id: 'patch_1',
        fileOffset: 0,
        virtualAddress: 0x1000,
        originalBytes: Uint8List.fromList([0x90]),
        patchedBytes: Uint8List.fromList([0xCC]), // INT3 breakpoint
        originalAsm: 'nop',
        patchedAsm: 'int3',
      );

      final patchedBinary = execService.applyPatch(binary, patch);
      expect(patchedBinary.patches.length, equals(1));
      expect(patchedBinary.byteBuffer[0], equals(0xCC));
    });
  });
}
