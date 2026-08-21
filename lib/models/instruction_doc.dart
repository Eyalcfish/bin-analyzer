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

  factory InstructionDoc.fromMap(Map<String, dynamic> map) {
    TargetArch parsedArch = TargetArch.amd64;
    try {
      parsedArch = TargetArch.values.firstWhere((a) => a.id == map['arch']);
    } catch (_) {}

    return InstructionDoc(
      id: map['id'] as String? ?? '',
      mnemonic: map['mnemonic'] as String? ?? '',
      operands: map['operands'] as String? ?? '',
      arch: parsedArch,
      isaExtension: map['isa_extension'] as String? ?? 'Base',
      category: map['category'] as String? ?? 'General',
      opcodeEncoding: map['opcode_encoding'] as String? ?? '',
      opcodePrefix: map['opcode_prefix'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      description: map['description'] as String? ?? '',
      affectedFlags: map['affected_flags'] as String? ?? 'None',
      vectorLength: map['vector_length'] as String? ?? '',
      sourceDb: map['source_db'] as String? ?? '',
    );
  }

  factory InstructionDoc.fromJson(Map<String, dynamic> json) {
    TargetArch parsedArch = TargetArch.amd64;
    try {
      parsedArch = TargetArch.values.firstWhere((a) => a.id == json['arch']);
    } catch (_) {}

    return InstructionDoc(
      id: json['id'] as String? ?? '',
      mnemonic: json['mnemonic'] as String? ?? '',
      operands: json['operands'] as String? ?? '',
      arch: parsedArch,
      isaExtension: json['isa_extension'] as String? ?? 'Base',
      category: json['category'] as String? ?? 'General',
      opcodeEncoding: json['opcode_encoding'] as String? ?? '',
      opcodePrefix: json['opcode_prefix'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      description: json['description'] as String? ?? '',
      affectedFlags: json['affected_flags'] as String? ?? 'None',
      vectorLength: json['vector_length'] as String? ?? '',
      sourceDb: json['source_db'] as String? ?? '',
    );
  }
}
