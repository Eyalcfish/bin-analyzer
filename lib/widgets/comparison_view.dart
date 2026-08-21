import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/compilation_result.dart';
import '../models/cpu_capability.dart';
import '../providers/explorer_provider.dart';
import '../theme/app_colors.dart';
import 'cpu_capabilities_dialog.dart';

class ComparisonView extends StatelessWidget {
  const ComparisonView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExplorerProvider>();
    final resultA = provider.result;
    final resultB = provider.compareResult;

    return Column(
      children: [
        // Comparison Header & Controls
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: AppColors.mantle,
            border: Border(bottom: BorderSide(color: AppColors.surface0)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Target A Summary Chip
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.base,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.blue.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.looks_one, color: AppColors.blue, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Target A: ${provider.arch.name} (${provider.optLevel.flag})',
                                  style: const TextStyle(
                                    color: AppColors.text,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'Flags: ${provider.activeCpuFlags.isEmpty ? "Default" : provider.activeCpuFlags.join(" ")}',
                                  style: const TextStyle(color: AppColors.subtext0, fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.compare_arrows, color: AppColors.yellow, size: 24),
                  ),

                  // Target B Config Controls
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.base,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.red.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.looks_two, color: AppColors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      const Text('Target B: ', style: TextStyle(color: AppColors.text, fontSize: 12)),
                                      // Arch Dropdown
                                      DropdownButton<TargetArch>(
                                        value: provider.compareArch,
                                        isDense: true,
                                        underline: const SizedBox(),
                                        dropdownColor: AppColors.base,
                                        style: const TextStyle(color: AppColors.red, fontSize: 12, fontWeight: FontWeight.bold),
                                        items: TargetArch.values.map((a) {
                                          return DropdownMenuItem(value: a, child: Text(a.name));
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) provider.setCompareArch(val);
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      // Opt Dropdown
                                      DropdownButton<OptimizationLevel>(
                                        value: provider.compareOptLevel,
                                        isDense: true,
                                        underline: const SizedBox(),
                                        dropdownColor: AppColors.base,
                                        style: const TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.bold),
                                        items: OptimizationLevel.values.map((o) {
                                          return DropdownMenuItem(value: o, child: Text(o.flag));
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) provider.setCompareOptLevel(val);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: const Icon(Icons.memory, color: AppColors.blue, size: 14),
                                        label: Text(
                                          provider.compareFeatureIds.isEmpty
                                              ? 'Set CPU Flags'
                                              : '${provider.compareFeatureIds.length} CPU Flags',
                                          style: const TextStyle(color: AppColors.blue, fontSize: 11),
                                        ),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (_) => const CpuCapabilitiesDialog(isComparison: true),
                                          );
                                        },
                                      ),
                                      if (provider.compareActiveCpuFlags.isNotEmpty) ...[
                                        const SizedBox(width: 4),
                                        Text(
                                          provider.compareActiveCpuFlags.join(' '),
                                          style: const TextStyle(color: AppColors.subtext0, fontSize: 11),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Metrics comparison row (Wrap avoids overflow on narrow screen)
              if (resultA != null && resultB != null && resultA.success && resultB.success) ...[
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.spaceAround,
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _buildDeltaBadge(
                      label: 'Code Size (.text)',
                      valA: '${resultA.codeSizeBytes} B',
                      valB: '${resultB.codeSizeBytes} B',
                      delta: resultB.codeSizeBytes - resultA.codeSizeBytes,
                      isBytes: true,
                    ),
                    _buildDeltaBadge(
                      label: 'Instructions',
                      valA: '${resultA.instructionCount}',
                      valB: '${resultB.instructionCount}',
                      delta: resultB.instructionCount - resultA.instructionCount,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Dual Pane Disassembly / Assembly Viewer
        Expanded(
          child: Row(
            children: [
              // Target A Pane
              Expanded(
                child: ComparisonPane(
                  title: 'Target A (${provider.arch.id.toUpperCase()} ${provider.optLevel.flag})',
                  result: resultA,
                  isLoading: provider.isCompiling,
                  headerColor: AppColors.blue,
                ),
              ),
              const VerticalDivider(color: AppColors.surface0, width: 1),
              // Target B Pane
              Expanded(
                child: ComparisonPane(
                  title: 'Target B (${provider.compareArch.id.toUpperCase()} ${provider.compareOptLevel.flag})',
                  result: resultB,
                  isLoading: provider.isCompareCompiling,
                  headerColor: AppColors.red,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeltaBadge({
    required String label,
    required String valA,
    required String valB,
    required int delta,
    bool isBytes = false,
  }) {
    final isReduction = delta < 0;
    final color = delta == 0
        ? AppColors.subtext0
        : (isReduction ? AppColors.green : AppColors.yellow);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(color: AppColors.subtext0, fontSize: 11)),
        Text(valA, style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.bold, fontSize: 11)),
        const Text('  vs  ', style: TextStyle(color: AppColors.surface2, fontSize: 11)),
        Text(valB, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.bold, fontSize: 11)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            delta == 0 ? 'Equal' : '${delta > 0 ? "+$delta" : "$delta"} ${isBytes ? "B" : ""}',
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class ComparisonPane extends StatefulWidget {
  final String title;
  final CompilationResult? result;
  final bool isLoading;
  final Color headerColor;

  const ComparisonPane({
    super.key,
    required this.title,
    required this.result,
    required this.isLoading,
    required this.headerColor,
  });

  @override
  State<ComparisonPane> createState() => _ComparisonPaneState();
}

class _ComparisonPaneState extends State<ComparisonPane> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.blue));
    }

    final result = widget.result;
    if (result == null) {
      return const Center(
        child: Text('No result', style: TextStyle(color: AppColors.overlay0)),
      );
    }

    if (!result.success) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              result.stderr,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: AppColors.red,
                fontSize: 11,
              ),
            ),
          ),
        ),
      );
    }

    final asm = result.filteredAssembly.isNotEmpty
        ? result.filteredAssembly
        : result.rawAssembly;
    final lines = asm.split('\n');

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: AppColors.mantle,
          child: Row(
            children: [
              Text(
                widget.title,
                style: TextStyle(color: widget.headerColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const Spacer(),
              Text(
                '${lines.length} lines | ${result.codeSizeBytes} B',
                style: const TextStyle(color: AppColors.overlay0, fontSize: 11),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: AppColors.crust,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return RawScrollbar(
                  controller: _horizontalController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  thumbColor: AppColors.surface1,
                  trackColor: AppColors.mantle,
                  thickness: 10,
                  radius: const Radius.circular(5),
                  notificationPredicate: (n) => n.depth == 0,
                  child: SingleChildScrollView(
                    controller: _horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                        minHeight: constraints.maxHeight,
                      ),
                      child: RawScrollbar(
                        controller: _verticalController,
                        thumbVisibility: true,
                        trackVisibility: true,
                        thumbColor: AppColors.surface1,
                        trackColor: AppColors.mantle,
                        thickness: 8,
                        radius: const Radius.circular(4),
                        notificationPredicate: (n) => n.depth == 0,
                        child: SingleChildScrollView(
                          controller: _verticalController,
                          scrollDirection: Axis.vertical,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: SelectionArea(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: List.generate(lines.length, (index) {
                                final line = lines[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 32,
                                        child: Text(
                                          '${index + 1}',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            color: AppColors.surface1,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        line,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          color: line.trim().endsWith(':') ? AppColors.yellow : AppColors.text,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
