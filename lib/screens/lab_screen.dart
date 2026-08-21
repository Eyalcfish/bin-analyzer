import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/cpu_capability.dart';
import '../models/lab_experiment.dart';
import '../providers/lab_provider.dart';
import '../theme/app_colors.dart';

class LabScreen extends StatefulWidget {
  final VoidCallback? onSwitchToCodeExplorer;
  final VoidCallback? onSwitchToExecutableAnalyzer;

  const LabScreen({
    super.key,
    this.onSwitchToCodeExplorer,
    this.onSwitchToExecutableAnalyzer,
  });

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> with SingleTickerProviderStateMixin {
  late TabController _rightTabController;
  late TextEditingController _codeController;

  @override
  void initState() {
    super.initState();
    _rightTabController = TabController(length: 3, vsync: this);
    final provider = context.read<LabProvider>();
    _codeController = TextEditingController(text: provider.modifiedSnippet.code);
  }

  @override
  void dispose() {
    _rightTabController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LabProvider>();

    // Synchronize controller if snippet changed externally (e.g. sent from compiler/analyzer)
    if (_codeController.text != provider.modifiedSnippet.code && !provider.isExecuting && !provider.isBenchmarking) {
      _codeController.text = provider.modifiedSnippet.code;
    }

    return Scaffold(
      backgroundColor: AppColors.crust,
      body: SafeArea(
        child: Column(
          children: [
            // Top Toolbar
            _buildTopToolbar(context, provider),

            // Error Banner if present
            if (provider.errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.red.withOpacity(0.2),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: AppColors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        provider.errorMessage!,
                        style: const TextStyle(color: AppColors.red, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            // Main Split Workspace
            Expanded(
              child: Row(
                children: [
                  // Left Pane: Snippet Editor & Initial Register State
                  Expanded(
                    flex: 5,
                    child: _buildLeftEditorPanel(context, provider),
                  ),

                  // Divider
                  Container(width: 2, color: AppColors.surface0),

                  // Right Pane: Verification & Benchmark Results
                  Expanded(
                    flex: 6,
                    child: _buildRightInspectionPanel(context, provider),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Top Toolbar ---
  Widget _buildTopToolbar(BuildContext context, LabProvider provider) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.mantle,
        border: Border(bottom: BorderSide(color: AppColors.surface0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // App Title
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.peach.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.science, color: AppColors.peach, size: 18),
                ),
                const SizedBox(width: 8),
                const Text(
                  'BinAnalyzer',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text),
                ),
              ],
            ),
            const SizedBox(width: 16),

            // 3-Way Mode Switcher
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.base,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.surface0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModeTabButton(
                    title: 'C Source Compiler',
                    icon: Icons.code,
                    isSelected: false,
                    onTap: () {
                      if (widget.onSwitchToCodeExplorer != null) {
                        widget.onSwitchToCodeExplorer!();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  _buildModeTabButton(
                    title: 'Executable Analyzer',
                    icon: Icons.biotech,
                    isSelected: false,
                    onTap: () {
                      if (widget.onSwitchToExecutableAnalyzer != null) {
                        widget.onSwitchToExecutableAnalyzer!();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  _buildModeTabButton(
                    title: 'The Lab (Workbench)',
                    icon: Icons.science,
                    isSelected: true,
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Snippet Origin Detail Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surface0,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.surface1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    provider.modifiedSnippet.source == LabSnippetSource.cCompiler
                        ? Icons.code
                        : (provider.modifiedSnippet.source == LabSnippetSource.executableBinary
                            ? Icons.biotech
                            : Icons.edit_note),
                    size: 14,
                    color: AppColors.mauve,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    provider.modifiedSnippet.originDetail,
                    style: const TextStyle(color: AppColors.subtext0, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Reset to Baseline
            if (provider.baselineSnippet != null)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.subtext0,
                  side: const BorderSide(color: AppColors.surface1),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                icon: const Icon(Icons.restore, size: 14),
                label: const Text('Reset to Baseline', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  provider.resetToBaseline();
                  _codeController.text = provider.modifiedSnippet.code;
                },
              ),

            const SizedBox(width: 12),

            // Run & Capture Registers Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: AppColors.base,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              ),
              icon: provider.isExecuting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.base))
                  : const Icon(Icons.play_arrow, size: 18),
              label: const Text('Run & Capture Registers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: provider.isExecuting
                  ? null
                  : () {
                      provider.setSnippetCode(_codeController.text);
                      provider.executeBaselineAndModified();
                    },
            ),

            const SizedBox(width: 10),

            // Benchmark Button with Iterations
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.surface0,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.yellow.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, size: 14, color: AppColors.yellow),
                  const SizedBox(width: 6),
                  DropdownButton<int>(
                    value: provider.benchmarkIterations,
                    underline: const SizedBox(),
                    dropdownColor: AppColors.mantle,
                    isDense: true,
                    style: const TextStyle(color: AppColors.yellow, fontSize: 11, fontWeight: FontWeight.bold),
                    items: const [
                      DropdownMenuItem(value: 10000, child: Text('10K iters')),
                      DropdownMenuItem(value: 100000, child: Text('100K iters')),
                      DropdownMenuItem(value: 1000000, child: Text('1M iters')),
                    ],
                    onChanged: (val) {
                      if (val != null) provider.setBenchmarkIterations(val);
                    },
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.yellow,
                      foregroundColor: AppColors.base,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: provider.isBenchmarking
                        ? null
                        : () {
                            provider.setSnippetCode(_codeController.text);
                            provider.runBenchmark();
                            _rightTabController.animateTo(1); // switch to Benchmark tab
                          },
                    child: provider.isBenchmarking
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.base))
                        : const Text('Benchmark', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Left Pane: Editor & Initial Registers ---
  Widget _buildLeftEditorPanel(BuildContext context, LabProvider provider) {
    return Column(
      children: [
        // Editor Header Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: AppColors.mantle,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Icon(Icons.edit_note, size: 16, color: AppColors.peach),
                const SizedBox(width: 8),
                const Text(
                  'Snippet Editor (Modify Instructions)',
                  style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(width: 16),
                // Snippet Type Toggle (Assembly vs Machine Code)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.base,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.surface0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTypeChip(
                        label: 'Assembly (.s)',
                        isSelected: provider.modifiedSnippet.type == LabSnippetType.assembly,
                        onTap: () => provider.setSnippetType(LabSnippetType.assembly),
                      ),
                      _buildTypeChip(
                        label: 'Machine Code (Hex)',
                        isSelected: provider.modifiedSnippet.type == LabSnippetType.machineCodeHex,
                        onTap: () => provider.setSnippetType(LabSnippetType.machineCodeHex),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Code Editor Input Field
        Expanded(
          flex: 6,
          child: Container(
            color: AppColors.base,
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _codeController,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: AppColors.text,
                height: 1.4,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Enter assembly instructions (e.g. mov rax, 10; add rax, rbx)...',
                hintStyle: TextStyle(color: AppColors.surface2),
              ),
              onChanged: (val) => provider.setSnippetCode(val),
            ),
          ),
        ),

        // Initial Registers Setup Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          color: AppColors.mantle,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Icon(Icons.input, size: 14, color: AppColors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Initial Register Setup (Inputs)',
                  style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.add, size: 14, color: AppColors.green),
                  label: const Text('Set Register', style: TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => _showAddRegisterDialog(context, provider),
                ),
                if (provider.initialRegisters.isNotEmpty)
                  TextButton(
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), visualDensity: VisualDensity.compact),
                    onPressed: () => provider.clearInitialRegisters(),
                    child: const Text('Clear All', style: TextStyle(color: AppColors.red, fontSize: 11)),
                  ),
              ],
            ),
          ),
        ),

        // Initial Registers Chips List
        Container(
          height: 70,
          color: AppColors.crust,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: provider.initialRegisters.isEmpty
              ? const Center(
                  child: Text(
                    'No initial registers set (all registers default to 0x0). Click "Set Register" to inject initial inputs.',
                    style: TextStyle(color: AppColors.surface2, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: provider.initialRegisters.entries.map((entry) {
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface0,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.blue.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              entry.key.toUpperCase(),
                              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppColors.blue, fontSize: 12),
                            ),
                            const Text(' = ', style: TextStyle(color: AppColors.surface2, fontSize: 12)),
                            Text(
                              '0x${entry.value.toRadixString(16).toUpperCase()}',
                              style: const TextStyle(fontFamily: 'monospace', color: AppColors.yellow, fontSize: 11),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => provider.removeInitialRegister(entry.key),
                              child: const Icon(Icons.close, size: 12, color: AppColors.subtext0),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  // --- Right Pane: Verification & Benchmark Results ---
  Widget _buildRightInspectionPanel(BuildContext context, LabProvider provider) {
    return Column(
      children: [
        // Tab Bar
        Container(
          height: 42,
          decoration: const BoxDecoration(
            color: AppColors.mantle,
            border: Border(bottom: BorderSide(color: AppColors.surface0)),
          ),
          child: TabBar(
            controller: _rightTabController,
            isScrollable: true,
            indicatorColor: AppColors.peach,
            indicatorWeight: 3,
            labelColor: AppColors.peach,
            unselectedLabelColor: AppColors.subtext0,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            tabs: const [
              Tab(icon: Icon(Icons.fact_check, size: 16), text: 'End Register State (Verification)'),
              Tab(icon: Icon(Icons.speed, size: 16), text: 'Benchmarking & Timing'),
              Tab(icon: Icon(Icons.data_array, size: 16), text: 'SIMD / Vector Registers'),
            ],
          ),
        ),

        // Tab View
        Expanded(
          child: TabBarView(
            controller: _rightTabController,
            children: [
              _buildRegisterVerificationView(context, provider),
              _buildBenchmarkTimingView(context, provider),
              _buildSimdRegistersView(context, provider),
            ],
          ),
        ),
      ],
    );
  }

  // 1. Register Verification View
  Widget _buildRegisterVerificationView(BuildContext context, LabProvider provider) {
    final modRes = provider.modifiedExecution;
    final baseRes = provider.baselineExecution;

    if (modRes == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_circle_outline, size: 48, color: AppColors.surface2),
            const SizedBox(height: 12),
            const Text(
              'Click "Run & Capture Registers" to execute the snippet and inspect post-execution register state.',
              style: TextStyle(color: AppColors.subtext0, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: AppColors.base),
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('Run & Capture Registers', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                provider.setSnippetCode(_codeController.text);
                provider.executeBaselineAndModified();
              },
            ),
          ],
        ),
      );
    }

    final gprs = ['rax', 'rbx', 'rcx', 'rdx', 'rsi', 'rdi', 'rbp', 'rsp', 'r8', 'r9', 'r10', 'r11', 'r12', 'r13', 'r14', 'r15'];

    return Column(
      children: [
        // Display Format Selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          color: AppColors.surface0,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Format: ', style: TextStyle(color: AppColors.subtext0, fontSize: 11, fontWeight: FontWeight.bold)),
                _buildFormatChip('Hex', 'hex', provider),
                _buildFormatChip('Decimal', 'dec', provider),
                _buildFormatChip('Signed', 'signed_dec', provider),
                _buildFormatChip('Binary', 'bin', provider),
                _buildFormatChip('ASCII', 'ascii', provider),
                const SizedBox(width: 16),
                Text(
                  'Execution: ${modRes.durationUs} µs',
                  style: const TextStyle(color: AppColors.yellow, fontSize: 11, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ),

        // RFLAGS Status Flags Card
        Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface0,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.surface1),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('RFLAGS: ', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.mauve)),
                Text(
                  '0x${modRes.registers.rflags.toRadixString(16).toUpperCase()}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.yellow),
                ),
                const SizedBox(width: 14),
                _buildFlagBadge('ZF', modRes.registers.zf),
                _buildFlagBadge('CF', modRes.registers.cf),
                _buildFlagBadge('SF', modRes.registers.sf),
                _buildFlagBadge('OF', modRes.registers.of),
                _buildFlagBadge('PF', modRes.registers.pf),
                _buildFlagBadge('AF', modRes.registers.af),
                _buildFlagBadge('DF', modRes.registers.df),
              ],
            ),
          ),
        ),

        // GPR Grid
        Expanded(
          child: ListView.builder(
            itemCount: gprs.length,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemBuilder: (context, index) {
              final reg = gprs[index];
              final modVal = modRes.registers.gpr[reg] ?? BigInt.zero;
              final baseVal = baseRes?.registers.gpr[reg];
              final isChanged = baseVal != null && baseVal != modVal;

              String displayVal;
              switch (provider.registerDisplayFormat) {
                case 'dec':
                  displayVal = modRes.registers.formatGprDec(reg);
                  break;
                case 'signed_dec':
                  displayVal = modRes.registers.formatGprSignedDec(reg);
                  break;
                case 'bin':
                  displayVal = modRes.registers.formatGprBin(reg);
                  break;
                case 'ascii':
                  displayVal = modRes.registers.formatGprAscii(reg);
                  break;
                default:
                  displayVal = modRes.registers.formatGprHex(reg);
              }

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isChanged ? AppColors.peach.withOpacity(0.12) : (index % 2 == 0 ? AppColors.base : AppColors.mantle),
                  borderRadius: BorderRadius.circular(4),
                  border: isChanged ? const Border(left: BorderSide(color: AppColors.peach, width: 3)) : null,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text(
                        reg.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isChanged ? AppColors.peach : AppColors.blue,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        displayVal,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.text),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isChanged) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.peach.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Modified (was: 0x${baseVal.toRadixString(16).toUpperCase()})',
                          style: const TextStyle(color: AppColors.peach, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 2. Benchmarking & Timing View
  Widget _buildBenchmarkTimingView(BuildContext context, LabProvider provider) {
    final bench = provider.benchmarkResult;

    if (bench == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_outlined, size: 48, color: AppColors.surface2),
            const SizedBox(height: 12),
            const Text(
              'Run a high-precision benchmark across 10K, 100K, or 1M iterations to measure latency & speedup.',
              style: TextStyle(color: AppColors.subtext0, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.yellow, foregroundColor: AppColors.base),
              icon: const Icon(Icons.speed, size: 16),
              label: const Text('Run Benchmark', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                provider.setSnippetCode(_codeController.text);
                provider.runBenchmark();
              },
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metrics Cards Row
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Average Latency',
                  value: '${bench.avgDurationNs.toStringAsFixed(2)} ns',
                  subtitle: '${bench.avgCycles.toStringAsFixed(1)} cycles / op',
                  icon: Icons.timer,
                  color: AppColors.yellow,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Throughput',
                  value: '${(bench.opsPerSecond / 1e6).toStringAsFixed(1)} Mops/s',
                  subtitle: '${bench.iterations} iterations in ${bench.totalDurationMs.toStringAsFixed(1)} ms',
                  icon: Icons.bolt,
                  color: AppColors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Speedup Card vs Baseline
          if (bench.speedupRatio != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface0,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: bench.speedupRatio! >= 1.0 ? AppColors.green : AppColors.red),
              ),
              child: Row(
                children: [
                  Icon(
                    bench.speedupRatio! >= 1.0 ? Icons.trending_up : Icons.trending_down,
                    color: bench.speedupRatio! >= 1.0 ? AppColors.green : AppColors.red,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bench.speedupRatio! >= 1.0
                            ? '${bench.speedupRatio!.toStringAsFixed(2)}x Faster (${bench.speedupPercent!.toStringAsFixed(1)}% speedup)'
                            : '${(1.0 / bench.speedupRatio!).toStringAsFixed(2)}x Slower',
                        style: TextStyle(
                          color: bench.speedupRatio! >= 1.0 ? AppColors.green : AppColors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Baseline: ${bench.baselineAvgDurationNs?.toStringAsFixed(2)} ns/op  →  Modified: ${bench.avgDurationNs.toStringAsFixed(2)} ns/op',
                        style: const TextStyle(color: AppColors.subtext0, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 3. SIMD / Vector Registers View
  Widget _buildSimdRegistersView(BuildContext context, LabProvider provider) {
    final modRes = provider.modifiedExecution;

    if (modRes == null) {
      return const Center(
        child: Text('Run the snippet to inspect 256-bit SIMD YMM/XMM vector registers.', style: TextStyle(color: AppColors.subtext0)),
      );
    }

    return ListView.builder(
      itemCount: 16,
      padding: const EdgeInsets.all(10),
      itemBuilder: (context, index) {
        final ymmName = 'ymm$index';
        final hexStr = modRes.registers.getYmmHex(ymmName);
        final floats = modRes.registers.getYmmAsFloats(ymmName);
        final isZero = hexStr.replaceAll('0', '').replaceAll(' ', '').isEmpty;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isZero ? AppColors.base : AppColors.surface0,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isZero ? AppColors.surface0 : AppColors.mauve.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    ymmName.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isZero ? AppColors.subtext0 : AppColors.mauve,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '256-bit Vector',
                    style: TextStyle(fontSize: 10, color: AppColors.subtext0.withOpacity(0.6)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                hexStr,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.yellow),
              ),
              if (!isZero) ...[
                const SizedBox(height: 4),
                Text(
                  'Float32x8: [${floats.map((f) => f.toStringAsFixed(2)).join(', ')}]',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppColors.green),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // --- Helpers & Widgets ---
  Widget _buildModeTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface0 : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? AppColors.peach : AppColors.subtext0),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppColors.text : AppColors.subtext0,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.peach : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.base : AppColors.subtext0,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildFormatChip(String label, String formatKey, LabProvider provider) {
    final isSelected = provider.registerDisplayFormat == formatKey;
    return InkWell(
      onTap: () => provider.setRegisterDisplayFormat(formatKey),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.peach : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.base : AppColors.subtext0,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildFlagBadge(String flagName, bool isSet) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isSet ? AppColors.green.withOpacity(0.2) : AppColors.surface1,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isSet ? AppColors.green : Colors.transparent),
      ),
      child: Text(
        '$flagName:${isSet ? "1" : "0"}',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isSet ? AppColors.green : AppColors.subtext0,
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface0,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surface1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: AppColors.subtext0, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppColors.surface2, fontSize: 11)),
        ],
      ),
    );
  }

  void _showAddRegisterDialog(BuildContext context, LabProvider provider) {
    String selectedReg = 'rax';
    final valController = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.mantle,
          title: const Text('Set Initial Register Value', style: TextStyle(color: AppColors.text, fontSize: 14)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedReg,
                dropdownColor: AppColors.base,
                decoration: const InputDecoration(labelText: 'Register'),
                items: ['rax', 'rbx', 'rcx', 'rdx', 'rsi', 'rdi', 'rbp', 'r8', 'r9', 'r10', 'r11', 'r12', 'r13', 'r14', 'r15']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase())))
                    .toList(),
                onChanged: (val) {
                  if (val != null) selectedReg = val;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valController,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  labelText: 'Value (Hex e.g. 0x2A or Dec e.g. 42)',
                  hintText: '0x100 or 42',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: AppColors.base),
              onPressed: () {
                final txt = valController.text.trim();
                BigInt val = BigInt.zero;
                if (txt.startsWith('0x') || txt.startsWith('0X')) {
                  val = BigInt.tryParse(txt.substring(2), radix: 16) ?? BigInt.zero;
                } else {
                  val = BigInt.tryParse(txt) ?? BigInt.zero;
                }
                provider.setInitialRegister(selectedReg, val);
                Navigator.of(ctx).pop();
              },
              child: const Text('Set'),
            ),
          ],
        );
      },
    );
  }
}
