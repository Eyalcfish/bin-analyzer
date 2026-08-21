import 'dart:typed_data';
import 'cpu_capability.dart';

enum BinaryOutputFormat {
  peExe(
    id: 'pe_exe',
    label: 'Windows PE Executable (.exe)',
    extension: 'exe',
    format: ExecutableFormat.pe,
  ),
  elfBinary(
    id: 'elf_binary',
    label: 'Linux ELF Executable (.elf)',
    extension: 'elf',
    format: ExecutableFormat.elf,
  ),
  machOBinary(
    id: 'macho_binary',
    label: 'macOS Mach-O Binary (.macho)',
    extension: 'macho',
    format: ExecutableFormat.macho,
  ),
  relocatableObject(
    id: 'relocatable_object',
    label: 'Relocatable Object (.o)',
    extension: 'o',
    format: ExecutableFormat.raw,
  );

  final String id;
  final String label;
  final String extension;
  final ExecutableFormat format;

  const BinaryOutputFormat({
    required this.id,
    required this.label,
    required this.extension,
    required this.format,
  });
}

enum ExecutableFormat {
  pe(name: 'PE / COFF (Windows)'),
  elf(name: 'ELF (Linux / Unix)'),
  macho(name: 'Mach-O (macOS / Darwin)'),
  raw(name: 'Raw / Object File');

  final String name;
  const ExecutableFormat({required this.name});
}

class ExecutableHeader {
  final ExecutableFormat format;
  final String formatDetail;
  final TargetArch arch;
  final String machineType;
  final int bitness; // 32 or 64
  final String endianness; // Little-Endian or Big-Endian
  final int entryPointAddress;
  final int imageBase;
  final String subsystem;
  final int sectionCount;
  final int symbolCount;
  final int fileSizeBytes;
  final String sha256;

  ExecutableHeader({
    required this.format,
    required this.formatDetail,
    required this.arch,
    required this.machineType,
    required this.bitness,
    required this.endianness,
    required this.entryPointAddress,
    required this.imageBase,
    required this.subsystem,
    required this.sectionCount,
    required this.symbolCount,
    required this.fileSizeBytes,
    required this.sha256,
  });
}

class ExecutableSection {
  final String name;
  final int virtualAddress;
  final int virtualSize;
  final int rawOffset;
  final int rawSize;
  final String permissions; // 'r-x', 'rw-', 'r--', etc.
  final int characteristics;
  final double entropy;

  ExecutableSection({
    required this.name,
    required this.virtualAddress,
    required this.virtualSize,
    required this.rawOffset,
    required this.rawSize,
    required this.permissions,
    required this.characteristics,
    this.entropy = 0.0,
  });

  bool get isExecutable => permissions.contains('x');
  bool get isWritable => permissions.contains('w');
  bool get isReadable => permissions.contains('r');
}

enum SymbolType {
  function,
  data,
  importSymbol,
  exportSymbol,
  section,
  unknown,
}

class ExecutableSymbol {
  final String name;
  final int virtualAddress;
  final int size;
  final String sectionName;
  final SymbolType type;
  final bool isExported;
  final bool isImported;

  ExecutableSymbol({
    required this.name,
    required this.virtualAddress,
    this.size = 0,
    this.sectionName = '',
    this.type = SymbolType.function,
    this.isExported = false,
    this.isImported = false,
  });
}

class ExecutableInstruction {
  final int virtualAddress;
  final int fileOffset;
  final String hexBytes;
  final String mnemonic;
  final String operands;
  final String comment;
  final String? functionName;
  final bool isFunctionHeader;
  final bool isPatched;
  final Uint8List? rawBytes;

  ExecutableInstruction({
    required this.virtualAddress,
    required this.fileOffset,
    required this.hexBytes,
    required this.mnemonic,
    required this.operands,
    this.comment = '',
    this.functionName,
    this.isFunctionHeader = false,
    this.isPatched = false,
    this.rawBytes,
  });

  String get fullDisassembly => operands.isEmpty ? mnemonic : '$mnemonic $operands';
}

class BinaryPatch {
  final String id;
  final int fileOffset;
  final int virtualAddress;
  final Uint8List originalBytes;
  final Uint8List patchedBytes;
  final String originalAsm;
  final String patchedAsm;
  final String description;
  final DateTime timestamp;

  BinaryPatch({
    required this.id,
    required this.fileOffset,
    required this.virtualAddress,
    required this.originalBytes,
    required this.patchedBytes,
    required this.originalAsm,
    required this.patchedAsm,
    this.description = '',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ExecutableBinary {
  final String filePath;
  final String fileName;
  final Uint8List byteBuffer;
  final ExecutableHeader header;
  final List<ExecutableSection> sections;
  final List<ExecutableSymbol> symbols;
  final List<ExecutableInstruction> instructions;
  final List<BinaryPatch> patches;

  ExecutableBinary({
    required this.filePath,
    required this.fileName,
    required this.byteBuffer,
    required this.header,
    required this.sections,
    required this.symbols,
    required this.instructions,
    this.patches = const [],
  });

  ExecutableBinary copyWith({
    String? filePath,
    String? fileName,
    Uint8List? byteBuffer,
    ExecutableHeader? header,
    List<ExecutableSection>? sections,
    List<ExecutableSymbol>? symbols,
    List<ExecutableInstruction>? instructions,
    List<BinaryPatch>? patches,
  }) {
    return ExecutableBinary(
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      byteBuffer: byteBuffer ?? this.byteBuffer,
      header: header ?? this.header,
      sections: sections ?? this.sections,
      symbols: symbols ?? this.symbols,
      instructions: instructions ?? this.instructions,
      patches: patches ?? this.patches,
    );
  }
}
