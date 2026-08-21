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
  late TextEditingController _baselineCodeController;

  @override
  void initState() {
    super.initState();
    _rightTabController = TabController(length: 3, vsync: this);
    final provider = context.read<LabProvider>();
    _codeController = TextEditingController(text: provider.modifiedSnippet.code);
    _baselineCodeController = TextEditingController(text: provider.baselineSnippet?.code ?? '');
  }

  @override
  void dispose() {
    _rightTabController.dispose();
    _codeController.dispose();
    _baselineCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LabProvider>();

    // Synchronize controllers if snippets changed externally
    if (_codeController.text != provider.modifiedSnippet.code && !provider.isExecuting && !provider.isBenchmarking) {
      _codeController.text = provider.modifiedSnippet.code;
    }
    if (provider.baselineSnippet != null &&
        _baselineCodeController.text != provider.baselineSnippet!.code &&
        !provider.isExecuting &&
        !provider.isBenchmarking) {
      _baselineCodeController.text = provider.baselineSnippet!.code;
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
                    flex: provider.isComparisonMode ? 6 : 5,
                    child: _buildLeftEditorPanel(context, provider),
                  ),

                  // Divider
                  Container(width: 2, color: AppColors.surface0),

                  // Right Pane: Verification & Benchmark Results
                  Expanded(
                    flex: provider.isComparisonMode ? 6 : 6,
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

            // Dual Compare Mode Toggle Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: provider.isComparisonMode ? AppColors.blue : AppColors.surface0,
                foregroundColor: provider.isComparisonMode ? AppColors.base : AppColors.blue,
                side: const BorderSide(color: AppColors.blue),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              icon: Icon(provider.isComparisonMode ? Icons.compare : Icons.splitscreen, size: 15),
              label: Text(
                provider.isComparisonMode ? 'Dual Compare: ON' : 'Dual Compare: OFF',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              onPressed: () {
                provider.toggleComparisonMode();
              },
            ),

            const SizedBox(width: 12),

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

            const SizedBox(width: 12),

            // Reset to Baseline
            if (!provider.isComparisonMode && provider.baselineSnippet != null)
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
              label: Text(
                provider.isComparisonMode ? 'Run Both & Compare' : 'Run & Capture Registers',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              onPressed: provider.isExecuting
                  ? null
                  : () {
                      provider.setSnippetCode(_codeController.text);
                      if (provider.isComparisonMode) {
                        provider.setBaselineCode(_baselineCodeController.text);
                      }
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
                            if (provider.isComparisonMode) {
                              provider.setBaselineCode(_baselineCodeController.text);
                            }
                            provider.runBenchmark();
                            _rightTabController.animateTo(1); // switch to Benchmark tab
                          },
                    child: provider.isBenchmarking
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.base))
                        : Text(
                            provider.isComparisonMode ? 'Benchmark Both' : 'Benchmark',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
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
    if (provider.isComparisonMode) {
      return _buildDualComparisonEditorPanel(context, provider);
    }
    return _buildSingleEditorPanel(context, provider);
  }

  // Single Editor Panel Layout
  Widget _buildSingleEditorPanel(BuildContext context, LabProvider provider) {
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

        // Initial Registers Setup
        _buildInitialRegistersSetup(context, provider),
      ],
    );
  }

  // Dual Comparison Editor Layout (Side-by-Side Code A vs Code B)
  Widget _buildDualComparisonEditorPanel(BuildContext context, LabProvider provider) {
    return Column(
      children: [
        // Dual Editor Sub-Bar with Controls
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: AppColors.mantle,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Icon(Icons.compare_arrows, size: 16, color: AppColors.blue),
                const SizedBox(width: 6),
                const Text('Dual Code Workbench', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.text)),
                const SizedBox(width: 16),
                TextButton.icon(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2)),
                  icon: const Icon(Icons.swap_horiz, size: 14, color: AppColors.peach),
                  label: const Text('Swap A ↔ B', style: TextStyle(color: AppColors.peach, fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    provider.swapSnippets();
                    _baselineCodeController.text = provider.baselineSnippet?.code ?? '';
                    _codeController.text = provider.modifiedSnippet.code;
                  },
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2)),
                  icon: const Icon(Icons.copy, size: 14, color: AppColors.green),
                  label: const Text('Copy A → B', style: TextStyle(color: AppColors.green, fontSize: 11)),
                  onPressed: () {
                    provider.cloneBaselineToModified();
                    _codeController.text = provider.modifiedSnippet.code;
                  },
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2)),
                  icon: const Icon(Icons.copy, size: 14, color: AppColors.mauve),
                  label: const Text('Copy B → A', style: TextStyle(color: AppColors.mauve, fontSize: 11)),
                  onPressed: () {
                    provider.cloneModifiedToBaseline();
                    _baselineCodeController.text = provider.baselineSnippet?.code ?? '';
                  },
                ),
              ],
            ),
          ),
        ),

        // Dual Editors Row
        Expanded(
          flex: 6,
          child: Row(
            children: [
              // Code A (Baseline / Reference)
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      color: AppColors.surface0,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                            child: const Text('Code A (Baseline)', style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                          const Spacer(),
                          _buildTypeChip(
                            label: 'ASM',
                            isSelected: provider.baselineSnippet?.type == LabSnippetType.assembly,
                            onTap: () => provider.setBaselineType(LabSnippetType.assembly),
                          ),
                          const SizedBox(width: 4),
                          _buildTypeChip(
                            label: 'Hex',
                            isSelected: provider.baselineSnippet?.type == LabSnippetType.machineCodeHex,
                            onTap: () => provider.setBaselineType(LabSnippetType.machineCodeHex),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        color: AppColors.base,
                        padding: const EdgeInsets.all(10),
                        child: TextField(
                          controller: _baselineCodeController,
                          maxLines: null,
                          expands: true,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.text, height: 1.35),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Enter Code A (Baseline instructions)...',
                            hintStyle: TextStyle(color: AppColors.surface2, fontSize: 12),
                          ),
                          onChanged: (val) => provider.setBaselineCode(val),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Vertical Divider
              Container(width: 2, color: AppColors.surface0),

              // Code B (Variant / Candidate)
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      color: AppColors.surface0,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.peach.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                            child: const Text('Code B (Variant)', style: TextStyle(color: AppColors.peach, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                          const Spacer(),
                          _buildTypeChip(
                            label: 'ASM',
                            isSelected: provider.modifiedSnippet.type == LabSnippetType.assembly,
                            onTap: () => provider.setSnippetType(LabSnippetType.assembly),
                          ),
                          const SizedBox(width: 4),
                          _buildTypeChip(
                            label: 'Hex',
                            isSelected: provider.modifiedSnippet.type == LabSnippetType.machineCodeHex,
                            onTap: () => provider.setSnippetType(LabSnippetType.machineCodeHex),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        color: AppColors.base,
                        padding: const EdgeInsets.all(10),
                        child: TextField(
                          controller: _codeController,
                          maxLines: null,
                          expands: true,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.text, height: 1.35),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Enter Code B (Candidate instructions)...',
                            hintStyle: TextStyle(color: AppColors.surface2, fontSize: 12),
                          ),
                          onChanged: (val) => provider.setSnippetCode(val),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Initial Registers Setup
        _buildInitialRegistersSetup(context, provider),
      ],
    );
  }

  // Initial Registers Setup Panel (Shared)
  Widget _buildInitialRegistersSetup(BuildContext context, LabProvider provider) {
    return Column(
      children: [
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
                    'No initial registers set (all registers default to 0x0 / safe buffers). Click "Set Register" to inject inputs.',
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

    if (modRes == null && baseRes == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_circle_outline, size: 48, color: AppColors.surface2),
            const SizedBox(height: 12),
            const Text(
              'Click "Run & Capture" to execute snippets and inspect post-execution register state.',
              style: TextStyle(color: AppColors.subtext0, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: AppColors.base),
              icon: const Icon(Icons.play_arrow, size: 16),
              label: Text(
                provider.isComparisonMode ? 'Run Both & Compare' : 'Run & Capture Registers',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                provider.setSnippetCode(_codeController.text);
                if (provider.isComparisonMode) {
                  provider.setBaselineCode(_baselineCodeController.text);
                }
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
        // Display Format Selector & Timings
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
                if (baseRes != null && provider.isComparisonMode)
                  Text(
                    'Code A: ${baseRes.durationUs} µs  |  ',
                    style: const TextStyle(color: AppColors.blue, fontSize: 11, fontFamily: 'monospace'),
                  ),
                if (modRes != null)
                  Text(
                    provider.isComparisonMode ? 'Code B: ${modRes.durationUs} µs' : 'Execution: ${modRes.durationUs} µs',
                    style: const TextStyle(color: AppColors.yellow, fontSize: 11, fontFamily: 'monospace'),
                  ),
              ],
            ),
          ),
        ),

        // RFLAGS Status Flags (Single or Side-by-Side Dual Comparison)
        if (provider.isComparisonMode && baseRes != null && modRes != null) ...[
          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface0,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.surface1),
            ),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text('Code A RFLAGS: ', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.blue)),
                      Text('0x${baseRes.registers.rflags.toRadixString(16).toUpperCase()} ', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.yellow)),
                      _buildFlagBadge('ZF', baseRes.registers.zf),
                      _buildFlagBadge('CF', baseRes.registers.cf),
                      _buildFlagBadge('SF', baseRes.registers.sf),
                      _buildFlagBadge('OF', baseRes.registers.of),
                      _buildFlagBadge('PF', baseRes.registers.pf),
                      _buildFlagBadge('AF', baseRes.registers.af),
                      _buildFlagBadge('DF', baseRes.registers.df),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text('Code B RFLAGS: ', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.peach)),
                      Text('0x${modRes.registers.rflags.toRadixString(16).toUpperCase()} ', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.yellow)),
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
              ],
            ),
          ),
        ] else if (modRes != null) ...[
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
        ],

        // GPR Comparison Table / Grid
        if (provider.isComparisonMode && baseRes != null && modRes != null) ...[
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: AppColors.mantle,
            child: const Row(
              children: [
                SizedBox(width: 50, child: Text('REG', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.subtext0, fontSize: 11))),
                Expanded(child: Text('CODE A (BASELINE)', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.blue, fontSize: 11))),
                Expanded(child: Text('CODE B (VARIANT)', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.peach, fontSize: 11))),
                SizedBox(width: 70, child: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.subtext0, fontSize: 11))),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: gprs.length,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              itemBuilder: (context, index) {
                final reg = gprs[index];
                final baseVal = baseRes.registers.gpr[reg] ?? BigInt.zero;
                final modVal = modRes.registers.gpr[reg] ?? BigInt.zero;
                final isMatch = baseVal == modVal;

                final baseDisplay = _formatRegisterValue(baseRes.registers, reg, provider.registerDisplayFormat);
                final modDisplay = _formatRegisterValue(modRes.registers, reg, provider.registerDisplayFormat);

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: isMatch ? (index % 2 == 0 ? AppColors.base : AppColors.mantle) : AppColors.peach.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: isMatch ? null : const Border(left: BorderSide(color: AppColors.peach, width: 3)),
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
                            fontSize: 11,
                            color: isMatch ? AppColors.subtext0 : AppColors.peach,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          baseDisplay,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.blue),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          modDisplay,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: isMatch ? AppColors.text : AppColors.peach,
                            fontWeight: isMatch ? FontWeight.normal : FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: 70,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: isMatch ? AppColors.green.withOpacity(0.2) : AppColors.peach.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            isMatch ? 'MATCH' : 'DIFF',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isMatch ? AppColors.green : AppColors.peach,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ] else if (modRes != null) ...[
          Expanded(
            child: ListView.builder(
              itemCount: gprs.length,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemBuilder: (context, index) {
                final reg = gprs[index];
                final modVal = modRes.registers.gpr[reg] ?? BigInt.zero;
                final baseVal = baseRes?.registers.gpr[reg];
                final isChanged = baseVal != null && baseVal != modVal;

                final displayVal = _formatRegisterValue(modRes.registers, reg, provider.registerDisplayFormat);

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
      ],
    );
  }

  // Helper to format register value
  String _formatRegisterValue(CpuRegisterState state, String reg, String format) {
    switch (format) {
      case 'dec':
        return state.formatGprDec(reg);
      case 'signed_dec':
        return state.formatGprSignedDec(reg);
      case 'bin':
        return state.formatGprBin(reg);
      case 'ascii':
        return state.formatGprAscii(reg);
      default:
        return state.formatGprHex(reg);
    }
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
              label: Text(
                provider.isComparisonMode ? 'Benchmark Both Head-to-Head' : 'Run Benchmark',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                provider.setSnippetCode(_codeController.text);
                if (provider.isComparisonMode) {
                  provider.setBaselineCode(_baselineCodeController.text);
                }
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
          // Speedup / Winner Banner
          if (bench.speedupRatio != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface0,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: bench.speedupRatio! >= 1.0 ? AppColors.green : AppColors.peach),
              ),
              child: Row(
                children: [
                  Icon(
                    bench.speedupRatio! >= 1.0 ? Icons.bolt : Icons.trending_down,
                    color: bench.speedupRatio! >= 1.0 ? AppColors.green : AppColors.peach,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bench.speedupRatio! >= 1.0
                              ? '⚡ Code B (Variant) is ${bench.speedupRatio!.toStringAsFixed(2)}x Faster (${bench.speedupPercent!.toStringAsFixed(1)}% speedup)'
                              : '⚡ Code A (Baseline) is ${(1.0 / bench.speedupRatio!).toStringAsFixed(2)}x Faster',
                          style: TextStyle(
                            color: bench.speedupRatio! >= 1.0 ? AppColors.green : AppColors.peach,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Code A: ${bench.baselineAvgDurationNs?.toStringAsFixed(2)} ns/op  vs  Code B: ${bench.avgDurationNs.toStringAsFixed(2)} ns/op',
                          style: const TextStyle(color: AppColors.subtext0, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Head-to-Head Comparative Metric Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: provider.isComparisonMode ? 'Code B Latency' : 'Average Latency',
                  value: '${bench.avgDurationNs.toStringAsFixed(2)} ns',
                  subtitle: '${bench.avgCycles.toStringAsFixed(1)} cycles / op',
                  icon: Icons.timer,
                  color: AppColors.yellow,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: provider.isComparisonMode ? 'Code B Throughput' : 'Throughput',
                  value: '${(bench.opsPerSecond / 1e6).toStringAsFixed(1)} Mops/s',
                  subtitle: '${bench.iterations} iters in ${bench.totalDurationMs.toStringAsFixed(1)} ms',
                  icon: Icons.bolt,
                  color: AppColors.green,
                ),
              ),
            ],
          ),

          if (provider.isComparisonMode && bench.baselineAvgDurationNs != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Code A Baseline Latency',
                    value: '${bench.baselineAvgDurationNs!.toStringAsFixed(2)} ns',
                    subtitle: '${bench.baselineAvgCycles?.toStringAsFixed(1) ?? 'N/A'} cycles / op',
                    icon: Icons.history_toggle_off,
                    color: AppColors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Latency Delta',
                    value: '${(bench.avgDurationNs - bench.baselineAvgDurationNs!).toStringAsFixed(2)} ns',
                    subtitle: bench.avgDurationNs < bench.baselineAvgDurationNs! ? 'Reduction in execution time' : 'Increase in execution time',
                    icon: Icons.compare_arrows,
                    color: bench.avgDurationNs <= bench.baselineAvgDurationNs! ? AppColors.green : AppColors.peach,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 3. SIMD / Vector Registers View
  Widget _buildSimdRegistersView(BuildContext context, LabProvider provider) {
    final modRes = provider.modifiedExecution;
    final baseRes = provider.baselineExecution;

    if (modRes == null && baseRes == null) {
      return const Center(
        child: Text('Run the snippets to inspect 256-bit SIMD YMM/XMM vector registers.', style: TextStyle(color: AppColors.subtext0)),
      );
    }

    return ListView.builder(
      itemCount: 16,
      padding: const EdgeInsets.all(10),
      itemBuilder: (context, index) {
        final ymmName = 'ymm$index';
        final hexStrB = modRes?.registers.getYmmHex(ymmName) ?? '00 00 ...';
        final floatsB = modRes?.registers.getYmmAsFloats(ymmName) ?? [];
        final isZeroB = hexStrB.replaceAll('0', '').replaceAll(' ', '').isEmpty;

        final hexStrA = baseRes?.registers.getYmmHex(ymmName);
        final isDiff = hexStrA != null && hexStrA != hexStrB;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDiff ? AppColors.peach.withOpacity(0.1) : (isZeroB ? AppColors.base : AppColors.surface0),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isDiff ? AppColors.peach : (isZeroB ? AppColors.surface0 : AppColors.mauve.withOpacity(0.5))),
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
                      color: isDiff ? AppColors.peach : (isZeroB ? AppColors.subtext0 : AppColors.mauve),
                    ),
                  ),
                  if (isDiff) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.peach.withOpacity(0.2), borderRadius: BorderRadius.circular(3)),
                      child: const Text('DIFF', style: TextStyle(color: AppColors.peach, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '256-bit Vector',
                    style: TextStyle(fontSize: 10, color: AppColors.subtext0.withOpacity(0.6)),
                  ),
                ],
              ),
              if (provider.isComparisonMode && hexStrA != null) ...[
                const SizedBox(height: 4),
                Text(
                  'A: $hexStrA',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppColors.blue),
                ),
                Text(
                  'B: $hexStrB',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppColors.yellow),
                ),
              ] else ...[
                const SizedBox(height: 6),
                Text(
                  hexStrB,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.yellow),
                ),
              ],
              if (!isZeroB && floatsB.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Float32x8: [${floatsB.map((f) => f.toStringAsFixed(2)).join(', ')}]',
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                color: isSelected ? AppColors.peach : AppColors.subtext0,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.peach.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.peach : AppColors.subtext0,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildFormatChip(String label, String formatKey, LabProvider provider) {
    final isSelected = provider.registerDisplayFormat == formatKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? AppColors.base : AppColors.text)),
        selected: isSelected,
        selectedColor: AppColors.peach,
        backgroundColor: AppColors.mantle,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        visualDensity: VisualDensity.compact,
        onSelected: (_) => provider.setRegisterDisplayFormat(formatKey),
      ),
    );
  }

  Widget _buildFlagBadge(String name, bool isSet) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: isSet ? AppColors.green.withOpacity(0.2) : AppColors.surface0,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: isSet ? AppColors.green : AppColors.surface1),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isSet ? AppColors.green : AppColors.surface2,
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.subtext0, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppColors.surface2, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Add Register Dialog ---
  void _showAddRegisterDialog(BuildContext context, LabProvider provider) {
    String selectedReg = 'rax';
    final valController = TextEditingController(text: '0x10');
    final gprs = ['rax', 'rbx', 'rcx', 'rdx', 'rsi', 'rdi', 'rbp', 'rsp', 'r8', 'r9', 'r10', 'r11', 'r12', 'r13', 'r14', 'r15'];

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppColors.mantle,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: const Row(
            children: [
              Icon(Icons.input, size: 18, color: AppColors.blue),
              SizedBox(width: 8),
              Text('Inject Initial Register Value', style: TextStyle(fontSize: 14, color: AppColors.text, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('Register: ', style: TextStyle(color: AppColors.subtext0, fontSize: 12)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: selectedReg,
                    dropdownColor: AppColors.surface0,
                    underline: const SizedBox(),
                    items: gprs.map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase(), style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.blue)))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedReg = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valController,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: AppColors.text),
                decoration: const InputDecoration(
                  labelText: 'Value (Hex e.g. 0x2A or Dec e.g. 42)',
                  labelStyle: TextStyle(color: AppColors.subtext0, fontSize: 11),
                  filled: true,
                  fillColor: AppColors.base,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppColors.subtext0)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue, foregroundColor: AppColors.base),
              onPressed: () {
                final text = valController.text.trim();
                BigInt? parsed;
                if (text.startsWith('0x') || text.startsWith('0X')) {
                  parsed = BigInt.tryParse(text.substring(2), radix: 16);
                } else {
                  parsed = BigInt.tryParse(text);
                }
                if (parsed != null) {
                  provider.setInitialRegister(selectedReg, parsed);
                  Navigator.of(dialogCtx).pop();
                }
              },
              child: const Text('Set Register'),
            ),
          ],
        ),
      ),
    );
  }
}
