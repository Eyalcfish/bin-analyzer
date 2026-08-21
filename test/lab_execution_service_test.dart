import 'package:flutter_test/flutter_test.dart';
import 'package:bin_analyzer/models/cpu_capability.dart';
import 'package:bin_analyzer/models/lab_experiment.dart';
import 'package:bin_analyzer/services/lab_execution_service.dart';

void main() {
  group('LabExecutionService Snippet & Register State Capture Tests', () {
    late LabExecutionService service;

    setUp(() {
      service = LabExecutionService.instance;
    });

    test('Executes assembly arithmetic snippet and captures RAX/RBX', () async {
      const asmCode = '''
mov rax, 10
mov rbx, 32
add rax, rbx
''';

      final result = await service.executeSnippet(
        snippetCode: asmCode,
        snippetType: LabSnippetType.assembly,
        arch: TargetArch.amd64,
      );

      expect(result.success, isTrue, reason: 'Error: ${result.errorMessage}');
      expect(result.registers.gpr['rax'], equals(BigInt.from(42)));
      expect(result.registers.gpr['rbx'], equals(BigInt.from(32)));
    });

    test('Injects initial register values and computes in snippet', () async {
      const asmCode = '''
add rax, rcx
imul rax, 2
''';

      final initial = {
        'rax': BigInt.from(15),
        'rcx': BigInt.from(5),
      };

      final result = await service.executeSnippet(
        snippetCode: asmCode,
        snippetType: LabSnippetType.assembly,
        arch: TargetArch.amd64,
        initialRegisters: initial,
      );

      expect(result.success, isTrue);
      // (15 + 5) * 2 = 40
      expect(result.registers.gpr['rax'], equals(BigInt.from(40)));
    });

    test('Captures RFLAGS correctly after CMP', () async {
      const asmCode = '''
mov rax, 100
cmp rax, 100
''';

      final result = await service.executeSnippet(
        snippetCode: asmCode,
        snippetType: LabSnippetType.assembly,
        arch: TargetArch.amd64,
      );

      expect(result.success, isTrue);
      expect(result.registers.zf, isTrue, reason: 'Zero flag should be set for equal CMP');
    });

    test('Executes raw machine code hex opcodes', () async {
      // 48 C7 C0 2A 00 00 00 -> mov rax, 42
      const hexBytes = '48 C7 C0 2A 00 00 00';

      final result = await service.executeSnippet(
        snippetCode: hexBytes,
        snippetType: LabSnippetType.machineCodeHex,
        arch: TargetArch.amd64,
      );

      expect(result.success, isTrue);
      expect(result.registers.gpr['rax'], equals(BigInt.from(42)));
    });

    test('Runs high-precision benchmark across iterations', () async {
      const asmCode = '''
add rax, 1
''';

      final bench = await service.benchmarkSnippet(
        snippetCode: asmCode,
        snippetType: LabSnippetType.assembly,
        arch: TargetArch.amd64,
        iterations: 10000,
      );

      expect(bench.iterations, equals(10000));
      expect(bench.totalDurationMs, isNonNegative);
      expect(bench.avgDurationNs, isNonNegative);
    });

    test('Executes and benchmarks user snippet with comments and rcx = 10', () async {
      const snippet = '''
mov\tebx, 2\t # i,
mov\tedx, ebx\t # tmp100, i
mov\teax, ecx
add\teax, edx\t # _3, tmp100
''';
      final initial = {'rcx': BigInt.from(10)};

      final execRes = await service.executeSnippet(
        snippetCode: snippet,
        snippetType: LabSnippetType.assembly,
        arch: TargetArch.amd64,
        initialRegisters: initial,
      );

      expect(execRes.success, isTrue);
      // 10 + 2 = 12 (0xC)
      expect(execRes.registers.gpr['rax'], equals(BigInt.from(12)));
      expect(execRes.registers.gpr['rbx'], equals(BigInt.from(2)));
      expect(execRes.registers.gpr['rdx'], equals(BigInt.from(2)));
      expect(execRes.registers.gpr['rcx'], equals(BigInt.from(10)));

      final benchRes = await service.benchmarkSnippet(
        snippetCode: snippet,
        snippetType: LabSnippetType.assembly,
        arch: TargetArch.amd64,
        iterations: 10000,
        initialRegisters: initial,
      );

      expect(benchRes.iterations, equals(10000));
      expect(benchRes.avgDurationNs, isPositive);
    });

    test('Executes and benchmarks complex AVX vector_add with memory buffers and internal rets', () async {
      const vectorAddSnippet = '''
vector_add:
\tpush\trbx\t #
\ttest\tr9d, r9d\t # count
\tjle\t.L14\t #,
\tlea\teax, -1[r9]\t # _42,
\tcmp\teax, 6\t # _42,
\tjbe\t.L8\t #,
\tmov\tr10d, r9d\t # bnd.5_45, count
\txor\teax, eax\t # ivtmp.36
\tshr\tr10d, 3\t #,
\tsal\tr10, 5\t # _80,
.L4:
\tvmovups\tymm0, YMMWORD PTR [rdx+rax]\t # vect__6.13_55
\tvaddps\tymm0, ymm0, YMMWORD PTR [rcx+rax]\t # vect__8.14_56
\tvmovups\tYMMWORD PTR [r8+rax], ymm0\t #
\tadd\trax, 32\t # ivtmp.36
\tcmp\trax, r10\t # ivtmp.36, _80
\tjne\t.L4\t #,
\tmov\tr10d, r9d\t # tmp.20, count
\tand\tr10d, -8\t # tmp.20
\tmov\teax, r10d\t # tmp.20
\tcmp\tr9d, r10d\t # count, tmp.20
\tje\t.L16\t #,
\tvzeroupper
.L3:
\tmov\tr11d, r9d\t # niters.17, count
\tsub\tr11d, eax\t # niters.17
\tlea\tebx, -1[r11]\t # _81
\tcmp\tebx, 2\t # _81
\tjbe\t.L6\t #,
\tsal\trax, 2\t # _90
\tvmovups\txmm0, XMMWORD PTR [rdx+rax]\t #
\tvaddps\txmm0, xmm0, XMMWORD PTR [rcx+rax]\t #
\tvmovups\tXMMWORD PTR [r8+rax], xmm0\t #
\tmov\teax, r11d\t #
\tand\teax, -4\t #
\tadd\tr10d, eax\t #
\tand\tr11d, 3\t #
\tje\t.L14\t #,
.L6:
\tmovsx\trax, r10d\t #
\tlea\tr11d, 1[r10]\t #
\tsal\trax, 2\t #
\tvmovss\txmm0, DWORD PTR [rcx+rax]\t #
\tvaddss\txmm0, xmm0, DWORD PTR [rdx+rax]\t #
\tvmovss\tDWORD PTR [r8+rax], xmm0\t #
\tcmp\tr9d, r11d\t #
\tjle\t.L14\t #,
\tvmovss\txmm0, DWORD PTR 4[rcx+rax]\t #
\tadd\tr10d, 2\t #
\tvaddss\txmm0, xmm0, DWORD PTR 4[rdx+rax]\t #
\tvmovss\tDWORD PTR 4[r8+rax], xmm0\t #
\tcmp\tr9d, r10d\t #
\tjle\t.L14\t #,
\tvmovss\txmm0, DWORD PTR 8[rcx+rax]\t #
\tvaddss\txmm0, xmm0, DWORD PTR 8[rdx+rax]\t #
\tvmovss\tDWORD PTR 8[r8+rax], xmm0\t #
.L14:
\tpop\trbx\t #
\tret
.L16:
\tvzeroupper
\tpop\trbx\t #
\tret
.L8:
\txor\teax, eax\t #
\txor\tr10d, r10d\t #
\tjmp\t.L3\t #
''';

      final execRes = await service.executeSnippet(
        snippetCode: vectorAddSnippet,
        snippetType: LabSnippetType.assembly,
        arch: TargetArch.amd64,
        initialRegisters: {
          'r9': BigInt.from(8),
        },
      );

      expect(execRes.success, isTrue, reason: 'Error: ${execRes.errorMessage}');

      final benchRes = await service.benchmarkSnippet(
        snippetCode: vectorAddSnippet,
        snippetType: LabSnippetType.assembly,
        arch: TargetArch.amd64,
        iterations: 10000,
        initialRegisters: {
          'r9': BigInt.from(8),
        },
      );

      expect(benchRes.iterations, equals(10000));
      expect(benchRes.avgDurationNs, isPositive);
    });
  });
}
