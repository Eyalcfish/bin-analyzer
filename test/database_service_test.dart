import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bin_analyzer/models/snippet.dart';
import 'package:bin_analyzer/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('DatabaseService Tests', () {
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
}
