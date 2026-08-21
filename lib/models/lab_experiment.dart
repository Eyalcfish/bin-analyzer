import 'dart:typed_data';
import 'cpu_capability.dart';

enum LabSnippetType {
  assembly,
  machineCodeHex,
}

enum LabSnippetSource {
  cCompiler,
  executableBinary,
  manual,
}

class CpuRegisterState {
  final Map<String, BigInt> gpr;
  final BigInt rflags;
  final Map<String, Uint8List> simd; // YMM0 - YMM15 (32 bytes each)
  final BigInt? rip;

  CpuRegisterState({
    required this.gpr,
    required this.rflags,
    required this.simd,
    this.rip,
  });

  factory CpuRegisterState.empty() {
    final defaultGpr = <String, BigInt>{
      'rax': BigInt.zero,
      'rbx': BigInt.zero,
      'rcx': BigInt.zero,
      'rdx': BigInt.zero,
      'rsi': BigInt.zero,
      'rdi': BigInt.zero,
      'rbp': BigInt.zero,
      'rsp': BigInt.zero,
      'r8': BigInt.zero,
      'r9': BigInt.zero,
      'r10': BigInt.zero,
      'r11': BigInt.zero,
      'r12': BigInt.zero,
      'r13': BigInt.zero,
      'r14': BigInt.zero,
      'r15': BigInt.zero,
    };
    final defaultSimd = <String, Uint8List>{
      for (int i = 0; i < 16; i++) 'ymm$i': Uint8List(32),
    };
    return CpuRegisterState(
      gpr: defaultGpr,
      rflags: BigInt.zero,
      simd: defaultSimd,
    );
  }

  factory CpuRegisterState.fromJson(Map<String, dynamic> json) {
    final gprMap = <String, BigInt>{};
    final rawGpr = json['gpr'] as Map<String, dynamic>? ?? {};
    for (final entry in rawGpr.entries) {
      final valStr = entry.value.toString();
      if (valStr.startsWith('0x') || valStr.startsWith('0X')) {
        gprMap[entry.key.toLowerCase()] = BigInt.tryParse(valStr.substring(2), radix: 16) ?? BigInt.zero;
      } else {
        gprMap[entry.key.toLowerCase()] = BigInt.tryParse(valStr) ?? BigInt.zero;
      }
    }

    BigInt flags = BigInt.zero;
    final flagsStr = json['rflags']?.toString() ?? '0';
    if (flagsStr.startsWith('0x') || flagsStr.startsWith('0X')) {
      flags = BigInt.tryParse(flagsStr.substring(2), radix: 16) ?? BigInt.zero;
    } else {
      flags = BigInt.tryParse(flagsStr) ?? BigInt.zero;
    }

    final simdMap = <String, Uint8List>{};
    final rawSimd = json['simd'] as Map<String, dynamic>? ?? {};
    for (final entry in rawSimd.entries) {
      final hexList = entry.value.toString().replaceAll(' ', '').replaceAll(',', '');
      final bytes = <int>[];
      for (int i = 0; i < hexList.length; i += 2) {
        if (i + 2 <= hexList.length) {
          bytes.add(int.tryParse(hexList.substring(i, i + 2), radix: 16) ?? 0);
        }
      }
      simdMap[entry.key.toLowerCase()] = Uint8List.fromList(bytes.length == 32 ? bytes : List<int>.filled(32, 0));
    }

    return CpuRegisterState(
      gpr: gprMap,
      rflags: flags,
      simd: simdMap,
    );
  }

  // RFLAGS bit accessors
  bool get cf => (rflags & (BigInt.one << 0)) != BigInt.zero; // Carry Flag
  bool get pf => (rflags & (BigInt.one << 2)) != BigInt.zero; // Parity Flag
  bool get af => (rflags & (BigInt.one << 4)) != BigInt.zero; // Auxiliary Carry Flag
  bool get zf => (rflags & (BigInt.one << 6)) != BigInt.zero; // Zero Flag
  bool get sf => (rflags & (BigInt.one << 7)) != BigInt.zero; // Sign Flag
  bool get tf => (rflags & (BigInt.one << 8)) != BigInt.zero; // Trap Flag
  bool get ifFlag => (rflags & (BigInt.one << 9)) != BigInt.zero; // Interrupt Enable Flag
  bool get df => (rflags & (BigInt.one << 10)) != BigInt.zero; // Direction Flag
  bool get of => (rflags & (BigInt.one << 11)) != BigInt.zero; // Overflow Flag

  String formatGprHex(String name) {
    final val = gpr[name.toLowerCase()] ?? BigInt.zero;
    return '0x${val.toRadixString(16).toUpperCase().padLeft(16, '0')}';
  }

  String formatGprDec(String name) {
    final val = gpr[name.toLowerCase()] ?? BigInt.zero;
    return val.toString();
  }

  String formatGprSignedDec(String name) {
    final val = gpr[name.toLowerCase()] ?? BigInt.zero;
    final signedVal = val.toSigned(64);
    return signedVal.toString();
  }

  String formatGprBin(String name) {
    final val = gpr[name.toLowerCase()] ?? BigInt.zero;
    return '0b${val.toRadixString(2).padLeft(64, '0')}';
  }

  String formatGprAscii(String name) {
    final val = gpr[name.toLowerCase()] ?? BigInt.zero;
    final hex = val.toRadixString(16).padLeft(16, '0');
    final chars = <String>[];
    for (int i = 0; i < 16; i += 2) {
      final b = int.tryParse(hex.substring(i, i + 2), radix: 16) ?? 0;
      if (b >= 32 && b <= 126) {
        chars.add(String.fromCharCode(b));
      } else {
        chars.add('.');
      }
    }
    return chars.reversed.join(''); // little-endian view
  }

  List<double> getYmmAsFloats(String name) {
    final bytes = simd[name.toLowerCase()];
    if (bytes == null || bytes.length < 32) return List.filled(8, 0.0);
    final byteData = ByteData.sublistView(bytes);
    return List.generate(8, (i) => byteData.getFloat32(i * 4, Endian.little));
  }

  List<int> getYmmAsInt32s(String name) {
    final bytes = simd[name.toLowerCase()];
    if (bytes == null || bytes.length < 32) return List.filled(8, 0);
    final byteData = ByteData.sublistView(bytes);
    return List.generate(8, (i) => byteData.getInt32(i * 4, Endian.little));
  }

  List<BigInt> getYmmAsInt64s(String name) {
    final bytes = simd[name.toLowerCase()];
    if (bytes == null || bytes.length < 32) return List.filled(4, BigInt.zero);
    final byteData = ByteData.sublistView(bytes);
    return List.generate(4, (i) => BigInt.from(byteData.getInt64(i * 8, Endian.little)));
  }

  String getYmmHex(String name) {
    final bytes = simd[name.toLowerCase()];
    if (bytes == null) return '00' * 32;
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase();
  }
}

class LabSnippet {
  final String id;
  final String title;
  final String description;
  final LabSnippetType type;
  final LabSnippetSource source;
  final String code; // Assembly text or Machine Code hex string
  final TargetArch arch;
  final OptimizationLevel optLevel;
  final List<String> cpuFlags;
  final String originDetail; // e.g., "From Executable: <compute_sum> in demo.exe"

  LabSnippet({
    required this.id,
    required this.title,
    this.description = '',
    required this.type,
    required this.source,
    required this.code,
    this.arch = TargetArch.amd64,
    this.optLevel = OptimizationLevel.O2,
    this.cpuFlags = const [],
    this.originDetail = 'Manual Snippet',
  });

  LabSnippet copyWith({
    String? id,
    String? title,
    String? description,
    LabSnippetType? type,
    LabSnippetSource? source,
    String? code,
    TargetArch? arch,
    OptimizationLevel? optLevel,
    List<String> cpuFlags = const [],
    String? originDetail,
  }) {
    return LabSnippet(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      source: source ?? this.source,
      code: code ?? this.code,
      arch: arch ?? this.arch,
      optLevel: optLevel ?? this.optLevel,
      cpuFlags: cpuFlags.isNotEmpty ? cpuFlags : this.cpuFlags,
      originDetail: originDetail ?? this.originDetail,
    );
  }
}

class LabExecutionResult {
  final bool success;
  final CpuRegisterState registers;
  final String stdout;
  final String stderr;
  final int exitCode;
  final int durationUs;
  final String? errorMessage;

  LabExecutionResult({
    required this.success,
    required this.registers,
    this.stdout = '',
    this.stderr = '',
    this.exitCode = 0,
    this.durationUs = 0,
    this.errorMessage,
  });

  factory LabExecutionResult.failure({
    required String error,
    String stdout = '',
    String stderr = '',
    int exitCode = -1,
  }) {
    return LabExecutionResult(
      success: false,
      registers: CpuRegisterState.empty(),
      stdout: stdout,
      stderr: stderr,
      exitCode: exitCode,
      errorMessage: error,
    );
  }
}

class LabBenchmarkResult {
  final int iterations;
  final double totalDurationMs;
  final double avgDurationNs;
  final double avgCycles;
  final double opsPerSecond;
  final double? baselineAvgDurationNs;
  final double? baselineAvgCycles;

  LabBenchmarkResult({
    required this.iterations,
    required this.totalDurationMs,
    required this.avgDurationNs,
    required this.avgCycles,
    required this.opsPerSecond,
    this.baselineAvgDurationNs,
    this.baselineAvgCycles,
  });

  /// Speedup ratio (e.g. 2.45 = 2.45x faster than baseline)
  double? get speedupRatio {
    if (baselineAvgDurationNs != null && baselineAvgDurationNs! > 0 && avgDurationNs > 0) {
      return baselineAvgDurationNs! / avgDurationNs;
    }
    return null;
  }

  /// Percentage speedup (+145% or -20%)
  double? get speedupPercent {
    if (speedupRatio != null) {
      return (speedupRatio! - 1.0) * 100.0;
    }
    return null;
  }
}
