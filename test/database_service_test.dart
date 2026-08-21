import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bin_analyzer/models/cpu_capability.dart';
import 'package:bin_analyzer/models/snippet.dart';
import 'package:bin_analyzer/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('DatabaseService Snippets Tests', () {
    final dbService = DatabaseService.instance;

    test('Loads pre-populated default presets on first init', () async {
      final snippets = await dbService.getAllSnippets();
      expect(snippets.isNotEmpty, isTrue);
      expect(snippets.any((s) => s.id == 'preset_vector_add'), isTrue);
    });

    test('Searches snippets by category and text', () async {
      final results = await dbService.searchSnippets('Vector', category: 'All');
      expect(results.isNotEmpty, isTrue);
      expect(results.any((s) => s.category.contains('SIMD') || s.title.contains('Vector')), isTrue);
    });

    test('Saves and deletes custom snippet', () async {
      final customSnippet = Snippet(
        id: 'test_custom_snippet_123',
        title: 'Custom Math',
        description: 'Test description',
        category: 'Custom Category',
        code: 'int custom_calc(int x) {\n\treturn x * 2;\n}\n',
        isPreset: false,
      );

      await dbService.saveSnippet(customSnippet);
      var fetched = await dbService.searchSnippets('Custom Math');
      expect(fetched.any((s) => s.id == 'test_custom_snippet_123'), isTrue);

      await dbService.deleteSnippet('test_custom_snippet_123');
      fetched = await dbService.searchSnippets('Custom Math');
      expect(fetched.any((s) => s.id == 'test_custom_snippet_123'), isFalse);
    });
  });

  group('DatabaseService Hardware Instruction Docs Tests', () {
    final dbService = DatabaseService.instance;

    test('Imports instruction dataset from JSON and indexes into SQLite', () async {
      const jsonSpec = '''
{
  "version": "1.0",
  "instructions": [
    {
      "id": "test_x86_vaddps",
      "mnemonic": "vaddps",
      "operands": "zmm1, zmm2, zmm3",
      "arch": "amd64",
      "isa_extension": "AVX512F",
      "category": "Vector / SIMD",
      "opcode_encoding": "EVEX.512.66.0F.W0 58 /r",
      "opcode_prefix": "EVEX",
      "summary": "Add Packed Single Float",
      "description": "Performs 512-bit vector addition.",
      "affected_flags": "None",
      "vector_length": "512 bits",
      "source_db": "Test Spec"
    },
    {
      "id": "test_arm_fadd",
      "mnemonic": "fadd",
      "operands": "v0.4s, v1.4s, v2.4s",
      "arch": "arm64",
      "isa_extension": "ARMv8-A NEON",
      "category": "Vector / SIMD",
      "opcode_encoding": "0x4e20d420",
      "opcode_prefix": "Fixed 32-bit",
      "summary": "Vector Float Add",
      "description": "Adds vector lanes.",
      "affected_flags": "None",
      "vector_length": "128 bits",
      "source_db": "Test ARM Spec"
    }
  ]
}
''';

      final count = await dbService.importInstructionsFromJson(jsonSpec, clearFirst: false);
      expect(count, equals(2));

      final all = await dbService.getInstructions();
      expect(all.any((i) => i.id == 'test_x86_vaddps'), isTrue);
      expect(all.any((i) => i.id == 'test_arm_fadd'), isTrue);
    });

    test('Queries and filters instructions by architecture and ISA extension', () async {
      final amd64Docs = await dbService.getInstructions(arch: TargetArch.amd64);
      expect(amd64Docs.isNotEmpty, isTrue);
      expect(amd64Docs.every((d) => d.arch == TargetArch.amd64), isTrue);

      final avx512Docs = await dbService.getInstructions(isaExtension: 'AVX512F');
      expect(avx512Docs.isNotEmpty, isTrue);
      expect(avx512Docs.every((d) => d.isaExtension.toLowerCase() == 'avx512f'), isTrue);

      final searchResults = await dbService.getInstructions(query: 'fadd');
      expect(searchResults.any((d) => d.mnemonic == 'fadd'), isTrue);
    });

    test('Exports instructions from SQLite database to formatted JSON', () async {
      final exportedJson = await dbService.exportInstructionsToJson();
      expect(exportedJson.contains('"version": "1.0"'), isTrue);
      expect(exportedJson.contains('"instructions"'), isTrue);
    });

    test('lookupInstruction finds mnemonics, strips AT&T suffixes, and matches opcodes', () async {
      final vaddps = await dbService.lookupInstruction('vaddps', arch: TargetArch.amd64);
      expect(vaddps, isNotNull);
      expect(vaddps!.mnemonic, equals('vaddps'));

      // Test suffix stripping (e.g. vaddpsq or faddd)
      final fadd = await dbService.lookupInstruction('fadd', arch: TargetArch.arm64);
      expect(fadd, isNotNull);
      expect(fadd!.mnemonic, equals('fadd'));

      // Test ISA instructions lookup with feature names and IDs
      final avx512List = await dbService.getInstructionsByIsa(
        'AVX-512 Foundation (F)',
        arch: TargetArch.amd64,
        featureId: 'avx512f',
      );
      expect(avx512List.isNotEmpty, isTrue);
      expect(avx512List.any((i) => i.mnemonic == 'vaddps'), isTrue);

      final avx2List = await dbService.getInstructionsByIsa(
        'AVX2 (Advanced Vector Extensions 2)',
        arch: TargetArch.amd64,
        featureId: 'avx2',
      );
      expect(avx2List.isNotEmpty, isTrue);
      expect(avx2List.any((i) => i.mnemonic == 'vpaddd'), isTrue);

      final neonList = await dbService.getInstructionsByIsa(
        'ARM NEON SIMD',
        arch: TargetArch.arm64,
        featureId: 'neon',
      );
      expect(neonList.isNotEmpty, isTrue);
      expect(neonList.any((i) => i.mnemonic == 'fadd' || i.mnemonic == 'fmla'), isTrue);
    });

    test('Imports bare JSON array with arch aliases and auto-generated IDs without crashing', () async {
      const bareJson = '''
[
  {
    "mnemonic": "custom_insn1",
    "operands": ["r0", "r1"],
    "arch": "x86_64",
    "isa": "SSE4.2",
    "category": "Math",
    "summary": 12345,
    "description": null
  },
  {
    "mnemonic": "custom_insn2",
    "operands": "x0, x1",
    "arch": "aarch64",
    "isa_extension": "Base",
    "category": "Flow",
    "summary": "ARM instruction"
  }
]
''';
      final imported = await dbService.importInstructionsFromJson(bareJson, clearFirst: false);
      expect(imported, equals(2));

      final insn1 = await dbService.lookupInstruction('custom_insn1', arch: TargetArch.amd64);
      expect(insn1, isNotNull);
      expect(insn1!.arch, equals(TargetArch.amd64));
      expect(insn1.operands, equals('r0, r1'));
      expect(insn1.summary, equals('12345'));

      final insn2 = await dbService.lookupInstruction('custom_insn2', arch: TargetArch.arm64);
      expect(insn2, isNotNull);
      expect(insn2!.arch, equals(TargetArch.arm64));
    });
  });
}
