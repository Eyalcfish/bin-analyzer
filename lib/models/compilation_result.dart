import 'cpu_capability.dart';

class MachineInstruction {
  final String offset;
  final String hexBytes;
  final String mnemonic;
  final String operands;
  final String fullText;
  final bool isHeader;
  final String? functionName;

  MachineInstruction({
    required this.offset,
    required this.hexBytes,
    required this.mnemonic,
    required this.operands,
    required this.fullText,
    this.isHeader = false,
    this.functionName,
  });
}

class CompilationResult {
  final bool success;
  final String rawAssembly;
  final String filteredAssembly;
  final List<MachineInstruction> instructions;
  final String rawDisassembly;
  final String hexDump;
  final String commandExecuted;
  final String stdout;
  final String stderr;
  final int exitCode;
  final int durationMs;
  final int codeSizeBytes;
  final int instructionCount;
  final TargetArch arch;
  final OptimizationLevel optLevel;
  final List<String> appliedFlags;

  CompilationResult({
    required this.success,
    required this.rawAssembly,
    required this.filteredAssembly,
    required this.instructions,
    required this.rawDisassembly,
    required this.hexDump,
    required this.commandExecuted,
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.durationMs,
    required this.codeSizeBytes,
    required this.instructionCount,
    required this.arch,
    required this.optLevel,
    required this.appliedFlags,
  });

  factory CompilationResult.failure({
    required String commandExecuted,
    required String stderr,
    required String stdout,
    required int exitCode,
    required int durationMs,
    required TargetArch arch,
    required OptimizationLevel optLevel,
    required List<String> appliedFlags,
  }) {
    return CompilationResult(
      success: false,
      rawAssembly: '',
      filteredAssembly: '',
      instructions: [],
      rawDisassembly: '',
      hexDump: '',
      commandExecuted: commandExecuted,
      stdout: stdout,
      stderr: stderr,
      exitCode: exitCode,
      durationMs: durationMs,
      codeSizeBytes: 0,
      instructionCount: 0,
      arch: arch,
      optLevel: optLevel,
      appliedFlags: appliedFlags,
    );
  }
}
