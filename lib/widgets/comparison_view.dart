import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cpu_capability.dart';
import '../providers/explorer_provider.dart';
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
            color: Color(0xFF181825),
            border: Border(bottom: BorderSide(color: Color(0xFF313244))),
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
                        color: const Color(0xFF1E1E2E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF89B4FA).withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.looks_one, color: Color(0xFF89B4FA), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Target A: ${provider.arch.name} (${provider.optLevel.flag})',
                                  style: const TextStyle(
                                    color: Color(0xFFCDD6F4),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'Flags: ${provider.activeCpuFlags.isEmpty ? "Default" : provider.activeCpuFlags.join(" ")}',
                                  style: const TextStyle(color: Color(0xFFA6ADC8), fontSize: 11),
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
                    child: Icon(Icons.compare_arrows, color: Color(0xFFF9E2AF), size: 24),
                  ),

                  // Target B Config Controls
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF38BA8).withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.looks_two, color: Color(0xFFF38BA8), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      const Text('Target B: ', style: TextStyle(color: Color(0xFFCDD6F4), fontSize: 12)),
                                      // Arch Dropdown
                                      DropdownButton<TargetArch>(
                                        value: provider.compareArch,
                                        isDense: true,
                                        underline: const SizedBox(),
                                        dropdownColor: const Color(0xFF1E1E2E),
                                        style: const TextStyle(color: Color(0xFFF38BA8), fontSize: 12, fontWeight: FontWeight.bold),
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
                                        dropdownColor: const Color(0xFF1E1E2E),
                                        style: const TextStyle(color: Color(0xFFA6E3A1), fontSize: 12, fontWeight: FontWeight.bold),
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
                                        icon: const Icon(Icons.memory, color: Color(0xFF89B4FA), size: 14),
                                        label: Text(
                                          provider.compareFeatureIds.isEmpty
                                              ? 'Set CPU Flags'
                                              : '${provider.compareFeatureIds.length} CPU Flags',
                                          style: const TextStyle(color: Color(0xFF89B4FA), fontSize: 11),
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
                                          style: const TextStyle(color: Color(0xFFA6ADC8), fontSize: 11),
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

              // Metrics comparison row
              if (resultA != null && resultB != null && resultA.success && resultB.success) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                child: _buildPane(
                  title: 'Target A (${provider.arch.id.toUpperCase()} ${provider.optLevel.flag})',
                  result: resultA,
                  isLoading: provider.isCompiling,
                  headerColor: const Color(0xFF89B4FA),
                ),
              ),
              const VerticalDivider(color: Color(0xFF313244), width: 1),
              // Target B Pane
              Expanded(
                child: _buildPane(
                  title: 'Target B (${provider.compareArch.id.toUpperCase()} ${provider.compareOptLevel.flag})',
                  result: resultB,
                  isLoading: provider.isCompareCompiling,
                  headerColor: const Color(0xFFF38BA8),
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
        ? const Color(0xFFA6ADC8)
        : (isReduction ? const Color(0xFFA6E3A1) : const Color(0xFFF9E2AF));

    return Row(
      children: [
        Text('$label: ', style: const TextStyle(color: Color(0xFFA6ADC8), fontSize: 11)),
        Text(valA, style: const TextStyle(color: Color(0xFF89B4FA), fontWeight: FontWeight.bold, fontSize: 11)),
        const Text('  vs  ', style: TextStyle(color: Color(0xFF585B70), fontSize: 11)),
        Text(valB, style: const TextStyle(color: Color(0xFFF38BA8), fontWeight: FontWeight.bold, fontSize: 11)),
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

  Widget _buildPane({
    required String title,
    required dynamic result,
    required bool isLoading,
    required Color headerColor,
  }) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (result == null) {
      return const Center(
        child: Text('No result', style: TextStyle(color: Color(0xFF6C7086))),
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
              result.stderr.toString(),
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFFF38BA8),
                fontSize: 11,
              ),
            ),
          ),
        ),
      );
    }

    final asm = (result.filteredAssembly as String).isNotEmpty
        ? result.filteredAssembly as String
        : result.rawAssembly as String;
    final lines = asm.split('\n');

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: const Color(0xFF181825),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(color: headerColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const Spacer(),
              Text(
                '${lines.length} lines | ${result.codeSizeBytes} B',
                style: const TextStyle(color: Color(0xFF6C7086), fontSize: 11),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFF11111B),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
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
                                  color: Color(0xFF45475A),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              line,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: line.trim().endsWith(':') ? const Color(0xFFF9E2AF) : const Color(0xFFCDD6F4),
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
      ],
    );
  }
}
