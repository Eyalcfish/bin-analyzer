import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/explorer_provider.dart';

class MachineCodeViewer extends StatefulWidget {
  const MachineCodeViewer({super.key});

  @override
  State<MachineCodeViewer> createState() => _MachineCodeViewerState();
}

class _MachineCodeViewerState extends State<MachineCodeViewer> {
  bool _showRawHexDump = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExplorerProvider>();
    final result = provider.result;

    if (provider.isCompiling) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF89B4FA)),
            SizedBox(height: 16),
            Text('Disassembling Machine Code...', style: TextStyle(color: Color(0xFFA6ADC8))),
          ],
        ),
      );
    }

    if (result == null || !result.success) {
      return const Center(
        child: Text('No machine code generated.', style: TextStyle(color: Color(0xFF6C7086))),
      );
    }

    return Column(
      children: [
        // Sub-toolbar
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF181825),
            border: Border(bottom: BorderSide(color: Color(0xFF313244))),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF313244),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${result.codeSizeBytes} bytes (.text)',
                  style: const TextStyle(color: Color(0xFFA6E3A1), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF313244),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${result.instructionCount} instructions',
                  style: const TextStyle(color: Color(0xFF89B4FA), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              // Toggle Table vs Raw Hex Dump
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Opcode Table', style: TextStyle(fontSize: 11)),
                    icon: Icon(Icons.table_rows, size: 14),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Raw Hex Dump', style: TextStyle(fontSize: 11)),
                    icon: Icon(Icons.data_object, size: 14),
                  ),
                ],
                selected: {_showRawHexDump},
                onSelectionChanged: (set) {
                  setState(() {
                    _showRawHexDump = set.first;
                  });
                },
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: const Color(0xFF181825),
                  selectedBackgroundColor: const Color(0xFF313244),
                  foregroundColor: const Color(0xFFA6ADC8),
                  selectedForegroundColor: const Color(0xFFCDD6F4),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Copy Disassembly',
                icon: const Icon(Icons.copy, color: Color(0xFFA6ADC8), size: 16),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _showRawHexDump ? result.hexDump : result.rawDisassembly));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard!')),
                  );
                },
              ),
            ],
          ),
        ),

        // Body
        Expanded(
          child: Container(
            color: const Color(0xFF11111B),
            child: _showRawHexDump ? _buildHexDumpView(result.hexDump) : _buildInstructionsTable(result),
          ),
        ),
      ],
    );
  }

  Widget _buildHexDumpView(String hexDump) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: SelectableText(
        hexDump.isNotEmpty ? hexDump : 'No hex dump available.',
        style: GoogleFonts.firaCode(
          color: const Color(0xFFA6ADC8),
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildInstructionsTable(dynamic result) {
    final instructions = result.instructions as List;

    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF181825),
            border: Border(bottom: BorderSide(color: Color(0xFF313244))),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 70,
                child: Text('OFFSET', style: _headerStyle),
              ),
              SizedBox(
                width: 220,
                child: Text('MACHINE OPCODES (HEX)', style: _headerStyle),
              ),
              SizedBox(
                width: 100,
                child: Text('MNEMONIC', style: _headerStyle),
              ),
              Expanded(
                child: Text('OPERANDS / REGISTERS', style: _headerStyle),
              ),
            ],
          ),
        ),

        // Table Rows
        Expanded(
          child: ListView.builder(
            itemCount: instructions.length,
            itemBuilder: (context, index) {
              final instr = instructions[index];

              if (instr.isHeader) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  color: const Color(0xFF1E1E2E),
                  child: Row(
                    children: [
                      const Icon(Icons.functions, color: Color(0xFFF9E2AF), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        instr.mnemonic,
                        style: GoogleFonts.firaCode(
                          color: const Color(0xFFF9E2AF),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final isEven = index % 2 == 0;
              final isVectorOp = instr.mnemonic.startsWith('v') ||
                  instr.mnemonic.startsWith('fadd') ||
                  instr.mnemonic.startsWith('fmul');

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                color: isEven ? const Color(0xFF11111B) : const Color(0xFF141420),
                child: Row(
                  children: [
                    // Offset
                    SizedBox(
                      width: 70,
                      child: Text(
                        instr.offset,
                        style: GoogleFonts.firaCode(
                          color: const Color(0xFF585B70),
                          fontSize: 12,
                        ),
                      ),
                    ),

                    // Hex Machine Bytes
                    SizedBox(
                      width: 220,
                      child: SelectableText(
                        instr.hexBytes,
                        style: GoogleFonts.firaCode(
                          color: isVectorOp ? const Color(0xFFF38BA8) : const Color(0xFFA6E3A1),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // Mnemonic
                    SizedBox(
                      width: 100,
                      child: SelectableText(
                        instr.mnemonic,
                        style: GoogleFonts.firaCode(
                          color: isVectorOp ? const Color(0xFFCBA6F7) : const Color(0xFF89B4FA),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),

                    // Operands
                    Expanded(
                      child: SelectableText(
                        instr.operands,
                        style: GoogleFonts.firaCode(
                          color: const Color(0xFFCDD6F4),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  TextStyle get _headerStyle => const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
        color: Color(0xFF89B4FA),
      );
}
