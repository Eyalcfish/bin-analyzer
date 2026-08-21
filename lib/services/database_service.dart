import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../models/compilation_result.dart';
import '../models/snippet.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  Database? _database;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String dbPath = inMemoryDatabasePath;
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final dbDir = Directory(p.join(docDir.path, 'bin_analyzer'));
      if (!dbDir.existsSync()) {
        dbDir.createSync(recursive: true);
      }
      dbPath = p.join(dbDir.path, 'snippets.db');
    } catch (_) {
      final tempDir = Directory(p.join(Directory.systemTemp.path, 'bin_analyzer_test'));
      if (!tempDir.existsSync()) {
        tempDir.createSync(recursive: true);
      }
      dbPath = p.join(tempDir.path, 'snippets.db');
    }

    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE snippets (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              description TEXT NOT NULL,
              category TEXT NOT NULL,
              code TEXT NOT NULL,
              recommended_arch TEXT NOT NULL,
              recommended_opt TEXT NOT NULL,
              recommended_features TEXT NOT NULL,
              is_preset INTEGER NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE compilation_history (
              id TEXT PRIMARY KEY,
              snippet_title TEXT NOT NULL,
              code TEXT NOT NULL,
              arch TEXT NOT NULL,
              opt_level TEXT NOT NULL,
              applied_flags TEXT NOT NULL,
              code_size INTEGER NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');

          // Seed default presets
          for (final preset in Snippet.defaultPresets) {
            await db.insert('snippets', preset.toMap());
          }
        },
      ),
    );

    return db;
  }

  Future<List<Snippet>> getAllSnippets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'snippets',
      orderBy: 'is_preset DESC, title ASC',
    );
    return maps.map((map) => Snippet.fromMap(map)).toList();
  }

  Future<List<Snippet>> searchSnippets(String query, {String? category}) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (query.trim().isNotEmpty) {
      whereClause = '(title LIKE ? OR description LIKE ? OR category LIKE ?)';
      final q = '%${query.trim()}%';
      whereArgs.addAll([q, q, q]);
    }

    if (category != null && category != 'All') {
      if (whereClause.isNotEmpty) {
        whereClause += ' AND category = ?';
      } else {
        whereClause = 'category = ?';
      }
      whereArgs.add(category);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'snippets',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'is_preset DESC, title ASC',
    );

    return maps.map((map) => Snippet.fromMap(map)).toList();
  }

  Future<void> saveSnippet(Snippet snippet) async {
    final db = await database;
    await db.insert(
      'snippets',
      snippet.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSnippet(String id) async {
    final db = await database;
    await db.delete(
      'snippets',
      where: 'id = ? AND is_preset = 0',
      whereArgs: [id],
    );
  }

  Future<List<String>> getCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT DISTINCT category FROM snippets ORDER BY category ASC',
    );
    return result.map((r) => r['category'] as String).toList();
  }

  Future<void> recordHistory(CompilationResult result, String snippetTitle, String code) async {
    final db = await database;
    final id = const Uuid().v4();
    await db.insert('compilation_history', {
      'id': id,
      'snippet_title': snippetTitle,
      'code': code,
      'arch': result.arch.id,
      'opt_level': result.optLevel.flag,
      'applied_flags': result.appliedFlags.join(' '),
      'code_size': result.codeSizeBytes,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getHistory({int limit = 50}) async {
    final db = await database;
    return await db.query(
      'compilation_history',
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }
}
