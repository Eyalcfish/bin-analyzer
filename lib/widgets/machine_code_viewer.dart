import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/compilation_result.dart';
import '../models/cpu_capability.dart';
import '../providers/explorer_provider.dart';
import '../theme/app_colors.dart';
import '../utils/instruction_inspector.dart';

class MachineCodeViewer extends StatefulWidget {
  const MachineCodeViewer({super.key});

  @override
  State<MachineCodeViewer> createState() => _MachineCodeViewerState();
}

class _MachineCodeViewerState extends State<MachineCodeViewer> {
  bool _showRawHexDump = false;
  final ScrollController _tableHorizontalController = ScrollController();
  final ScrollController _hexHorizontalController = ScrollController();
  final ScrollController _hexVerticalController = ScrollController();

  @override
  void dispose() {
    _tableHorizontalController.dispose();
    _hexHorizontalController.dispose();
    _hexVerticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExplorerProvider>();
    final result = provider.result;

    if (provider.isCompiling) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.blue),
            SizedBox(height: 16),
            Text('Disassembling Machine Code...', style: TextStyle(color: AppColors.subtext0)),
          ],
        ),
      );
    }

    if (result == null || !result.success) {
      return const Center(
        child: Text('No machine code generated.', style: TextStyle(color: AppColors.overlay0)),
      );
    }

    return Column(
      children: [
        // Sub-toolbar
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            color: AppColors.mantle,
            border: Border(bottom: BorderSide(color: AppColors.surface0)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surface0,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${result.codeSizeBytes} bytes (.text)',
                    style: const TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surface0,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${result.instructionCount} instructions',
                    style: const TextStyle(color: AppColors.blue, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
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
                    backgroundColor: AppColors.mantle,
                    selectedBackgroundColor: AppColors.surface0,
                    foregroundColor: AppColors.subtext0,
                    selectedForegroundColor: AppColors.text,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Copy Disassembly',
                  icon: const Icon(Icons.copy, color: AppColors.subtext0, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _showRawHexDump ? result.hexDump : result.rawDisassembly));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard!')),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.crust,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.surface0),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 12, color: AppColors.blue),
                      SizedBox(width: 4),
                      Text(
                        'Shift + Click an opcode or mnemonic to view specs',
                        style: TextStyle(fontSize: 10, color: AppColors.subtext0),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Body
        Expanded(
          child: Container(
            color: AppColors.crust,
            child: _showRawHexDump
                ? _buildHexDumpView(result.hexDump, provider.arch)
                : _buildInstructionsTable(result, provider.arch),
          ),
        ),
      ],
    );
  }

  Widget _buildHexDumpView(String hexDump, TargetArch arch) {
    return RawScrollbar(
      controller: _hexHorizontalController,
      thumbVisibility: true,
      trackVisibility: true,
      thumbColor: AppColors.surface1,
      trackColor: AppColors.mantle,
      thickness: 10,
      radius: const Radius.circular(5),
      notificationPredicate: (n) => n.depth == 0,
      child: SingleChildScrollView(
        controller: _hexHorizontalController,
        scrollDirection: Axis.horizontal,
        child: RawScrollbar(
          controller: _hexVerticalController,
          thumbVisibility: true,
          trackVisibility: true,
          thumbColor: AppColors.surface1,
          trackColor: AppColors.mantle,
          thickness: 8,
          radius: const Radius.circular(4),
          notificationPredicate: (n) => n.depth == 0,
          child: SingleChildScrollView(
            controller: _hexVerticalController,
            scrollDirection: Axis.vertical,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              hexDump.isNotEmpty ? hexDump : 'No hex dump available.',
              style: const TextStyle(
                fontFamily: 'monospace',
                color: AppColors.subtext0,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionsTable(CompilationResult result, TargetArch arch) {
    final instructions = result.instructions;

    return LayoutBuilder(
      builder: (context, constraints) {
        final minTableWidth = constraints.maxWidth > 650 ? constraints.maxWidth : 650.0;

        return RawScrollbar(
          controller: _tableHorizontalController,
          thumbVisibility: true,
          trackVisibility: true,
          thumbColor: AppColors.surface1,
          trackColor: AppColors.mantle,
          thickness: 10,
          radius: const Radius.circular(5),
          notificationPredicate: (n) => n.depth == 0,
          child: SingleChildScrollView(
            controller: _tableHorizontalController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: minTableWidth,
              height: constraints.maxHeight,
              child: SelectionArea(
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: const BoxDecoration(
                        color: AppColors.mantle,
                        border: Border(bottom: BorderSide(color: AppColors.surface0)),
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
                              color: AppColors.base,
                              child: Row(
                                children: [
                                  const Icon(Icons.functions, color: AppColors.yellow, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    instr.mnemonic,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      color: AppColors.yellow,
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

                          return Material(
                            color: isEven ? AppColors.crust : const Color(0xFF141420),
                            child: InkWell(
                              onTap: () {
                                if (HardwareKeyboard.instance.isShiftPressed) {
                                  InstructionInspector.inspectInstruction(context, instr.mnemonic, arch: arch);
                                }
                              },
                              hoverColor: AppColors.blue.withOpacity(0.08),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                child: Row(
                                  children: [
                                    // Offset
                                    SizedBox(
                                      width: 70,
                                      child: Text(
                                        instr.offset,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          color: AppColors.surface2,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),

                                    // Hex Machine Bytes
                                    SizedBox(
                                      width: 220,
                                      child: Text(
                                        instr.hexBytes,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          color: isVectorOp ? AppColors.red : AppColors.green,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),

                                    // Mnemonic
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        instr.mnemonic,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          color: isVectorOp ? AppColors.mauve : AppColors.blue,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),

                                    // Operands
                                    Expanded(
                                      child: Text(
                                        instr.operands,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          color: AppColors.text,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  TextStyle get _headerStyle => const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
        color: AppColors.blue,
      );
}
