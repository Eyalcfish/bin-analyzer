import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/compilation_result.dart';
import '../models/cpu_capability.dart';

class CompilerService {
  String gccPath = 'C:\\MinGW-64\\bin\\gcc.exe';
  String objdumpPath = 'C:\\MinGW-64\\bin\\objdump.exe';
  String clangPath = 'C:\\MinGW-64\\bin\\clang.exe';
  String llvmObjdumpPath = 'C:\\MinGW-64\\bin\\llvm-objdump.exe';
  bool useWsl = false;
  String wslDistribution = 'Ubuntu';

  CompilerService() {
    _autoDetectPaths();
  }

  void _autoDetectPaths() {
    if (!File(gccPath).existsSync()) {
      gccPath = 'gcc';
    }
    if (!File(objdumpPath).existsSync()) {
      objdumpPath = 'objdump';
    }
    if (!File(clangPath).existsSync()) {
      clangPath = 'clang';
    }
    if (!File(llvmObjdumpPath).existsSync()) {
      llvmObjdumpPath = 'llvm-objdump';
    }
  }

  Future<CompilationResult> compile({
    required String sourceCode,
    required TargetArch arch,
    required OptimizationLevel optLevel,
    List<String> cpuFlags = const [],
    String syntax = 'intel',
    bool cleanDirectives = true,
    String extraFlags = '',
  }) async {
    final stopwatch = Stopwatch()..start();
    final tempDir = Directory.systemTemp.createTempSync('bin_analyzer_');
    final uuid = const Uuid().v4().substring(0, 8);
    final srcFile = File(p.join(tempDir.path, 'input_$uuid.c'));
    final asmFile = File(p.join(tempDir.path, 'output_$uuid.s'));
    final objFile = File(p.join(tempDir.path, 'output_$uuid.o'));

    try {
      await srcFile.writeAsString(sourceCode);

      final isX86 = arch == TargetArch.amd64 || arch == TargetArch.i386;
      final compilerBin = isX86 ? gccPath : clangPath;
      final objdumpBin = isX86 ? objdumpPath : llvmObjdumpPath;

      final List<String> baseFlags = [];

      // Architecture flags
      if (arch == TargetArch.amd64) {
        baseFlags.add('-m64');
      } else if (arch == TargetArch.i386) {
        baseFlags.add('-m32');
      } else if (arch == TargetArch.arm64) {
        baseFlags.add('--target=aarch64-linux-gnu');
      } else if (arch == TargetArch.arm32) {
        baseFlags.add('--target=armv7-linux-gnueabihf');
      } else if (arch == TargetArch.riscv64) {
        baseFlags.add('--target=riscv64-linux-gnu');
      }

      // Optimization level
      baseFlags.add(optLevel.flag);

      // CPU Capability flags
      baseFlags.addAll(cpuFlags);

      // Extra user flags
      if (extraFlags.trim().isNotEmpty) {
        final parsedExtras = extraFlags.trim().split(RegExp(r'\s+'));
        baseFlags.addAll(parsedExtras);
      }

      // 1. Generate Assembly (.s)
      final List<String> asmArgs = List.from(baseFlags);
      if (isX86) {
        asmArgs.add(syntax == 'intel' ? '-masm=intel' : '-masm=att');
        asmArgs.add('-fverbose-asm');
      }
      asmArgs.addAll(['-S', srcFile.path, '-o', asmFile.path]);

      final asmCmdStr = '$compilerBin ${asmArgs.join(' ')}';
      final asmProcess = await Process.run(compilerBin, asmArgs);

      if (asmProcess.exitCode != 0) {
        stopwatch.stop();
        return CompilationResult.failure(
          commandExecuted: asmCmdStr,
          stderr: asmProcess.stderr.toString(),
          stdout: asmProcess.stdout.toString(),
          exitCode: asmProcess.exitCode,
          durationMs: stopwatch.elapsedMilliseconds,
          arch: arch,
          optLevel: optLevel,
          appliedFlags: baseFlags,
        );
      }

      String rawAssembly = '';
      if (asmFile.existsSync()) {
        rawAssembly = await asmFile.readAsString();
      }

      final filteredAssembly = _filterAssemblyDirectives(rawAssembly, syntax);

      // 2. Generate Object File (.o)
      final List<String> objArgs = List.from(baseFlags);
      objArgs.addAll(['-c', srcFile.path, '-o', objFile.path]);
      final objCmdStr = '$compilerBin ${objArgs.join(' ')}';
      final objProcess = await Process.run(compilerBin, objArgs);

      if (objProcess.exitCode != 0) {
        stopwatch.stop();
        return CompilationResult.failure(
          commandExecuted: objCmdStr,
          stderr: objProcess.stderr.toString(),
          stdout: objProcess.stdout.toString(),
          exitCode: objProcess.exitCode,
          durationMs: stopwatch.elapsedMilliseconds,
          arch: arch,
          optLevel: optLevel,
          appliedFlags: baseFlags,
        );
      }

      // 3. Run Objdump to disassemble with machine code bytes
      final List<String> dumpArgs = ['-d'];
      if (isX86 && syntax == 'intel') {
        if (objdumpBin.contains('llvm-objdump')) {
          dumpArgs.add('--x86-asm-syntax=intel');
        } else {
          dumpArgs.addAll(['-M', 'intel']);
        }
      }
      dumpArgs.add(objFile.path);

      final dumpCmdStr = '$objdumpBin ${dumpArgs.join(' ')}';
      final dumpProcess = await Process.run(objdumpBin, dumpArgs);

      final rawDisassembly = dumpProcess.stdout.toString();
      final instructions = _parseDisassembly(rawDisassembly);

      // 4. Run Objdump to get full section hex dump (.text)
      final List<String> hexArgs = ['-s', '-j', '.text', objFile.path];
      final hexProcess = await Process.run(objdumpBin, hexArgs);
      final rawHexDump = hexProcess.stdout.toString();

      // Calculate metrics
      int totalCodeSize = 0;
      int instructionCount = 0;

      for (final instr in instructions) {
        if (!instr.isHeader && instr.hexBytes.isNotEmpty) {
          instructionCount++;
          final byteTokens = instr.hexBytes.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
          totalCodeSize += byteTokens.length;
        }
      }

      stopwatch.stop();

      return CompilationResult(
        success: true,
        rawAssembly: rawAssembly,
        filteredAssembly: filteredAssembly,
        instructions: instructions,
        rawDisassembly: rawDisassembly,
        hexDump: rawHexDump,
        commandExecuted: '$asmCmdStr\n$objCmdStr\n$dumpCmdStr',
        stdout: asmProcess.stdout.toString() + dumpProcess.stdout.toString(),
        stderr: asmProcess.stderr.toString(),
        exitCode: 0,
        durationMs: stopwatch.elapsedMilliseconds,
        codeSizeBytes: totalCodeSize,
        instructionCount: instructionCount,
        arch: arch,
        optLevel: optLevel,
        appliedFlags: baseFlags,
      );
    } catch (e, stack) {
      stopwatch.stop();
      return CompilationResult.failure(
        commandExecuted: 'Compilation Exception',
        stderr: 'Error: $e\n$stack',
        stdout: '',
        exitCode: -1,
        durationMs: stopwatch.elapsedMilliseconds,
        arch: arch,
        optLevel: optLevel,
        appliedFlags: [],
      );
    } finally {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  String _filterAssemblyDirectives(String rawAsm, String syntax) {
    final cleanAsm = rawAsm.replaceAll('\r', '');
    final lines = cleanAsm.split('\n');
    final outputLines = <String>[];

    final ignoredDirectivePrefixes = [
      '.file',
      '.def',
      '.scl',
      '.type',
      '.endef',
      '.seh_proc',
      '.seh_endproc',
      '.seh_pushreg',
      '.seh_setframe',
      '.seh_endprologue',
      '.cfi_startproc',
      '.cfi_endproc',
      '.cfi_def_cfa',
      '.cfi_offset',
      '.cfi_restore',
      '.ident',
      '.addrsig',
      '.p2align',
      '.intel_syntax',
      '.att_syntax',
      '.text',
      '.syntax',
      '.eabi_attribute',
      '.fnstart',
      '.fnend',
      '.cantunwind',
      '.section',
    ];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Keep labels like func: or .L1: or .LBB0_1:
      if (trimmed.endsWith(':')) {
        outputLines.add(line);
        continue;
      }

      // Check if it's an ignored assembler directive
      bool isIgnored = false;
      for (final prefix in ignoredDirectivePrefixes) {
        if (trimmed.startsWith(prefix)) {
          isIgnored = true;
          break;
        }
      }

      if (!isIgnored) {
        outputLines.add(line);
      }
    }

    return outputLines.join('\n');
  }

  List<MachineInstruction> _parseDisassembly(String disassembly) {
    final instructions = <MachineInstruction>[];
    final cleanDisasm = disassembly.replaceAll('\r', '');
    final lines = cleanDisasm.split('\n');

    final funcHeaderRegex = RegExp(r'^[0-9a-fA-F]+\s+<(.*)>:$');
    String? currentFunction;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final headerMatch = funcHeaderRegex.firstMatch(line);
      if (headerMatch != null) {
        currentFunction = headerMatch.group(1);
        instructions.add(
          MachineInstruction(
            offset: '',
            hexBytes: '',
            mnemonic: '<$currentFunction>:',
            operands: '',
            fullText: rawLine,
            isHeader: true,
            functionName: currentFunction,
          ),
        );
        continue;
      }

      final colonIndex = line.indexOf(':');
      if (colonIndex != -1) {
        final offsetPart = line.substring(0, colonIndex).trim();
        if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(offsetPart)) {
          final rest = line.substring(colonIndex + 1).trim();
          String hexPart = '';
          String instrPart = '';

          if (rest.contains('\t')) {
            final parts = rest.split('\t').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
            if (parts.isNotEmpty) {
              hexPart = parts[0];
              if (parts.length > 1) {
                instrPart = parts.sublist(1).join(' ');
              }
            }
          } else {
            final parts = rest.split(RegExp(r'\s{2,}')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
            if (parts.isNotEmpty) {
              hexPart = parts[0];
              if (parts.length > 1) {
                instrPart = parts.sublist(1).join(' ');
              }
            }
          }

          if (hexPart.isNotEmpty) {
            final firstSpace = instrPart.indexOf(RegExp(r'\s+'));
            String mnemonic = instrPart;
            String operands = '';

            if (firstSpace != -1) {
              mnemonic = instrPart.substring(0, firstSpace).trim();
              operands = instrPart.substring(firstSpace).trim();
            }

            instructions.add(
              MachineInstruction(
                offset: '0x$offsetPart',
                hexBytes: hexPart,
                mnemonic: mnemonic,
                operands: operands,
                fullText: rawLine,
                isHeader: false,
                functionName: currentFunction,
              ),
            );
          }
        }
      }
    }

    return instructions;
  }
}
