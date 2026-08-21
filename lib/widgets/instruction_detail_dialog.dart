import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/instruction_doc.dart';

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
      backgroundColor: const Color(0xFF1E1E2E),
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
                      color: const Color(0xFF313244),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF89B4FA)),
                    ),
                    child: Text(
                      doc.mnemonic,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF89B4FA),
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
                            color: Color(0xFFCDD6F4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _buildBadge(doc.arch.name, const Color(0xFF89B4FA)),
                            _buildBadge(doc.isaExtension, const Color(0xFFF38BA8)),
                            _buildBadge(doc.category, const Color(0xFFCBA6F7)),
                            if (doc.vectorLength.isNotEmpty)
                              _buildBadge(doc.vectorLength, const Color(0xFFA6E3A1)),
                          ],
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

              // Syntax & Operands
              _buildSectionTitle('SYNTAX & OPERANDS'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF11111B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SelectableText(
                  '${doc.mnemonic} ${doc.operands}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFCDD6F4),
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
                  color: const Color(0xFF11111B),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF313244)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Encoding: ',
                          style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 12),
                        ),
                        Expanded(
                          child: SelectableText(
                            doc.opcodeEncoding,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFA6E3A1),
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
                            style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 12),
                          ),
                          Expanded(
                            child: SelectableText(
                              doc.opcodePrefix,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: Color(0xFFF9E2AF),
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
                  color: const Color(0xFF181825),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SelectableText(
                  doc.description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFFCDD6F4),
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
                            color: Color(0xFFA6ADC8),
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
                            style: const TextStyle(color: Color(0xFFA6ADC8), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 24),

              // Action Hooks Toolbar
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFA6ADC8),
                      side: const BorderSide(color: Color(0xFF45475A)),
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
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFA6ADC8),
                      side: const BorderSide(color: Color(0xFF45475A)),
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
                  if (onFilterByIsa != null) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF313244),
                        foregroundColor: const Color(0xFF89B4FA),
                      ),
                      icon: const Icon(Icons.filter_alt, size: 14),
                      label: Text('Filter ${doc.isaExtension}'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onFilterByIsa!();
                      },
                    ),
                  ],
                ],
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
          color: Color(0xFF89B4FA),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
