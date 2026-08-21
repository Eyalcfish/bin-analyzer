import 'package:flutter/material.dart';
import '../models/cpu_capability.dart';
import '../models/instruction_doc.dart';
import '../screens/docs_screen.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../widgets/instruction_detail_dialog.dart';
import '../widgets/tag_badge.dart';

/// Centralized utility for looking up and displaying instruction and ISA documentation.
class InstructionInspector {
  InstructionInspector._();

  static String extractMnemonic(String rawLineOrToken) {
    String trimmed = rawLineOrToken.trim();
    if (trimmed.isEmpty) return '';

    // Strip comments
    for (final delimiter in ['#', '//', ';']) {
      final idx = trimmed.indexOf(delimiter);
      if (idx != -1) {
        trimmed = trimmed.substring(0, idx).trim();
      }
    }

    // Strip labels / directives
    if (trimmed.endsWith(':')) trimmed = trimmed.substring(0, trimmed.length - 1).trim();
    if (trimmed.startsWith('.')) trimmed = trimmed.substring(1).trim();

    // Extract first token (the mnemonic)
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : '';
  }

  static Future<void> inspectInstruction(
    BuildContext context,
    String rawToken, {
    TargetArch? arch,
  }) async {
    final mnemonic = extractMnemonic(rawToken);
    if (mnemonic.isEmpty) return;

    final db = DatabaseService();
    final doc = await db.lookupInstruction(mnemonic, arch: arch);

    if (!context.mounted) return;

    if (doc != null) {
      showDialog(
        context: context,
        builder: (_) => InstructionDetailDialog(doc: doc),
      );
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.base,
          content: Text(
            'No specification found for "$mnemonic" in local database.',
            style: const TextStyle(color: AppColors.text),
          ),
          action: SnackBarAction(
            label: 'Search Docs',
            textColor: AppColors.blue,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DocsScreen()),
              );
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  static void openHardwareDocsForFeature(
    BuildContext context, {
    required TargetArch arch,
    required String featureName,
    String? featureId,
    String? flag,
  }) {
    String? targetIsa;
    if (featureId != null) {
      if (featureId.startsWith('avx512')) {
        targetIsa = 'AVX512F';
      } else if (featureId == 'avx2') {
        targetIsa = 'AVX2';
      } else if (featureId == 'avx') {
        targetIsa = 'AVX';
      } else if (featureId == 'fma') {
        targetIsa = 'FMA';
      } else if (featureId == 'bmi2') {
        targetIsa = 'BMI2';
      } else if (featureId == 'bmi1') {
        targetIsa = 'BMI1';
      } else if (featureId == 'popcnt') {
        targetIsa = 'POPCNT';
      } else if (featureId == 'neon') {
        targetIsa = 'ARMv8-A NEON';
      } else if (featureId == 'sve' || featureId == 'sve2') {
        targetIsa = 'ARM SVE';
      } else if (featureId == 'dotprod') {
        targetIsa = 'ARMv8.2-A DotProd';
      } else if (featureId == 'lse') {
        targetIsa = 'ARMv8.1-A LSE';
      } else if (featureId == 'rvv') {
        targetIsa = 'RV64GCV';
      } else if (featureId == 'zbb') {
        targetIsa = 'RV64GCB';
      } else if (featureId == 'sse4_2' || featureId.startsWith('sse')) {
        targetIsa = 'SSE4.2';
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocsScreen(
          initialArch: arch,
          initialIsa: targetIsa ?? featureName,
        ),
      ),
    );
  }

  static Future<void> showIsaInstructionsDialog(
    BuildContext context,
    String isaName,
    TargetArch arch, {
    String? featureName,
    String? featureId,
    String? flag,
  }) async {
    final db = DatabaseService.instance;
    final instructions = await db.getInstructionsByIsa(
      isaName,
      arch: arch,
      featureId: featureId,
      flag: flag,
    );

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.base,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 700,
          height: 560,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.menu_book, color: AppColors.blue, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          featureName != null ? '$featureName ($isaName)' : '$isaName Instructions',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          '${instructions.length} instruction(s) for ${arch.name}',
                          style: const TextStyle(fontSize: 12, color: AppColors.subtext0),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.subtext0),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(color: AppColors.surface0, height: 20),

              // Instructions List
              Expanded(
                child: instructions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.info_outline, color: AppColors.overlay0, size: 36),
                            const SizedBox(height: 8),
                            Text(
                              'No specific documentation entries tagged "$isaName" yet.',
                              style: const TextStyle(color: AppColors.subtext0),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: AppColors.mantle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.surface0),
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: instructions.length,
                          separatorBuilder: (_, __) => const Divider(color: AppColors.surface0, height: 1),
                          itemBuilder: (context, index) {
                            final doc = instructions[index];
                            return ListTile(
                              dense: true,
                              title: Row(
                                children: [
                                  Container(
                                    width: 90,
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.crust,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppColors.blue.withOpacity(0.4)),
                                    ),
                                    child: Text(
                                      doc.mnemonic,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        color: AppColors.blue,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      doc.summary,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: AppColors.text, fontSize: 12),
                                    ),
                                  ),
                                  TagBadge(doc.category, color: AppColors.mauve),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Syntax: ${doc.mnemonic} ${doc.operands}  |  Encoding: ${doc.opcodeEncoding}',
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.subtext0),
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right, color: AppColors.surface2, size: 18),
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => InstructionDetailDialog(doc: doc),
                                );
                              },
                            );
                          },
                        ),
                      ),
              ),

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open Hardware Docs Screen'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.blue),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DocsScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
