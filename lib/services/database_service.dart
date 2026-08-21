import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../models/compilation_result.dart';
import '../models/cpu_capability.dart';
import '../models/instruction_doc.dart';
import '../models/snippet.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  Database? _database;

  factory DatabaseService() => instance;

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
        version: 2,
        onCreate: (db, version) async {
          await _createTables(db);
          await _seedDefaultSnippets(db);
          await _seedDefaultInstructions(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _createInstructionTable(db);
            await _seedDefaultInstructions(db);
          }
        },
        onOpen: (db) async {
          await _createInstructionTable(db);
        },
      ),
    );

    return db;
  }

  Future<void> _createTables(Database db) async {
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

    await _createInstructionTable(db);
  }

  Future<void> _createInstructionTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS instruction_docs (
        id TEXT PRIMARY KEY,
        mnemonic TEXT NOT NULL,
        operands TEXT,
        arch TEXT NOT NULL,
        isa_extension TEXT NOT NULL,
        category TEXT NOT NULL,
        opcode_encoding TEXT NOT NULL,
        opcode_prefix TEXT,
        summary TEXT NOT NULL,
        description TEXT,
        affected_flags TEXT,
        vector_length TEXT,
        source_db TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_instr_arch ON instruction_docs(arch);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_instr_mnemonic ON instruction_docs(mnemonic);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_instr_isa ON instruction_docs(isa_extension);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_instr_category ON instruction_docs(category);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_instr_arch_isa ON instruction_docs(arch, isa_extension);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_instr_arch_mnemonic ON instruction_docs(arch, mnemonic);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_instr_arch_cat ON instruction_docs(arch, category);');

    try {
      final countRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM instruction_docs');
      final count = (countRes.first['cnt'] as int?) ?? 0;
      if (count == 0) {
        await _seedDefaultInstructions(db);
      }
    } catch (_) {}
  }

  Future<void> _seedDefaultSnippets(Database db) async {
    for (final preset in Snippet.defaultPresets) {
      await db.insert('snippets', preset.toMap());
    }
  }

  Future<void> _seedDefaultInstructions(Database db) async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/instructions_seed.json');
      await _importInstructionsFromJsonInternal(db, jsonString, clearFirst: false);
    } catch (_) {
      // Fallback for tests or environments where asset bundle isn't available
      final seedFile = File('assets/data/instructions_seed.json');
      if (seedFile.existsSync()) {
        final jsonString = seedFile.readAsStringSync();
        await _importInstructionsFromJsonInternal(db, jsonString, clearFirst: false);
      }
    }
  }

  Future<int> _importInstructionsFromJsonInternal(Database db, String jsonContent, {bool clearFirst = false}) async {
    final Map<String, dynamic> data = jsonDecode(jsonContent) as Map<String, dynamic>;
    final List<dynamic> list = data['instructions'] as List<dynamic>? ?? [];

    if (clearFirst) {
      await db.delete('instruction_docs');
    }

    final batch = db.batch();
    int count = 0;

    for (final item in list) {
      if (item is Map<String, dynamic>) {
        final doc = InstructionDoc.fromJson(item);
        final map = doc.toMap();
        map['created_at'] = DateTime.now().toIso8601String();
        batch.insert('instruction_docs', map, conflictAlgorithm: ConflictAlgorithm.replace);
        count++;
      }
    }

    await batch.commit(noResult: true);
    return count;
  }

  // --- Instruction Docs Database Operations ---

  Future<List<InstructionDoc>> getInstructions({
    String? query,
    TargetArch? arch,
    String? isaExtension,
    String? category,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim()}%';
      whereClauses.add('(mnemonic LIKE ? OR opcode_encoding LIKE ? OR summary LIKE ? OR description LIKE ?)');
      whereArgs.addAll([q, q, q, q]);
    }

    if (arch != null) {
      whereClauses.add('arch = ?');
      whereArgs.add(arch.id);
    }

    if (isaExtension != null && isaExtension != 'All') {
      whereClauses.add('isa_extension = ?');
      whereArgs.add(isaExtension);
    }

    if (category != null && category != 'All') {
      whereClauses.add('category = ?');
      whereArgs.add(category);
    }

    final String? where = whereClauses.isEmpty ? null : whereClauses.join(' AND ');

    final List<Map<String, dynamic>> maps = await db.query(
      'instruction_docs',
      where: where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'arch ASC, isa_extension ASC, mnemonic ASC',
      limit: limit,
      offset: offset,
    );

    return maps.map((m) => InstructionDoc.fromMap(m)).toList();
  }

  Future<int> countInstructions({
    String? query,
    TargetArch? arch,
    String? isaExtension,
    String? category,
  }) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim()}%';
      whereClauses.add('(mnemonic LIKE ? OR opcode_encoding LIKE ? OR summary LIKE ? OR description LIKE ?)');
      whereArgs.addAll([q, q, q, q]);
    }

    if (arch != null) {
      whereClauses.add('arch = ?');
      whereArgs.add(arch.id);
    }

    if (isaExtension != null && isaExtension != 'All') {
      whereClauses.add('isa_extension = ?');
      whereArgs.add(isaExtension);
    }

    if (category != null && category != 'All') {
      whereClauses.add('category = ?');
      whereArgs.add(category);
    }

    String sql = 'SELECT COUNT(*) as count FROM instruction_docs';
    if (whereClauses.isNotEmpty) {
      sql += ' WHERE ${whereClauses.join(' AND ')}';
    }

    final result = await db.rawQuery(sql, whereArgs.isEmpty ? null : whereArgs);
    if (result.isNotEmpty) {
      return (result.first['count'] as int?) ?? 0;
    }
    return 0;
  }

  Future<InstructionDoc?> lookupInstruction(String rawToken, {TargetArch? arch}) async {
    final db = await database;
    String token = rawToken.trim();

    // Clean prefix/directives/symbols
    if (token.startsWith('.')) token = token.substring(1);
    if (token.endsWith(':')) token = token.substring(0, token.length - 1);
    if (token.isEmpty) return null;

    // 1. Direct mnemonic match for current arch (if specified)
    if (arch != null) {
      final matches = await db.query(
        'instruction_docs',
        where: 'arch = ? AND mnemonic = ? COLLATE NOCASE',
        whereArgs: [arch.id, token],
        limit: 1,
      );
      if (matches.isNotEmpty) {
        return InstructionDoc.fromMap(matches.first);
      }
    }

    // 2. Direct mnemonic match across any arch
    final anyArchMatches = await db.query(
      'instruction_docs',
      where: 'mnemonic = ? COLLATE NOCASE',
      whereArgs: [token],
      limit: 1,
    );
    if (anyArchMatches.isNotEmpty) {
      return InstructionDoc.fromMap(anyArchMatches.first);
    }

    // 3. Try stripping AT&T size suffixes (q, l, w, b, d, s) if token length >= 3
    if (token.length >= 3) {
      final lastChar = token[token.length - 1].toLowerCase();
      if (lastChar == 'q' || lastChar == 'l' || lastChar == 'w' || lastChar == 'b' || lastChar == 'd' || lastChar == 's') {
        final stripped = token.substring(0, token.length - 1);
        if (arch != null) {
          final strippedArchMatches = await db.query(
            'instruction_docs',
            where: 'arch = ? AND mnemonic = ? COLLATE NOCASE',
            whereArgs: [arch.id, stripped],
            limit: 1,
          );
          if (strippedArchMatches.isNotEmpty) {
            return InstructionDoc.fromMap(strippedArchMatches.first);
          }
        }

        final strippedMatches = await db.query(
          'instruction_docs',
          where: 'mnemonic = ? COLLATE NOCASE',
          whereArgs: [stripped],
          limit: 1,
        );
        if (strippedMatches.isNotEmpty) {
          return InstructionDoc.fromMap(strippedMatches.first);
        }
      }
    }

    // 4. Try opcode matching if token looks like hex
    final hexMatches = await db.query(
      'instruction_docs',
      where: 'opcode_encoding LIKE ?',
      whereArgs: ['%$token%'],
      limit: 1,
    );
    if (hexMatches.isNotEmpty) {
      return InstructionDoc.fromMap(hexMatches.first);
    }

    return null;
  }

  Future<List<InstructionDoc>> getInstructionsByIsa(String isaName, {TargetArch? arch}) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    whereClauses.add('(isa_extension = ? COLLATE NOCASE OR isa_extension LIKE ?)');
    whereArgs.addAll([isaName, '%$isaName%']);

    if (arch != null) {
      whereClauses.add('arch = ?');
      whereArgs.add(arch.id);
    }

    final maps = await db.query(
      'instruction_docs',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'mnemonic ASC',
    );

    return maps.map((m) => InstructionDoc.fromMap(m)).toList();
  }

  Future<List<String>> getAvailableIsaExtensions({TargetArch? arch}) async {
    final db = await database;
    String sql = 'SELECT DISTINCT isa_extension FROM instruction_docs';
    List<dynamic> args = [];

    if (arch != null) {
      sql += ' WHERE arch = ?';
      args.add(arch.id);
    }
    sql += ' ORDER BY isa_extension ASC';

    final List<Map<String, dynamic>> result = await db.rawQuery(sql, args);
    return result.map((r) => r['isa_extension'] as String).toList();
  }

  Future<List<String>> getAvailableInstructionCategories({TargetArch? arch}) async {
    final db = await database;
    String sql = 'SELECT DISTINCT category FROM instruction_docs';
    List<dynamic> args = [];

    if (arch != null) {
      sql += ' WHERE arch = ?';
      args.add(arch.id);
    }
    sql += ' ORDER BY category ASC';

    final List<Map<String, dynamic>> result = await db.rawQuery(sql, args);
    return result.map((r) => r['category'] as String).toList();
  }

  Future<int> importInstructionsFromJson(String jsonContent, {bool clearFirst = false}) async {
    final db = await database;
    return await _importInstructionsFromJsonInternal(db, jsonContent, clearFirst: clearFirst);
  }

  Future<String> exportInstructionsToJson() async {
    final docs = await getInstructions();
    final data = {
      'version': '1.0',
      'exported_at': DateTime.now().toIso8601String(),
      'instructions': docs.map((d) => d.toMap()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<InstructionDoc?> getInstructionById(String id) async {
    final db = await database;
    final maps = await db.query(
      'instruction_docs',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return InstructionDoc.fromMap(maps.first);
  }

  // --- Snippets Database Operations ---

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
