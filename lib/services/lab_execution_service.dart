import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/cpu_capability.dart';
import '../models/lab_experiment.dart';
import 'compiler_service.dart';

class LabExecutionService {
	static final LabExecutionService instance = LabExecutionService._internal();
	LabExecutionService._internal();
	factory LabExecutionService() => instance;

	final CompilerService _compilerService = CompilerService();

	/// Executes an assembly or machine code snippet with optional initial register values,
	/// capturing the exact CPU register state (RAX..R15, RFLAGS, YMM0..YMM15) at completion.
	Future<LabExecutionResult> executeSnippet({
		required String snippetCode,
		required LabSnippetType snippetType,
		required TargetArch arch,
		Map<String, BigInt>? initialRegisters,
		List<String> cpuFlags = const [],
		OptimizationLevel optLevel = OptimizationLevel.O2,
	}) async {
		final stopwatch = Stopwatch()..start();
		final tempDir = Directory.systemTemp.createTempSync('bin_lab_exec_');
		final uuid = const Uuid().v4().substring(0, 8);

		final harnessCFile = File(p.join(tempDir.path, 'harness_$uuid.c'));
		final snippetSFile = File(p.join(tempDir.path, 'snippet_$uuid.s'));
		final runnerExeFile = File(p.join(tempDir.path, 'runner_$uuid.exe'));

		try {
			final asmBody = _formatSnippetAsAssembly(snippetCode, snippetType);
			final assemblySource = _generateAssemblyWrapper(asmBody);
			await snippetSFile.writeAsString(assemblySource);

			final harnessSource = _generateCExecutionHarness(initialRegisters ?? {}, iterations: 1, isBenchmark: false);
			await harnessCFile.writeAsString(harnessSource);

			// Compile harness + assembly with GCC / Clang
			final isX86 = arch == TargetArch.amd64 || arch == TargetArch.i386;
			final compilerBin = isX86 ? _compilerService.gccPath : _compilerService.clangPath;

			final List<String> args = [
				harnessCFile.path,
				snippetSFile.path,
				optLevel.flag,
				'-mavx2', // Enable vector register support in harness
				...cpuFlags,
				'-o',
				runnerExeFile.path,
			];

			if (arch == TargetArch.amd64) {
				args.add('-m64');
			} else if (arch == TargetArch.i386) {
				args.add('-m32');
			}

			final compileProcess = await Process.run(compilerBin, args);
			if (compileProcess.exitCode != 0 || !await runnerExeFile.exists()) {
				stopwatch.stop();
				return LabExecutionResult.failure(
					error: 'Failed to assemble/compile snippet:\n${compileProcess.stderr}',
					stderr: compileProcess.stderr.toString(),
					exitCode: compileProcess.exitCode,
				);
			}

			// Run the compiled harness
			final runProcess = await Process.run(runnerExeFile.path, []).timeout(
				const Duration(seconds: 5),
				onTimeout: () => ProcessResult(-1, -1, '', 'Execution timed out (infinite loop or hang)'),
			);

			stopwatch.stop();

			if (runProcess.exitCode != 0) {
				return LabExecutionResult.failure(
					error: 'Execution failed (exit code ${runProcess.exitCode}):\n${runProcess.stderr}',
					stdout: runProcess.stdout.toString(),
					stderr: runProcess.stderr.toString(),
					exitCode: runProcess.exitCode,
				);
			}

			// Parse JSON output from the C harness
			final stdoutStr = runProcess.stdout.toString();
			final jsonStart = stdoutStr.indexOf('{');
			final jsonEnd = stdoutStr.lastIndexOf('}');

			if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
				final jsonContent = stdoutStr.substring(jsonStart, jsonEnd + 1);
				final parsed = jsonDecode(jsonContent) as Map<String, dynamic>;
				final regState = CpuRegisterState.fromJson(parsed);

				return LabExecutionResult(
					success: true,
					registers: regState,
					stdout: stdoutStr.substring(0, jsonStart).trim(),
					stderr: runProcess.stderr.toString(),
					exitCode: runProcess.exitCode,
					durationUs: stopwatch.elapsedMicroseconds,
				);
			} else {
				return LabExecutionResult.failure(
					error: 'Invalid register output format from runner harness:\n$stdoutStr',
					stdout: stdoutStr,
					stderr: runProcess.stderr.toString(),
				);
			}
		} catch (e) {
			stopwatch.stop();
			return LabExecutionResult.failure(
				error: 'Lab execution error: $e',
			);
		} finally {
			_cleanupTempDir(tempDir);
		}
	}

	/// High-precision benchmarking across N iterations
	Future<LabBenchmarkResult> benchmarkSnippet({
		required String snippetCode,
		required LabSnippetType snippetType,
		required TargetArch arch,
		int iterations = 100000,
		Map<String, BigInt>? initialRegisters,
		List<String> cpuFlags = const [],
		OptimizationLevel optLevel = OptimizationLevel.O3,
		double? baselineAvgDurationNs,
		double? baselineAvgCycles,
	}) async {
		final tempDir = Directory.systemTemp.createTempSync('bin_lab_bench_');
		final uuid = const Uuid().v4().substring(0, 8);

		final harnessCFile = File(p.join(tempDir.path, 'harness_$uuid.c'));
		final snippetSFile = File(p.join(tempDir.path, 'snippet_$uuid.s'));
		final runnerExeFile = File(p.join(tempDir.path, 'runner_$uuid.exe'));

		try {
			final asmBody = _formatSnippetAsAssembly(snippetCode, snippetType);
			final assemblySource = _generateAssemblyWrapper(asmBody);
			await snippetSFile.writeAsString(assemblySource);

			final harnessSource = _generateCExecutionHarness(initialRegisters ?? {}, iterations: iterations, isBenchmark: true);
			await harnessCFile.writeAsString(harnessSource);

			final isX86 = arch == TargetArch.amd64 || arch == TargetArch.i386;
			final compilerBin = isX86 ? _compilerService.gccPath : _compilerService.clangPath;

			final List<String> args = [
				harnessCFile.path,
				snippetSFile.path,
				optLevel.flag,
				'-mavx2',
				...cpuFlags,
				'-o',
				runnerExeFile.path,
			];

			if (arch == TargetArch.amd64) {
				args.add('-m64');
			}

			final compileProcess = await Process.run(compilerBin, args);
			if (compileProcess.exitCode != 0 || !await runnerExeFile.exists()) {
				throw Exception('Benchmark compilation failed:\n${compileProcess.stderr}');
			}

			final runProcess = await Process.run(runnerExeFile.path, []).timeout(
				const Duration(seconds: 15),
				onTimeout: () => ProcessResult(-1, -1, '', 'Benchmark timed out'),
			);

			if (runProcess.exitCode != 0) {
				throw Exception('Benchmark execution failed:\n${runProcess.stderr}');
			}

			final stdoutStr = runProcess.stdout.toString();
			final jsonStart = stdoutStr.indexOf('{');
			final jsonEnd = stdoutStr.lastIndexOf('}');

			if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
				final jsonContent = stdoutStr.substring(jsonStart, jsonEnd + 1);
				final parsed = jsonDecode(jsonContent) as Map<String, dynamic>;

				final totalMs = (parsed['total_duration_ms'] as num?)?.toDouble() ?? 0.0;
				final avgNs = (parsed['avg_duration_ns'] as num?)?.toDouble() ?? 0.0;
				final avgCycles = (parsed['avg_cycles'] as num?)?.toDouble() ?? 0.0;
				final opsSec = (parsed['ops_per_sec'] as num?)?.toDouble() ?? (avgNs > 0 ? (1e9 / avgNs) : 0.0);

				return LabBenchmarkResult(
					iterations: iterations,
					totalDurationMs: totalMs,
					avgDurationNs: avgNs,
					avgCycles: avgCycles,
					opsPerSecond: opsSec,
					baselineAvgDurationNs: baselineAvgDurationNs,
					baselineAvgCycles: baselineAvgCycles,
				);
			} else {
				throw Exception('Could not parse benchmark output:\n$stdoutStr');
			}
		} finally {
			_cleanupTempDir(tempDir);
		}
	}

	String _formatSnippetAsAssembly(String code, LabSnippetType type) {
		if (type == LabSnippetType.assembly) {
			return code;
		}

		// Convert machine code hex bytes into GNU Assembly .byte directives
		final cleanHex = code.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
		final bytes = <String>[];
		for (int i = 0; i < cleanHex.length; i += 2) {
			if (i + 2 <= cleanHex.length) {
				bytes.add('0x${cleanHex.substring(i, i + 2)}');
			}
		}
		if (bytes.isEmpty) return 'nop';
		return '.byte ${bytes.join(', ')}';
	}

	String _generateAssemblyWrapper(String snippetBody) {
		return '''
.intel_syntax noprefix
.global run_user_snippet

.data
.align 16
g_in_state:    .quad 0
g_out_state:   .quad 0
g_temp_rax:    .quad 0
g_temp_rbx:    .quad 0
g_temp_rflags: .quad 0
g_saved_rsp:   .quad 0
g_saved_rbp:   .quad 0
g_saved_rbx:   .quad 0
g_saved_r12:   .quad 0
g_saved_r13:   .quad 0
g_saved_r14:   .quad 0
g_saved_r15:   .quad 0
g_saved_rsi:   .quad 0
g_saved_rdi:   .quad 0

.text
.align 16
user_snippet_subroutine:
$snippetBody
\tret

.align 16
run_user_snippet:
\t# Save caller state safely
\tmov [rip + g_saved_rsp], rsp
\tmov [rip + g_saved_rbp], rbp
\tmov [rip + g_saved_rbx], rbx
\tmov [rip + g_saved_r12], r12
\tmov [rip + g_saved_r13], r13
\tmov [rip + g_saved_r14], r14
\tmov [rip + g_saved_r15], r15
\tmov [rip + g_saved_rsi], rsi
\tmov [rip + g_saved_rdi], rdi

\t# Save state pointers
\tmov [rip + g_in_state], rcx
\tmov [rip + g_out_state], rdx

\t# Load initial registers from in_state
\tmov rax, [rcx + 0]
\tmov rbx, [rcx + 8]
\tmov rdx, [rcx + 24]
\tmov rsi, [rcx + 32]
\tmov rdi, [rcx + 40]
\tmov rbp, [rcx + 48]
\tmov r8,  [rcx + 64]
\tmov r9,  [rcx + 72]
\tmov r10, [rcx + 80]
\tmov r11, [rcx + 88]
\tmov r12, [rcx + 96]
\tmov r13, [rcx + 104]
\tmov r14, [rcx + 112]
\tmov r15, [rcx + 120]
\tmov rcx, [rcx + 16]

\t# Call snippet as a subroutine
\tcall user_snippet_subroutine

\t# Capture output registers
\tpushfq
\tpop qword ptr [rip + g_temp_rflags]

\tmov [rip + g_temp_rax], rax
\tmov [rip + g_temp_rbx], rbx

\tmov rax, [rip + g_out_state]

\tmov rbx, [rip + g_temp_rax]
\tmov [rax + 0], rbx
\tmov rbx, [rip + g_temp_rbx]
\tmov [rax + 8], rbx
\tmov [rax + 16], rcx
\tmov [rax + 24], rdx
\tmov [rax + 32], rsi
\tmov [rax + 40], rdi
\tmov [rax + 48], rbp
\tmov [rax + 56], rsp
\tmov [rax + 64], r8
\tmov [rax + 72], r9
\tmov [rax + 80], r10
\tmov [rax + 88], r11
\tmov [rax + 96], r12
\tmov [rax + 104], r13
\tmov [rax + 112], r14
\tmov [rax + 120], r15

\tmov rbx, [rip + g_temp_rflags]
\tmov [rax + 128], rbx

\tvmovdqu [rax + 136 + 0*32], ymm0
\tvmovdqu [rax + 136 + 1*32], ymm1
\tvmovdqu [rax + 136 + 2*32], ymm2
\tvmovdqu [rax + 136 + 3*32], ymm3
\tvmovdqu [rax + 136 + 4*32], ymm4
\tvmovdqu [rax + 136 + 5*32], ymm5
\tvmovdqu [rax + 136 + 6*32], ymm6
\tvmovdqu [rax + 136 + 7*32], ymm7
\tvmovdqu [rax + 136 + 8*32], ymm8
\tvmovdqu [rax + 136 + 9*32], ymm9
\tvmovdqu [rax + 136 + 10*32], ymm10
\tvmovdqu [rax + 136 + 11*32], ymm11
\tvmovdqu [rax + 136 + 12*32], ymm12
\tvmovdqu [rax + 136 + 13*32], ymm13
\tvmovdqu [rax + 136 + 14*32], ymm14
\tvmovdqu [rax + 136 + 15*32], ymm15

\t# Restore caller state
\tmov rsp, [rip + g_saved_rsp]
\tmov rbp, [rip + g_saved_rbp]
\tmov rbx, [rip + g_saved_rbx]
\tmov r12, [rip + g_saved_r12]
\tmov r13, [rip + g_saved_r13]
\tmov r14, [rip + g_saved_r14]
\tmov r15, [rip + g_saved_r15]
\tmov rsi, [rip + g_saved_rsi]
\tmov rdi, [rip + g_saved_rdi]

\tret
''';
	}

	String _generateCExecutionHarness(
		Map<String, BigInt> initialRegs, {
		required int iterations,
		required bool isBenchmark,
	}) {
		final inits = StringBuffer();
		for (final entry in initialRegs.entries) {
			final name = entry.key.toLowerCase();
			inits.writeln('\tin_state.$name = 0x${entry.value.toRadixString(16)}ULL;');
		}

		return '''
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <windows.h>
#include <intrin.h>

#pragma pack(push, 1)
typedef struct {
\tuint64_t rax;
\tuint64_t rbx;
\tuint64_t rcx;
\tuint64_t rdx;
\tuint64_t rsi;
\tuint64_t rdi;
\tuint64_t rbp;
\tuint64_t rsp;
\tuint64_t r8;
\tuint64_t r9;
\tuint64_t r10;
\tuint64_t r11;
\tuint64_t r12;
\tuint64_t r13;
\tuint64_t r14;
\tuint64_t r15;
\tuint64_t rflags;
\tuint8_t  ymm[16][32];
} CpuState;
#pragma pack(pop)

static uint8_t scratch_mem_rcx[65536] __attribute__((aligned(64)));
static uint8_t scratch_mem_rdx[65536] __attribute__((aligned(64)));
static uint8_t scratch_mem_r8 [65536] __attribute__((aligned(64)));
static uint8_t scratch_mem_rsi[65536] __attribute__((aligned(64)));
static uint8_t scratch_mem_rdi[65536] __attribute__((aligned(64)));

extern void run_user_snippet(CpuState* in_state, CpuState* out_state);

int main() {
\tCpuState in_state = {0};
\tCpuState out_state = {0};

\t// Provide valid memory buffers for pointer registers by default
\tfor (int i = 0; i < 16384; i++) {
\t\t((float*)scratch_mem_rcx)[i] = (float)(i + 1);
\t\t((float*)scratch_mem_rdx)[i] = (float)((i + 1) * 2);
\t\t((float*)scratch_mem_r8 )[i] = 0.0f;
\t\t((float*)scratch_mem_rsi)[i] = (float)(i + 1);
\t\t((float*)scratch_mem_rdi)[i] = 0.0f;
\t}

\tin_state.rcx = (uint64_t)scratch_mem_rcx;
\tin_state.rdx = (uint64_t)scratch_mem_rdx;
\tin_state.r8  = (uint64_t)scratch_mem_r8;
\tin_state.rsi = (uint64_t)scratch_mem_rsi;
\tin_state.rdi = (uint64_t)scratch_mem_rdi;
\tin_state.r9  = 8ULL;

$inits

\tLARGE_INTEGER freq, start_time, end_time;
\tQueryPerformanceFrequency(&freq);

\tint iters = $iterations;
\tuint64_t start_cycles = 0, end_cycles = 0;

\tif ($isBenchmark) {
\t\t// Warmup
\t\tfor (int i = 0; i < 100; i++) {
\t\t\trun_user_snippet(&in_state, &out_state);
\t\t}

\t\tQueryPerformanceCounter(&start_time);
\t\tstart_cycles = __rdtsc();

\t\tfor (int i = 0; i < iters; i++) {
\t\t\trun_user_snippet(&in_state, &out_state);
\t\t}

\t\tend_cycles = __rdtsc();
\t\tQueryPerformanceCounter(&end_time);

\t\tdouble total_ms = (double)(end_time.QuadPart - start_time.QuadPart) * 1000.0 / (double)freq.QuadPart;
\t\tdouble avg_ns = (total_ms * 1000000.0) / (double)iters;
\t\tdouble avg_cycles = (double)(end_cycles - start_cycles) / (double)iters;
\t\tdouble ops_sec = (double)iters / (total_ms / 1000.0);

\t\tprintf("{\\n");
\t\tprintf("  \\"total_duration_ms\\": %f,\\n", total_ms);
\t\tprintf("  \\"avg_duration_ns\\": %f,\\n", avg_ns);
\t\tprintf("  \\"avg_cycles\\": %f,\\n", avg_cycles);
\t\tprintf("  \\"ops_per_sec\\": %f\\n", ops_sec);
\t\tprintf("}\\n");
\t\treturn 0;
\t}

\t// Single Execution for Register State Capture
\trun_user_snippet(&in_state, &out_state);

\tprintf("{\\n");
\tprintf("  \\"gpr\\": {\\n");
\tprintf("    \\"rax\\": \\"0x%llX\\",\\n", out_state.rax);
\tprintf("    \\"rbx\\": \\"0x%llX\\",\\n", out_state.rbx);
\tprintf("    \\"rcx\\": \\"0x%llX\\",\\n", out_state.rcx);
\tprintf("    \\"rdx\\": \\"0x%llX\\",\\n", out_state.rdx);
\tprintf("    \\"rsi\\": \\"0x%llX\\",\\n", out_state.rsi);
\tprintf("    \\"rdi\\": \\"0x%llX\\",\\n", out_state.rdi);
\tprintf("    \\"rbp\\": \\"0x%llX\\",\\n", out_state.rbp);
\tprintf("    \\"rsp\\": \\"0x%llX\\",\\n", out_state.rsp);
\tprintf("    \\"r8\\": \\"0x%llX\\",\\n", out_state.r8);
\tprintf("    \\"r9\\": \\"0x%llX\\",\\n", out_state.r9);
\tprintf("    \\"r10\\": \\"0x%llX\\",\\n", out_state.r10);
\tprintf("    \\"r11\\": \\"0x%llX\\",\\n", out_state.r11);
\tprintf("    \\"r12\\": \\"0x%llX\\",\\n", out_state.r12);
\tprintf("    \\"r13\\": \\"0x%llX\\",\\n", out_state.r13);
\tprintf("    \\"r14\\": \\"0x%llX\\",\\n", out_state.r14);
\tprintf("    \\"r15\\": \\"0x%llX\\"\\n", out_state.r15);
\tprintf("  },\\n");
\tprintf("  \\"rflags\\": \\"0x%llX\\",\\n", out_state.rflags);
\tprintf("  \\"simd\\": {\\n");
\tfor (int y = 0; y < 16; y++) {
\t\tprintf("    \\"ymm%d\\": \\"", y);
\t\tfor (int b = 0; b < 32; b++) {
\t\t\tprintf("%02X", out_state.ymm[y][b]);
\t\t}
\t\tif (y == 15) {
\t\t\tprintf("\\"\\n");
\t\t} else {
\t\t\tprintf("\\",\\n");
\t\t}
\t}
\tprintf("  }\\n");
\tprintf("}\\n");

\treturn 0;
}
''';
	}

	void _cleanupTempDir(Directory dir) {
		try {
			if (dir.existsSync()) {
				dir.deleteSync(recursive: true);
			}
		} catch (_) {}
	}
}
