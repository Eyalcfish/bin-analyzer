import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/cpu_capability.dart';
import '../models/executable_binary.dart';
import '../models/lab_experiment.dart';
import '../services/lab_execution_service.dart';

class LabProvider extends ChangeNotifier {
  final LabExecutionService _executionService = LabExecutionService.instance;

  LabSnippet? _baselineSnippet;
  late LabSnippet _modifiedSnippet;

  final Map<String, BigInt> _initialRegisters = {};

  LabExecutionResult? _baselineExecution;
  LabExecutionResult? _modifiedExecution;
  LabBenchmarkResult? _benchmarkResult;

  bool _isExecuting = false;
  bool _isBenchmarking = false;
  String? _errorMessage;

  // Selected format display in Register View ('hex', 'dec', 'signed_dec', 'bin', 'ascii')
  String _registerDisplayFormat = 'hex';

  // Benchmark iteration settings
  int _benchmarkIterations = 100000;

  // Getters
  LabSnippet? get baselineSnippet => _baselineSnippet;
  LabSnippet get modifiedSnippet => _modifiedSnippet;
  Map<String, BigInt> get initialRegisters => Map.unmodifiable(_initialRegisters);
  LabExecutionResult? get baselineExecution => _baselineExecution;
  LabExecutionResult? get modifiedExecution => _modifiedExecution;
  LabBenchmarkResult? get benchmarkResult => _benchmarkResult;
  bool get isExecuting => _isExecuting;
  bool get isBenchmarking => _isBenchmarking;
  String? get errorMessage => _errorMessage;
  String get registerDisplayFormat => _registerDisplayFormat;
  int get benchmarkIterations => _benchmarkIterations;

  LabProvider() {
    _loadDefaultDemoSnippet();
  }

  void _loadDefaultDemoSnippet() {
    const defaultAsm = '''
# Example: Fast Arithmetic & Register Modification
# Modify these instructions, set initial registers, and click "Run & Capture"

mov rax, 100
add rax, rcx
imul rax, 3
cmp rax, 500
''';

    final snippet = LabSnippet(
      id: const Uuid().v4().substring(0, 8),
      title: 'Quick Arithmetic Demo',
      description: 'Multiply by 3 and compare to 500',
      type: LabSnippetType.assembly,
      source: LabSnippetSource.manual,
      code: defaultAsm,
      arch: TargetArch.amd64,
      optLevel: OptimizationLevel.O2,
      originDetail: 'Default Starter Snippet',
    );

    _baselineSnippet = snippet;
    _modifiedSnippet = snippet.copyWith();
    _initialRegisters['rcx'] = BigInt.from(25);
  }

  /// Ingest assembly / opcodes directly from C Source Compiler
  void loadFromCompiler({
    required String assemblyCode,
    String? machineCodeHex,
    required TargetArch arch,
    required OptimizationLevel optLevel,
    List<String> cpuFlags = const [],
    String title = 'Compiler Snippet',
  }) {
    // Strip unnecessary file boilerplate/labels if too long, or keep the pure instruction sequence
    final cleanedAsm = _cleanCompilerAssembly(assemblyCode);

    final snippet = LabSnippet(
      id: const Uuid().v4().substring(0, 8),
      title: title,
      description: 'Extracted from C Source Compiler with ${optLevel.flag}',
      type: LabSnippetType.assembly,
      source: LabSnippetSource.cCompiler,
      code: cleanedAsm,
      arch: arch,
      optLevel: optLevel,
      cpuFlags: cpuFlags,
      originDetail: 'From C Source Compiler (${optLevel.flag})',
    );

    _baselineSnippet = snippet;
    _modifiedSnippet = snippet.copyWith();
    _baselineExecution = null;
    _modifiedExecution = null;
    _benchmarkResult = null;
    _errorMessage = null;
    notifyListeners();

    // Auto-run initial baseline capture
    executeBaselineAndModified();
  }

  /// Ingest assembly / opcodes directly from Executable Analyzer
  void loadFromExecutable({
    required String functionName,
    required List<ExecutableInstruction> instructions,
    required String fileName,
    required TargetArch arch,
  }) {
    // Build clean assembly text from instructions (excluding function header and dummy labels)
    final asmBuffer = StringBuffer();
    final hexBuffer = StringBuffer();

    for (final insn in instructions) {
      if (insn.isFunctionHeader) continue;
      // Exclude ret if present so user snippet flows through harness capture safely
      if (insn.mnemonic.toLowerCase() == 'ret' || insn.mnemonic.toLowerCase() == 'retq') {
        continue;
      }
      asmBuffer.writeln('${insn.mnemonic} ${insn.operands}'.trim());
      if (insn.hexBytes.isNotEmpty) {
        hexBuffer.write('${insn.hexBytes} ');
      }
    }

    final codeStr = asmBuffer.toString().trim().isNotEmpty
        ? asmBuffer.toString().trim()
        : 'nop';

    final snippet = LabSnippet(
      id: const Uuid().v4().substring(0, 8),
      title: functionName.isNotEmpty ? '<$functionName>' : 'Disassembled Block',
      description: 'Disassembled instructions from $fileName',
      type: LabSnippetType.assembly,
      source: LabSnippetSource.executableBinary,
      code: codeStr,
      arch: arch,
      originDetail: 'Extracted from $fileName: <$functionName>',
    );

    _baselineSnippet = snippet;
    _modifiedSnippet = snippet.copyWith();
    _baselineExecution = null;
    _modifiedExecution = null;
    _benchmarkResult = null;
    _errorMessage = null;
    notifyListeners();

    // Auto-run initial baseline capture
    executeBaselineAndModified();
  }

  void setSnippetCode(String code) {
    _modifiedSnippet = _modifiedSnippet.copyWith(code: code);
    notifyListeners();
  }

  void setSnippetType(LabSnippetType type) {
    _modifiedSnippet = _modifiedSnippet.copyWith(type: type);
    notifyListeners();
  }

  void setRegisterDisplayFormat(String format) {
    _registerDisplayFormat = format;
    notifyListeners();
  }

  void setBenchmarkIterations(int iters) {
    _benchmarkIterations = iters;
    notifyListeners();
  }

  void setInitialRegister(String name, BigInt value) {
    final cleanName = name.toLowerCase().trim();
    if (value == BigInt.zero) {
      _initialRegisters.remove(cleanName);
    } else {
      _initialRegisters[cleanName] = value;
    }
    notifyListeners();
  }

  void removeInitialRegister(String name) {
    _initialRegisters.remove(name.toLowerCase().trim());
    notifyListeners();
  }

  void clearInitialRegisters() {
    _initialRegisters.clear();
    notifyListeners();
  }

  void resetToBaseline() {
    if (_baselineSnippet != null) {
      _modifiedSnippet = _baselineSnippet!.copyWith();
      notifyListeners();
    }
  }

  /// Run and capture end register state for modified snippet
  Future<void> executeModified() async {
    _isExecuting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _executionService.executeSnippet(
        snippetCode: _modifiedSnippet.code,
        snippetType: _modifiedSnippet.type,
        arch: _modifiedSnippet.arch,
        initialRegisters: _initialRegisters,
        cpuFlags: _modifiedSnippet.cpuFlags,
        optLevel: _modifiedSnippet.optLevel,
      );

      _modifiedExecution = res;
      _isExecuting = false;
      if (!res.success && res.errorMessage != null) {
        _errorMessage = res.errorMessage;
      }
      notifyListeners();
    } catch (e) {
      _isExecuting = false;
      _errorMessage = 'Execution failed: $e';
      notifyListeners();
    }
  }

  /// Run and capture end register state for both baseline and modified snippets
  Future<void> executeBaselineAndModified() async {
    _isExecuting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_baselineSnippet != null) {
        final baseRes = await _executionService.executeSnippet(
          snippetCode: _baselineSnippet!.code,
          snippetType: _baselineSnippet!.type,
          arch: _baselineSnippet!.arch,
          initialRegisters: _initialRegisters,
          cpuFlags: _baselineSnippet!.cpuFlags,
          optLevel: _baselineSnippet!.optLevel,
        );
        _baselineExecution = baseRes;
      }

      final modRes = await _executionService.executeSnippet(
        snippetCode: _modifiedSnippet.code,
        snippetType: _modifiedSnippet.type,
        arch: _modifiedSnippet.arch,
        initialRegisters: _initialRegisters,
        cpuFlags: _modifiedSnippet.cpuFlags,
        optLevel: _modifiedSnippet.optLevel,
      );
      _modifiedExecution = modRes;

      _isExecuting = false;
      if (!modRes.success && modRes.errorMessage != null) {
        _errorMessage = modRes.errorMessage;
      }
      notifyListeners();
    } catch (e) {
      _isExecuting = false;
      _errorMessage = 'Execution failed: $e';
      notifyListeners();
    }
  }

  /// Run high-precision benchmark comparing baseline and modified snippets
  Future<void> runBenchmark() async {
    _isBenchmarking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      double? baseAvgNs;
      double? baseAvgCycles;

      if (_baselineSnippet != null && _baselineSnippet!.code.trim().isNotEmpty) {
        try {
          final baseBench = await _executionService.benchmarkSnippet(
            snippetCode: _baselineSnippet!.code,
            snippetType: _baselineSnippet!.type,
            arch: _baselineSnippet!.arch,
            iterations: _benchmarkIterations,
            initialRegisters: _initialRegisters,
            cpuFlags: _baselineSnippet!.cpuFlags,
            optLevel: _baselineSnippet!.optLevel,
          );
          baseAvgNs = baseBench.avgDurationNs;
          baseAvgCycles = baseBench.avgCycles;
        } catch (_) {
          // If baseline benchmark had an issue, continue running the active modified benchmark
        }
      }

      final modBench = await _executionService.benchmarkSnippet(
        snippetCode: _modifiedSnippet.code,
        snippetType: _modifiedSnippet.type,
        arch: _modifiedSnippet.arch,
        iterations: _benchmarkIterations,
        initialRegisters: _initialRegisters,
        cpuFlags: _modifiedSnippet.cpuFlags,
        optLevel: _modifiedSnippet.optLevel,
        baselineAvgDurationNs: baseAvgNs,
        baselineAvgCycles: baseAvgCycles,
      );

      _benchmarkResult = modBench;
      _isBenchmarking = false;
      notifyListeners();
    } catch (e) {
      _isBenchmarking = false;
      _errorMessage = 'Benchmark error: $e';
      notifyListeners();
    }
  }

	String _cleanCompilerAssembly(String rawAsm) {
		final lines = rawAsm.split('\n');
		final out = <String>[];
		for (final line in lines) {
			final trimmed = line.trim();
			if (trimmed.startsWith('.') && !trimmed.endsWith(':')) continue; // Skip directives like .file, .ident
			if (trimmed.startsWith('#') && !trimmed.startsWith('# User')) continue; // Skip comment lines
			if (trimmed.isEmpty) continue;
			out.add(line);
		}
		return out.join('\n');
	}
}
