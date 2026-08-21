import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/instruction_doc.dart';
import '../theme/app_colors.dart';
import 'tag_badge.dart';

class InstructionDetailDialog extends StatelessWidget {
  final InstructionDoc doc;
  final VoidCallback? onFilterByIsa;
  final VoidCallback? onFilterByArch;

  const InstructionDetailDialog({
    super.key,
    required this.doc,
    this.onFilterByIsa,
    this.onFilterByArch,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.base,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 750,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface0,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.blue),
                    ),
                    child: Text(
                      doc.mnemonic,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.summary,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            TagBadge(doc.arch.name, color: AppColors.blue, fontSize: 11),
                            TagBadge(doc.isaExtension, color: AppColors.red, fontSize: 11),
                            TagBadge(doc.category, color: AppColors.mauve, fontSize: 11),
                            if (doc.vectorLength.isNotEmpty)
                              TagBadge(doc.vectorLength, color: AppColors.green, fontSize: 11),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.subtext0),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(color: AppColors.surface0, height: 24),

              // Syntax & Operands
              _buildSectionTitle('SYNTAX & OPERANDS'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.crust,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SelectableText(
                  '${doc.mnemonic} ${doc.operands}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Opcode Byte Encoding & Structure
              _buildSectionTitle('MACHINE OPCODES & BYTE ENCODING'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.crust,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.surface0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Encoding: ',
                          style: TextStyle(color: AppColors.subtext0, fontSize: 12),
                        ),
                        Expanded(
                          child: SelectableText(
                            doc.opcodeEncoding,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (doc.opcodePrefix.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Text(
                            'Prefix Info: ',
                            style: TextStyle(color: AppColors.subtext0, fontSize: 12),
                          ),
                          Expanded(
                            child: SelectableText(
                              doc.opcodePrefix,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: AppColors.yellow,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Operational Semantics / Description
              _buildSectionTitle('OPERATION & HARDWARE SEMANTICS'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.mantle,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SelectableText(
                  doc.description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Technical Details (Flags, Source DB)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('FLAGS AFFECTED'),
                        Text(
                          doc.affectedFlags,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: AppColors.subtext0,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (doc.sourceDb.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('SPECIFICATION SOURCE'),
                          Text(
                            doc.sourceDb,
                            style: const TextStyle(color: AppColors.subtext0, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 24),

              // Action Hooks Toolbar (Wrap to prevent overflow on narrow screens)
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.subtext0,
                        side: const BorderSide(color: AppColors.surface1),
                      ),
                      icon: const Icon(Icons.copy, size: 14),
                      label: const Text('Copy Mnemonic'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: doc.mnemonic));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Copied ${doc.mnemonic} to clipboard')),
                        );
                      },
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.subtext0,
                        side: const BorderSide(color: AppColors.surface1),
                      ),
                      icon: const Icon(Icons.data_object, size: 14),
                      label: const Text('Copy Opcode'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: doc.opcodeEncoding));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Copied ${doc.opcodeEncoding} to clipboard')),
                        );
                      },
                    ),
                    if (onFilterByIsa != null)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surface0,
                          foregroundColor: AppColors.blue,
                        ),
                        icon: const Icon(Icons.filter_alt, size: 14),
                        label: Text('Filter ${doc.isaExtension}'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          onFilterByIsa!();
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          color: AppColors.blue,
        ),
      ),
    );
  }
}
