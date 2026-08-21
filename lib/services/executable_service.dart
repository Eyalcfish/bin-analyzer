import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import '../models/cpu_capability.dart';
import '../models/executable_binary.dart';

class ExecutableService {
  static final ExecutableService instance = ExecutableService._internal();
  ExecutableService._internal();
  factory ExecutableService() => instance;

  String llvmObjdumpPath = 'C:\\MinGW-64\\bin\\llvm-objdump.exe';
  String objdumpPath = 'C:\\MinGW-64\\bin\\objdump.exe';
  String llvmReadelfPath = 'C:\\MinGW-64\\bin\\llvm-readelf.exe';

  void _autoDetectPaths() {
    if (!File(llvmObjdumpPath).existsSync()) {
      llvmObjdumpPath = 'llvm-objdump';
    }
    if (!File(objdumpPath).existsSync()) {
      objdumpPath = 'objdump';
    }
    if (!File(llvmReadelfPath).existsSync()) {
      llvmReadelfPath = 'llvm-readelf';
    }
  }

  /// Ingest and analyze any executable binary file from disk
  Future<ExecutableBinary> analyzeExecutableFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Executable binary file not found', filePath);
    }
    final bytes = await file.readAsBytes();
    final fileName = p.basename(filePath);
    return _parseAndDisassemble(bytes, fileName: fileName, filePath: filePath);
  }

  /// Ingest and analyze raw bytes of an executable binary
  Future<ExecutableBinary> analyzeExecutableBytes(
    Uint8List bytes, {
    String fileName = 'binary.bin',
    String? filePath,
  }) async {
    return _parseAndDisassemble(bytes, fileName: fileName, filePath: filePath);
  }

  Future<ExecutableBinary> _parseAndDisassemble(
    Uint8List bytes, {
    required String fileName,
    String? filePath,
  }) async {
    _autoDetectPaths();

    final sha256Digest = sha256.convert(bytes).toString();

    // 1. Detect Format and Parse Binary Headers
    final format = _detectFormat(bytes);
    ExecutableHeader header;
    List<ExecutableSection> sections = [];
    List<ExecutableSymbol> symbols = [];

    switch (format) {
      case ExecutableFormat.pe:
        final peData = _parsePeBinary(bytes, sha256Digest);
        header = peData.header;
        sections = peData.sections;
        symbols = peData.symbols;
        break;
      case ExecutableFormat.elf:
        final elfData = _parseElfBinary(bytes, sha256Digest);
        header = elfData.header;
        sections = elfData.sections;
        symbols = elfData.symbols;
        break;
      case ExecutableFormat.macho:
        final machoData = _parseMachOBinary(bytes, sha256Digest);
        header = machoData.header;
        sections = machoData.sections;
        symbols = machoData.symbols;
        break;
      case ExecutableFormat.raw:
        header = _parseRawBinary(bytes, sha256Digest);
        sections = [
          ExecutableSection(
            name: '.raw',
            virtualAddress: 0x0000,
            virtualSize: bytes.length,
            rawOffset: 0,
            rawSize: bytes.length,
            permissions: 'r-x',
            characteristics: 0x60000020,
            entropy: _calculateEntropy(bytes, 0, bytes.length),
          ),
        ];
        break;
    }

    // 2. Disassemble Instructions
    String tempFileToClean;
    String actualPath;

    if (filePath != null && File(filePath).existsSync()) {
      actualPath = filePath;
      tempFileToClean = '';
    } else {
      final tempDir = Directory.systemTemp.createTempSync('bin_disasm_');
      final tempFile = File(p.join(tempDir.path, fileName));
      await tempFile.writeAsBytes(bytes);
      actualPath = tempFile.path;
      tempFileToClean = tempFile.path;
    }

    List<ExecutableInstruction> instructions = [];
    List<ExecutableSymbol> finalSymbols = List.from(symbols);

    try {
      instructions = await _disassembleWithToolchain(actualPath, header.arch);
    } catch (_) {
      // Fallback disassembly
      instructions = _fallbackDisassembly(bytes, header);
    }

    // Comprehensive Symbol Resolution from Toolchain & Disassembly Function Headers
    final Map<String, ExecutableSymbol> allSymbolsMap = {};

    // 1. Toolchain symbol table
    try {
      final toolSymbols = await _extractSymbolsFromToolchain(actualPath);
      for (final s in toolSymbols) {
        allSymbolsMap[s.name] = s;
      }
    } catch (_) {}

    // 2. Disassembly function headers (<main>:, <compute>:, etc.)
    for (final insn in instructions) {
      if (insn.isFunctionHeader && insn.functionName != null && insn.functionName!.isNotEmpty) {
        final fnName = insn.functionName!;
        if (!allSymbolsMap.containsKey(fnName)) {
          allSymbolsMap[fnName] = ExecutableSymbol(
            name: fnName,
            virtualAddress: insn.virtualAddress,
            sectionName: '.text',
            type: SymbolType.function,
            isExported: fnName == 'main' || fnName.startsWith('_start') || fnName == 'WinMain',
          );
        }
      }
    }

    // 3. Entry Point Mapping
    if (header.entryPointAddress > 0) {
      final entryMatches = allSymbolsMap.values.where((s) => s.virtualAddress == header.entryPointAddress).toList();
      if (entryMatches.isEmpty) {
        allSymbolsMap['_entry'] = ExecutableSymbol(
          name: '_entry',
          virtualAddress: header.entryPointAddress,
          sectionName: '.text',
          type: SymbolType.function,
          isExported: true,
        );
      }
    }

    // 4. Initial format header symbols
    for (final s in finalSymbols) {
      if (!allSymbolsMap.containsKey(s.name) && !allSymbolsMap.values.any((x) => x.virtualAddress == s.virtualAddress)) {
        allSymbolsMap[s.name] = s;
      }
    }

    final resolvedSymbols = allSymbolsMap.values.toList()
      ..sort((a, b) => a.virtualAddress.compareTo(b.virtualAddress));

    if (tempFileToClean.isNotEmpty) {
      try {
        final f = File(tempFileToClean);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }

    final updatedHeader = ExecutableHeader(
      format: header.format,
      formatDetail: header.formatDetail,
      arch: header.arch,
      machineType: header.machineType,
      bitness: header.bitness,
      endianness: header.endianness,
      entryPointAddress: header.entryPointAddress,
      imageBase: header.imageBase,
      subsystem: header.subsystem,
      sectionCount: sections.length,
      symbolCount: resolvedSymbols.length,
      fileSizeBytes: bytes.length,
      sha256: header.sha256,
    );

    return ExecutableBinary(
      filePath: filePath ?? fileName,
      fileName: fileName,
      byteBuffer: bytes,
      header: updatedHeader,
      sections: sections,
      symbols: resolvedSymbols,
      instructions: instructions,
    );
  }

  ExecutableFormat _detectFormat(Uint8List bytes) {
    if (bytes.length < 4) return ExecutableFormat.raw;

    // PE MZ signature
    if (bytes[0] == 0x4D && bytes[1] == 0x5A) {
      return ExecutableFormat.pe;
    }

    // ELF magic: 0x7F 'E' 'L' 'F'
    if (bytes[0] == 0x7F && bytes[1] == 0x45 && bytes[2] == 0x4C && bytes[3] == 0x46) {
      return ExecutableFormat.elf;
    }

    // Mach-O magics:
    // 0xFEEDFACE (32-bit BE), 0xFEEDFACF (64-bit BE)
    // 0xCEFAEDFE (32-bit LE), 0xCFFAEDFE (64-bit LE)
    // 0xCAFEBABE / 0xBEBAFECA (FAT Universal)
    final b0 = bytes[0], b1 = bytes[1], b2 = bytes[2], b3 = bytes[3];
    if ((b0 == 0xFE && b1 == 0xED && b2 == 0xFA && (b3 == 0xCE || b3 == 0xCF)) ||
        ((b0 == 0xCE || b0 == 0xCF) && b1 == 0xFA && b2 == 0xED && b3 == 0xFE) ||
        (b0 == 0xCA && b1 == 0xFE && b2 == 0xBA && b3 == 0xBE) ||
        (b0 == 0xBE && b1 == 0xBA && b2 == 0xFE && b3 == 0xCA)) {
      return ExecutableFormat.macho;
    }

    return ExecutableFormat.raw;
  }

  // --- PE Binary Parser ---
  _ParsedData _parsePeBinary(Uint8List bytes, String sha256Digest) {
    final byteData = ByteData.sublistView(bytes);
    int bitness = 64;
    TargetArch arch = TargetArch.amd64;
    String machineType = 'x86_64 (AMD64)';
    int entryPoint = 0;
    int imageBase = 0x140000000;
    String subsystem = 'Windows Console';
    int sectionCount = 0;
    final List<ExecutableSection> sections = [];
    final List<ExecutableSymbol> symbols = [];

    try {
      if (bytes.length >= 0x40) {
        final peOffset = byteData.getUint32(0x3C, Endian.little);
        if (peOffset + 24 < bytes.length &&
            bytes[peOffset] == 0x50 &&
            bytes[peOffset + 1] == 0x45 &&
            bytes[peOffset + 2] == 0x00 &&
            bytes[peOffset + 3] == 0x00) {
          final coffOffset = peOffset + 4;
          final machine = byteData.getUint16(coffOffset, Endian.little);
          sectionCount = byteData.getUint16(coffOffset + 2, Endian.little);
          final sizeOfOptionalHeader = byteData.getUint16(coffOffset + 16, Endian.little);

          switch (machine) {
            case 0x8664:
              arch = TargetArch.amd64;
              machineType = 'AMD64 / x86-64';
              break;
            case 0x014C:
              arch = TargetArch.i386;
              machineType = 'Intel 386 / x86-32';
              bitness = 32;
              break;
            case 0xAA64:
              arch = TargetArch.arm64;
              machineType = 'ARM64 (AArch64)';
              break;
            case 0x01C0:
            case 0x01C4:
              arch = TargetArch.arm32;
              machineType = 'ARMv7 (Thumb-2)';
              bitness = 32;
              break;
            case 0x5064:
              arch = TargetArch.riscv64;
              machineType = 'RISC-V 64-bit';
              break;
            default:
              machineType = '0x${machine.toRadixString(16).toUpperCase()}';
          }

          final optHeaderOffset = coffOffset + 20;
          if (sizeOfOptionalHeader > 0 && optHeaderOffset + 68 < bytes.length) {
            final magic = byteData.getUint16(optHeaderOffset, Endian.little);
            bitness = (magic == 0x020B) ? 64 : 32;
            entryPoint = byteData.getUint32(optHeaderOffset + 16, Endian.little);

            if (bitness == 64) {
              imageBase = byteData.getUint64(optHeaderOffset + 24, Endian.little);
            } else {
              imageBase = byteData.getUint32(optHeaderOffset + 28, Endian.little);
            }

            final sub = byteData.getUint16(optHeaderOffset + 68, Endian.little);
            subsystem = sub == 2 ? 'Windows GUI' : (sub == 3 ? 'Windows CUI (Console)' : 'Native ($sub)');
          }

          // Section Headers
          final sectionTableOffset = optHeaderOffset + sizeOfOptionalHeader;
          for (int i = 0; i < sectionCount; i++) {
            final secOffset = sectionTableOffset + (i * 40);
            if (secOffset + 40 <= bytes.length) {
              final rawNameBytes = bytes.sublist(secOffset, secOffset + 8);
              final name = String.fromCharCodes(rawNameBytes.takeWhile((b) => b != 0));
              final vSize = byteData.getUint32(secOffset + 8, Endian.little);
              final vAddr = byteData.getUint32(secOffset + 12, Endian.little);
              final rawSize = byteData.getUint32(secOffset + 16, Endian.little);
              final rawOff = byteData.getUint32(secOffset + 20, Endian.little);
              final charact = byteData.getUint32(secOffset + 36, Endian.little);

              final isExec = (charact & 0x20000000) != 0;
              final isRead = (charact & 0x40000000) != 0;
              final isWrite = (charact & 0x80000000) != 0;
              final perms = '${isRead ? "r" : "-"}${isWrite ? "w" : "-"}${isExec ? "x" : "-"}';

              final entropy = _calculateEntropy(bytes, rawOff, rawSize);

              sections.add(
                ExecutableSection(
                  name: name.isEmpty ? 'sec_$i' : name,
                  virtualAddress: imageBase + vAddr,
                  virtualSize: vSize,
                  rawOffset: rawOff,
                  rawSize: rawSize,
                  permissions: perms,
                  characteristics: charact,
                  entropy: entropy,
                ),
              );
            }
          }
        }
      }
    } catch (_) {}

    final header = ExecutableHeader(
      format: ExecutableFormat.pe,
      formatDetail: bitness == 64 ? 'PE32+ (64-bit Portable Executable)' : 'PE32 (32-bit Portable Executable)',
      arch: arch,
      machineType: machineType,
      bitness: bitness,
      endianness: 'Little-Endian (x86/ARM)',
      entryPointAddress: imageBase + entryPoint,
      imageBase: imageBase,
      subsystem: subsystem,
      sectionCount: sections.length,
      symbolCount: symbols.length,
      fileSizeBytes: bytes.length,
      sha256: sha256Digest,
    );

    return _ParsedData(header: header, sections: sections, symbols: symbols);
  }

  // --- ELF Binary Parser ---
  _ParsedData _parseElfBinary(Uint8List bytes, String sha256Digest) {
    final byteData = ByteData.sublistView(bytes);
    int bitness = 64;
    TargetArch arch = TargetArch.amd64;
    String machineType = 'x86_64';
    int entryPoint = 0;
    int imageBase = 0x400000;
    final List<ExecutableSection> sections = [];
    final List<ExecutableSymbol> symbols = [];

    try {
      if (bytes.length >= 52) {
        final elfClass = bytes[4];
        bitness = (elfClass == 1) ? 32 : 64;
        final endianCode = bytes[5];
        final isLittleEndian = endianCode == 1;
        final endian = isLittleEndian ? Endian.little : Endian.big;

        final machine = byteData.getUint16(18, endian);
        switch (machine) {
          case 0x3E:
            arch = TargetArch.amd64;
            machineType = 'Advanced Micro Devices X86-64';
            break;
          case 0x03:
            arch = TargetArch.i386;
            machineType = 'Intel 80386';
            bitness = 32;
            break;
          case 0xB7:
            arch = TargetArch.arm64;
            machineType = 'ARM AArch64';
            break;
          case 0x28:
            arch = TargetArch.arm32;
            machineType = 'ARM 32-bit';
            bitness = 32;
            break;
          case 0xF3:
            arch = TargetArch.riscv64;
            machineType = 'RISC-V 64-bit';
            break;
          default:
            machineType = 'ELF Machine 0x${machine.toRadixString(16)}';
        }

        int shOffset = 0;
        int shEntSize = 0;
        int shNum = 0;
        int shStrNdx = 0;

        if (bitness == 64 && bytes.length >= 64) {
          entryPoint = byteData.getUint64(24, endian);
          shOffset = byteData.getUint64(40, endian);
          shEntSize = byteData.getUint16(58, endian);
          shNum = byteData.getUint16(60, endian);
          shStrNdx = byteData.getUint16(62, endian);
        } else if (bitness == 32) {
          entryPoint = byteData.getUint32(24, endian);
          shOffset = byteData.getUint32(32, endian);
          shEntSize = byteData.getUint16(46, endian);
          shNum = byteData.getUint16(48, endian);
          shStrNdx = byteData.getUint16(50, endian);
        }

        // String table extraction for section names
        Uint8List? strTab;
        if (shStrNdx < shNum && shOffset + (shStrNdx * shEntSize) + shEntSize <= bytes.length) {
          final strHeaderOff = shOffset + (shStrNdx * shEntSize);
          int strOffset = 0;
          int strSize = 0;
          if (bitness == 64) {
            strOffset = byteData.getUint64(strHeaderOff + 24, endian);
            strSize = byteData.getUint64(strHeaderOff + 32, endian);
          } else {
            strOffset = byteData.getUint32(strHeaderOff + 16, endian);
            strSize = byteData.getUint32(strHeaderOff + 20, endian);
          }
          if (strOffset + strSize <= bytes.length) {
            strTab = bytes.sublist(strOffset, strOffset + strSize);
          }
        }

        for (int i = 0; i < shNum; i++) {
          final hOff = shOffset + (i * shEntSize);
          if (hOff + shEntSize <= bytes.length) {
            final nameIdx = byteData.getUint32(hOff, endian);
            String secName = '';
            if (strTab != null && nameIdx < strTab.length) {
              final sub = strTab.sublist(nameIdx);
              secName = String.fromCharCodes(sub.takeWhile((b) => b != 0));
            }
            if (secName.isEmpty) secName = 'sec_$i';

            int flags = 0;
            int addr = 0;
            int offset = 0;
            int size = 0;

            if (bitness == 64) {
              flags = byteData.getUint64(hOff + 8, endian);
              addr = byteData.getUint64(hOff + 16, endian);
              offset = byteData.getUint64(hOff + 24, endian);
              size = byteData.getUint64(hOff + 32, endian);
            } else {
              flags = byteData.getUint32(hOff + 8, endian);
              addr = byteData.getUint32(hOff + 12, endian);
              offset = byteData.getUint32(hOff + 16, endian);
              size = byteData.getUint32(hOff + 20, endian);
            }

            final isWrite = (flags & 0x1) != 0;
            final isAlloc = (flags & 0x2) != 0;
            final isExec = (flags & 0x4) != 0;
            final perms = '${isAlloc ? "r" : "-"}${isWrite ? "w" : "-"}${isExec ? "x" : "-"}';
            final entropy = _calculateEntropy(bytes, offset, size);

            sections.add(
              ExecutableSection(
                name: secName,
                virtualAddress: addr,
                virtualSize: size,
                rawOffset: offset,
                rawSize: size,
                permissions: perms,
                characteristics: flags,
                entropy: entropy,
              ),
            );
          }
        }
      }
    } catch (_) {}

    final header = ExecutableHeader(
      format: ExecutableFormat.elf,
      formatDetail: bitness == 64 ? 'ELF64 (64-bit Linux Executable)' : 'ELF32 (32-bit Linux Executable)',
      arch: arch,
      machineType: machineType,
      bitness: bitness,
      endianness: 'Little-Endian (standard)',
      entryPointAddress: entryPoint,
      imageBase: imageBase,
      subsystem: 'Linux ABI / Freestanding',
      sectionCount: sections.length,
      symbolCount: symbols.length,
      fileSizeBytes: bytes.length,
      sha256: sha256Digest,
    );

    return _ParsedData(header: header, sections: sections, symbols: symbols);
  }

  // --- Mach-O Binary Parser ---
  _ParsedData _parseMachOBinary(Uint8List bytes, String sha256Digest) {
    final byteData = ByteData.sublistView(bytes);
    int bitness = 64;
    TargetArch arch = TargetArch.amd64;
    String machineType = 'x86_64 / ARM64 Mach-O';
    final List<ExecutableSection> sections = [];
    final List<ExecutableSymbol> symbols = [];

    try {
      if (bytes.length >= 32) {
        final magic = byteData.getUint32(0, Endian.little);
        bitness = (magic == 0xFEEDFACF || magic == 0xCFFAEDFE) ? 64 : 32;

        final cpuType = byteData.getUint32(4, Endian.little);
        if (cpuType == 0x01000007) {
          arch = TargetArch.amd64;
          machineType = 'x86_64 (macOS Intel)';
        } else if (cpuType == 0x0100000C) {
          arch = TargetArch.arm64;
          machineType = 'ARM64 (Apple Silicon / M-series)';
        } else if (cpuType == 0x07) {
          arch = TargetArch.i386;
          machineType = 'i386 (macOS 32-bit)';
          bitness = 32;
        }

        final ncmds = byteData.getUint32(16, Endian.little);
        int cmdOffset = (bitness == 64) ? 32 : 28;

        for (int i = 0; i < ncmds; i++) {
          if (cmdOffset + 8 > bytes.length) break;
          final cmd = byteData.getUint32(cmdOffset, Endian.little);
          final cmdSize = byteData.getUint32(cmdOffset + 4, Endian.little);

          // LC_SEGMENT_64 (0x19) or LC_SEGMENT (0x01)
          if (cmd == 0x19 && cmdOffset + 72 <= bytes.length) {
            final segNameBytes = bytes.sublist(cmdOffset + 8, cmdOffset + 24);
            final segName = String.fromCharCodes(segNameBytes.takeWhile((b) => b != 0));
            final vmAddr = byteData.getUint64(cmdOffset + 24, Endian.little);
            final vmSize = byteData.getUint64(cmdOffset + 32, Endian.little);
            final fileOff = byteData.getUint64(cmdOffset + 40, Endian.little);
            final fileSize = byteData.getUint64(cmdOffset + 48, Endian.little);
            final maxProt = byteData.getUint32(cmdOffset + 56, Endian.little);
            final nsects = byteData.getUint32(cmdOffset + 64, Endian.little);

            final isRead = (maxProt & 0x1) != 0;
            final isWrite = (maxProt & 0x2) != 0;
            final isExec = (maxProt & 0x4) != 0;
            final perms = '${isRead ? "r" : "-"}${isWrite ? "w" : "-"}${isExec ? "x" : "-"}';

            sections.add(
              ExecutableSection(
                name: segName.isEmpty ? 'SEG_$i' : segName,
                virtualAddress: vmAddr,
                virtualSize: vmSize,
                rawOffset: fileOff,
                rawSize: fileSize,
                permissions: perms,
                characteristics: maxProt,
                entropy: _calculateEntropy(bytes, fileOff, fileSize),
              ),
            );

            // Subsections
            int sectOffset = cmdOffset + 72;
            for (int s = 0; s < nsects; s++) {
              if (sectOffset + 80 <= bytes.length) {
                final subNameBytes = bytes.sublist(sectOffset, sectOffset + 16);
                final subName = String.fromCharCodes(subNameBytes.takeWhile((b) => b != 0));
                final sAddr = byteData.getUint64(sectOffset + 32, Endian.little);
                final sSize = byteData.getUint64(sectOffset + 40, Endian.little);
                final sOff = byteData.getUint32(sectOffset + 48, Endian.little);

                sections.add(
                  ExecutableSection(
                    name: '$segName.$subName',
                    virtualAddress: sAddr,
                    virtualSize: sSize,
                    rawOffset: sOff,
                    rawSize: sSize,
                    permissions: perms,
                    characteristics: maxProt,
                    entropy: _calculateEntropy(bytes, sOff, sSize),
                  ),
                );
                sectOffset += 80;
              }
            }
          }
          cmdOffset += cmdSize;
        }
      }
    } catch (_) {}

    if (sections.isEmpty) {
      sections.add(
        ExecutableSection(
          name: '__TEXT',
          virtualAddress: 0x100000000,
          virtualSize: bytes.length,
          rawOffset: 0,
          rawSize: bytes.length,
          permissions: 'r-x',
          characteristics: 7,
          entropy: _calculateEntropy(bytes, 0, bytes.length),
        ),
      );
    }

    final header = ExecutableHeader(
      format: ExecutableFormat.macho,
      formatDetail: bitness == 64 ? 'Mach-O 64-bit Binary' : 'Mach-O 32-bit Binary',
      arch: arch,
      machineType: machineType,
      bitness: bitness,
      endianness: 'Little-Endian (Darwin)',
      entryPointAddress: sections.first.virtualAddress,
      imageBase: sections.first.virtualAddress,
      subsystem: 'macOS Darwin Kernel',
      sectionCount: sections.length,
      symbolCount: symbols.length,
      fileSizeBytes: bytes.length,
      sha256: sha256Digest,
    );

    return _ParsedData(header: header, sections: sections, symbols: symbols);
  }

  ExecutableHeader _parseRawBinary(Uint8List bytes, String sha256Digest) {
    return ExecutableHeader(
      format: ExecutableFormat.raw,
      formatDetail: 'Raw Binary Image / Relocatable Object',
      arch: TargetArch.amd64,
      machineType: 'Generic Binary Object',
      bitness: 64,
      endianness: 'Little-Endian',
      entryPointAddress: 0x0000,
      imageBase: 0x0000,
      subsystem: 'Standalone Object',
      sectionCount: 1,
      symbolCount: 0,
      fileSizeBytes: bytes.length,
      sha256: sha256Digest,
    );
  }

  // --- Toolchain Disassembler ---
  Future<List<ExecutableInstruction>> _disassembleWithToolchain(String filePath, TargetArch arch) async {
    final disasmBin = File(llvmObjdumpPath).existsSync() ? llvmObjdumpPath : objdumpPath;
    final args = ['-d', '-M', 'intel', filePath];

    final process = await Process.run(disasmBin, args);
    if (process.exitCode != 0 || process.stdout.toString().trim().isEmpty) {
      throw ProcessException(disasmBin, args, process.stderr.toString(), process.exitCode);
    }

    return _parseDisassemblyText(process.stdout.toString());
  }

  List<ExecutableInstruction> _parseDisassemblyText(String output) {
    final instructions = <ExecutableInstruction>[];
    final lines = output.split('\n');
    String? currentFunction;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Function header e.g. "0000000000401000 <main>:"
      final fnMatch = RegExp(r'^[0-9a-fA-F]+\s+<([^>]+)>:').firstMatch(line);
      if (fnMatch != null) {
        currentFunction = fnMatch.group(1);
        final addrStr = line.split(RegExp(r'\s+')).first;
        final addr = int.tryParse(addrStr, radix: 16) ?? 0;
        instructions.add(
          ExecutableInstruction(
            virtualAddress: addr,
            fileOffset: 0,
            hexBytes: '',
            mnemonic: '<$currentFunction>:',
            operands: '',
            functionName: currentFunction,
            isFunctionHeader: true,
          ),
        );
        continue;
      }

      // Instruction line: "  401000: 55                      push   rbp"
      final colonIndex = line.indexOf(':');
      if (colonIndex != -1) {
        final addrPart = line.substring(0, colonIndex).trim();
        if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(addrPart)) {
          final addr = int.tryParse(addrPart, radix: 16) ?? 0;
          final rest = line.substring(colonIndex + 1).trim();

          String hexBytes = '';
          String asmPart = '';

          if (rest.contains('\t')) {
            final parts = rest.split('\t').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
            if (parts.isNotEmpty) {
              hexBytes = parts[0];
              if (parts.length > 1) {
                asmPart = parts.sublist(1).join(' ');
              }
            }
          } else {
            final parts = rest.split(RegExp(r'\s{2,}')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
            if (parts.isNotEmpty) {
              hexBytes = parts[0];
              if (parts.length > 1) {
                asmPart = parts.sublist(1).join(' ');
              }
            }
          }

          if (hexBytes.isNotEmpty) {
            String mnemonic = asmPart;
            String operands = '';
            String comment = '';

            // Separate comments starting with # or //
            final commentIdx = asmPart.indexOf('#');
            if (commentIdx != -1) {
              comment = asmPart.substring(commentIdx + 1).trim();
              asmPart = asmPart.substring(0, commentIdx).trim();
            }

            final firstSpace = asmPart.indexOf(RegExp(r'\s+'));
            if (firstSpace != -1) {
              mnemonic = asmPart.substring(0, firstSpace).trim();
              operands = asmPart.substring(firstSpace).trim();
            }

            instructions.add(
              ExecutableInstruction(
                virtualAddress: addr,
                fileOffset: addrPart.length <= 6 ? addr : 0,
                hexBytes: hexBytes,
                mnemonic: mnemonic,
                operands: operands,
                comment: comment,
                functionName: currentFunction,
                isFunctionHeader: false,
              ),
            );
          }
        }
      }
    }

    return instructions;
  }

  Future<List<ExecutableSymbol>> _extractSymbolsFromToolchain(String filePath) async {
    final symBin = File(llvmObjdumpPath).existsSync() ? llvmObjdumpPath : objdumpPath;
    final List<ExecutableSymbol> result = [];

    try {
      final process = await Process.run(symBin, ['-t', filePath]);
      if (process.exitCode == 0) {
        final lines = process.stdout.toString().split('\n');
        for (final line in lines) {
          final parts = line.trim().split(RegExp(r'\s+'));
          if (parts.length >= 6) {
            final addrStr = parts[0];
            if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(addrStr)) {
              final addr = int.tryParse(addrStr, radix: 16) ?? 0;
              final name = parts.last;
              final flags = parts[1];
              final isFunc = line.contains(' F ') || flags.contains('F') || line.contains('.text');
              final isExported = flags.contains('g');
              final secName = parts.length >= 4 ? parts[3] : '.text';

              if (name.isNotEmpty && !name.startsWith('.') && !name.startsWith('*')) {
                result.add(
                  ExecutableSymbol(
                    name: name,
                    virtualAddress: addr,
                    sectionName: secName,
                    type: isFunc ? SymbolType.function : SymbolType.data,
                    isExported: isExported,
                  ),
                );
              }
            }
          }
        }
      }
    } catch (_) {}

    return result;
  }

  List<ExecutableInstruction> _fallbackDisassembly(Uint8List bytes, ExecutableHeader header) {
    final instructions = <ExecutableInstruction>[];
    final step = 4;
    final limit = math.min(bytes.length, 1024);

    for (int i = 0; i < limit; i += step) {
      final chunk = bytes.sublist(i, math.min(i + step, bytes.length));
      final hex = chunk.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      instructions.add(
        ExecutableInstruction(
          virtualAddress: header.imageBase + i,
          fileOffset: i,
          hexBytes: hex,
          mnemonic: 'db / raw_data',
          operands: hex,
          functionName: i == 0 ? '_entry' : null,
          isFunctionHeader: i == 0,
        ),
      );
    }
    return instructions;
  }

  // --- Entropy Calculation ---
  double _calculateEntropy(Uint8List bytes, int offset, int length) {
    if (length <= 0 || offset >= bytes.length) return 0.0;
    final actualLen = math.min(length, bytes.length - offset);
    if (actualLen <= 0) return 0.0;

    final freq = List<int>.filled(256, 0);
    for (int i = 0; i < actualLen; i++) {
      freq[bytes[offset + i]]++;
    }

    double entropy = 0.0;
    for (int i = 0; i < 256; i++) {
      if (freq[i] > 0) {
        final p = freq[i] / actualLen;
        entropy -= p * (math.log(p) / math.ln2);
      }
    }
    return entropy;
  }

  // --- Binary Patching & Export ---
  ExecutableBinary applyPatch(ExecutableBinary binary, BinaryPatch patch) {
    final newBytes = Uint8List.fromList(binary.byteBuffer);

    if (patch.fileOffset + patch.patchedBytes.length <= newBytes.length) {
      newBytes.setRange(
        patch.fileOffset,
        patch.fileOffset + patch.patchedBytes.length,
        patch.patchedBytes,
      );
    }

    final updatedPatches = List<BinaryPatch>.from(binary.patches)..add(patch);

    // Update instruction lines matching offset
    final updatedInstructions = binary.instructions.map((insn) {
      if (insn.fileOffset == patch.fileOffset || insn.virtualAddress == patch.virtualAddress) {
        final newHex = patch.patchedBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
        return ExecutableInstruction(
          virtualAddress: insn.virtualAddress,
          fileOffset: insn.fileOffset,
          hexBytes: newHex,
          mnemonic: patch.patchedAsm.isNotEmpty ? patch.patchedAsm.split(' ').first : insn.mnemonic,
          operands: patch.patchedAsm.contains(' ') ? patch.patchedAsm.substring(patch.patchedAsm.indexOf(' ') + 1) : insn.operands,
          comment: 'Patched (was: ${insn.mnemonic} ${insn.operands})',
          functionName: insn.functionName,
          isFunctionHeader: insn.isFunctionHeader,
          isPatched: true,
          rawBytes: patch.patchedBytes,
        );
      }
      return insn;
    }).toList();

    return binary.copyWith(
      byteBuffer: newBytes,
      instructions: updatedInstructions,
      patches: updatedPatches,
    );
  }

  Future<void> exportBinary(ExecutableBinary binary, String outputPath) async {
    final file = File(outputPath);
    await file.writeAsBytes(binary.byteBuffer);
  }
}

class _ParsedData {
  final ExecutableHeader header;
  final List<ExecutableSection> sections;
  final List<ExecutableSymbol> symbols;

  _ParsedData({
    required this.header,
    required this.sections,
    required this.symbols,
  });
}
