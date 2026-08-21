import 'cpu_capability.dart';

class InstructionDoc {
  final String id;
  final String mnemonic;
  final String operands;
  final TargetArch arch;
  final String isaExtension;
  final String category;
  final String opcodeEncoding;
  final String opcodePrefix;
  final String summary;
  final String description;
  final String affectedFlags;
  final String vectorLength;
  final String sourceDb;

  InstructionDoc({
    required this.id,
    required this.mnemonic,
    required this.operands,
    required this.arch,
    required this.isaExtension,
    required this.category,
    required this.opcodeEncoding,
    this.opcodePrefix = '',
    required this.summary,
    required this.description,
    this.affectedFlags = 'None',
    this.vectorLength = '',
    this.sourceDb = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mnemonic': mnemonic,
      'operands': operands,
      'arch': arch.id,
      'isa_extension': isaExtension,
      'category': category,
      'opcode_encoding': opcodeEncoding,
      'opcode_prefix': opcodePrefix,
      'summary': summary,
      'description': description,
      'affected_flags': affectedFlags,
      'vector_length': vectorLength,
      'source_db': sourceDb,
    };
  }

  static String _safeString(dynamic val, [String fallback = '']) {
    if (val == null) return fallback;
    if (val is String) return val;
    if (val is List) return val.map((e) => e.toString()).join(', ');
    return val.toString();
  }

  static TargetArch _parseArch(dynamic val) {
    if (val == null) return TargetArch.amd64;
    final str = val.toString().trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '');
    if (str == 'amd64' || str == 'x86_64' || str == 'x64' || str == 'x8664' || str == 'intel64') {
      return TargetArch.amd64;
    }
    if (str == 'i386' || str == 'x86' || str == 'i686' || str == 'ia32' || str == 'x86_32') {
      return TargetArch.i386;
    }
    if (str == 'arm64' || str == 'aarch64' || str == 'armv8' || str == 'armv8_a' || str == 'armv9') {
      return TargetArch.arm64;
    }
    if (str == 'arm32' || str == 'arm' || str == 'armv7' || str == 'armv7_a' || str == 'armhf') {
      return TargetArch.arm32;
    }
    if (str == 'riscv64' || str == 'riscv' || str == 'rv64' || str == 'rv64g' || str == 'riscv_64') {
      return TargetArch.riscv64;
    }
    for (final arch in TargetArch.values) {
      if (arch.id == str || arch.name.toLowerCase().contains(str)) {
        return arch;
      }
    }
    return TargetArch.amd64;
  }

  factory InstructionDoc.fromMap(Map<String, dynamic> map) {
    final parsedArch = _parseArch(map['arch']);
    return InstructionDoc(
      id: _safeString(map['id']),
      mnemonic: _safeString(map['mnemonic']),
      operands: _safeString(map['operands']),
      arch: parsedArch,
      isaExtension: _safeString(map['isa_extension'], 'Base'),
      category: _safeString(map['category'], 'General'),
      opcodeEncoding: _safeString(map['opcode_encoding']),
      opcodePrefix: _safeString(map['opcode_prefix']),
      summary: _safeString(map['summary']),
      description: _safeString(map['description']),
      affectedFlags: _safeString(map['affected_flags'], 'None'),
      vectorLength: _safeString(map['vector_length']),
      sourceDb: _safeString(map['source_db']),
    );
  }

  factory InstructionDoc.fromJson(Map<String, dynamic> json, [int fallbackIndex = 0]) {
    final parsedArch = _parseArch(json['arch']);
    final mnemonic = _safeString(json['mnemonic']);
    final isa = _safeString(json['isa_extension'] ?? json['isa'] ?? json['extension'], 'Base');
    String id = _safeString(json['id']);
    if (id.isEmpty) {
      id = '${parsedArch.id}_${mnemonic}_${isa}_$fallbackIndex'.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    }

    return InstructionDoc(
      id: id,
      mnemonic: mnemonic,
      operands: _safeString(json['operands'] ?? json['syntax']),
      arch: parsedArch,
      isaExtension: isa,
      category: _safeString(json['category'] ?? json['group'], 'General'),
      opcodeEncoding: _safeString(json['opcode_encoding'] ?? json['encoding'] ?? json['opcode']),
      opcodePrefix: _safeString(json['opcode_prefix'] ?? json['prefix']),
      summary: _safeString(json['summary'] ?? json['brief'] ?? json['short_desc']),
      description: _safeString(json['description'] ?? json['details'] ?? json['long_desc']),
      affectedFlags: _safeString(json['affected_flags'] ?? json['flags'], 'None'),
      vectorLength: _safeString(json['vector_length'] ?? json['vl'] ?? json['simd_width']),
      sourceDb: _safeString(json['source_db'] ?? json['source'], 'Imported'),
    );
  }
}
