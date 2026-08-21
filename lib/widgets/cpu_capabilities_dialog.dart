import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cpu_capability.dart';
import '../providers/explorer_provider.dart';

class CpuCapabilitiesDialog extends StatelessWidget {
  final bool isComparison;

  const CpuCapabilitiesDialog({super.key, this.isComparison = false});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExplorerProvider>();
    final arch = isComparison ? provider.compareArch : provider.arch;
    final selectedIds = isComparison ? provider.compareFeatureIds : provider.selectedFeatureIds;

    // Filter features for current arch
    final availableFeatures = CpuCapabilitiesData.allFeatures
        .where((f) => f.applicableArchs.contains(arch))
        .toList();

    // Group features by category
    final Map<String, List<CpuFeature>> grouped = {};
    for (final feat in availableFeatures) {
      grouped.putIfAbsent(feat.category, () => []).add(feat);
    }

    // Filter presets for current arch
    final availablePresets = CpuCapabilitiesData.presets
        .where((p) => p.arch == arch)
        .toList();

    return Dialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 800,
        height: 680,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.memory, color: Color(0xFF89B4FA), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CPU Capabilities & ISA Extensions (${arch.name})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFCDD6F4),
                        ),
                      ),
                      Text(
                        isComparison
                            ? 'Configure hardware extensions for Comparison Target'
                            : 'Select hardware instruction set extensions (AVX-512, AVX2, NEON, etc.)',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFA6ADC8),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFFA6ADC8)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: Color(0xFF313244), height: 24),

            // Quick Presets
            if (availablePresets.isNotEmpty) ...[
              const Text(
                'QUICK PRESETS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Color(0xFF89B4FA),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    backgroundColor: const Color(0xFF313244),
                    label: const Text('None (Generic)', style: TextStyle(color: Color(0xFFCDD6F4), fontSize: 12)),
                    onPressed: () {
                      if (isComparison) {
                        provider.compareFeatureIds.clear();
                        provider.compileComparison();
                      } else {
                        provider.clearCpuFeatures();
                      }
                    },
                  ),
                  ...availablePresets.map((preset) {
                    return ActionChip(
                      backgroundColor: const Color(0xFF313244),
                      avatar: const Icon(Icons.bolt, color: Color(0xFFF9E2AF), size: 16),
                      label: Text(
                        preset.name,
                        style: const TextStyle(color: Color(0xFFCDD6F4), fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      onPressed: () {
                        if (isComparison) {
                          provider.compareFeatureIds.clear();
                          provider.compareFeatureIds.addAll(preset.featureIds);
                          provider.compileComparison();
                        } else {
                          provider.applyCpuPreset(preset);
                        }
                      },
                    );
                  }),
                ],
              ),
              const SizedBox(height: 16),
            ],

            const Text(
              'INSTRUCTION SET EXTENSIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Color(0xFF89B4FA),
              ),
            ),
            const SizedBox(height: 8),

            // Scrollable feature list
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF181825),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF313244)),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: grouped.entries.map((entry) {
                    final category = entry.key;
                    final features = entry.value;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Text(
                            category.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFF38BA8),
                            ),
                          ),
                        ),
                        ...features.map((feat) {
                          final isSelected = selectedIds.contains(feat.id);
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            child: Material(
                              color: isSelected ? const Color(0xFF313244) : Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                                side: BorderSide(
                                  color: isSelected ? const Color(0xFF89B4FA) : const Color(0xFF2A2B3D),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: CheckboxListTile(
                                dense: true,
                                value: isSelected,
                                activeColor: const Color(0xFF89B4FA),
                                checkColor: const Color(0xFF11111B),
                                onChanged: (val) {
                                  if (isComparison) {
                                    provider.toggleCompareCpuFeature(feat.id);
                                  } else {
                                    provider.toggleCpuFeature(feat.id);
                                  }
                                },
                                title: Row(
                                  children: [
                                    Text(
                                      feat.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected ? const Color(0xFFCDD6F4) : const Color(0xFFA6ADC8),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF11111B),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        feat.flag,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                          color: Color(0xFFA6E3A1),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    feat.description,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF6C7086)),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${selectedIds.length} capability flag(s) active: ${isComparison ? provider.compareActiveCpuFlags.join(' ') : provider.activeCpuFlags.join(' ')}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFFA6E3A1),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF89B4FA),
                    foregroundColor: const Color(0xFF11111B),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text('Apply & Close', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
