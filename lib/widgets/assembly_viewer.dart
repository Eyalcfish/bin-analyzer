import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/cpu_capability.dart';
import '../providers/explorer_provider.dart';
import '../theme/app_colors.dart';
import '../utils/instruction_inspector.dart';

class AssemblyViewer extends StatefulWidget {
  const AssemblyViewer({super.key});

  @override
  State<AssemblyViewer> createState() => _AssemblyViewerState();
}

class _AssemblyViewerState extends State<AssemblyViewer> {
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
    final provider = context.watch<ExplorerProvider>();
    final result = provider.result;

    if (provider.isCompiling) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.blue),
            SizedBox(height: 16),
            Text('Compiling with GCC...', style: TextStyle(color: AppColors.subtext0)),
          ],
        ),
      );
    }

    if (result == null) {
      return const Center(
        child: Text('No compilation result yet. Click Compile.', style: TextStyle(color: AppColors.overlay0)),
      );
    }

    if (!result.success) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: AppColors.base,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.red),
                const SizedBox(width: 8),
                const Text(
                  'Compilation Error',
                  style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                Text('Exit code: ${result.exitCode}', style: const TextStyle(color: AppColors.overlay0, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.crust,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Command: ${result.commandExecuted.split('\n').first}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: AppColors.yellow,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.crust,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SelectableText(
                      result.stderr.isNotEmpty ? result.stderr : result.stdout,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: AppColors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final asmContent = provider.cleanDirectives ? result.filteredAssembly : result.rawAssembly;
    final lines = asmContent.split('\n');

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
                Text(
                  '${lines.length} lines',
                  style: const TextStyle(color: AppColors.subtext0, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surface0,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${result.durationMs} ms',
                    style: const TextStyle(color: AppColors.green, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 16),
                // Filter Directives Toggle
                Row(
                  children: [
                    const Text('Filter Noise', style: TextStyle(color: AppColors.subtext0, fontSize: 12)),
                    Switch(
                      value: provider.cleanDirectives,
                      activeColor: AppColors.blue,
                      onChanged: (val) => provider.setCleanDirectives(val),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Copy Assembly',
                  icon: const Icon(Icons.copy, color: AppColors.subtext0, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: asmContent));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Assembly copied to clipboard!')),
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
                        'Shift + Click any instruction to view hardware docs',
                        style: TextStyle(fontSize: 10, color: AppColors.subtext0),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Assembly Lines Area (Fills 100% of panel width & height with bidirectional scrolling)
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
                                return _buildAssemblyLine(index + 1, line, provider.arch);
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

  Widget _buildAssemblyLine(int lineNum, String line, TargetArch arch) {
    final trimmed = line.trim();

    Color textColor = AppColors.text;
    FontWeight fontWeight = FontWeight.normal;

    if (trimmed.endsWith(':')) {
      // Label
      textColor = AppColors.yellow;
      fontWeight = FontWeight.bold;
    } else if (trimmed.startsWith('#') || trimmed.startsWith('//') || trimmed.startsWith(';')) {
      // Comment
      textColor = AppColors.surface2;
    } else if (trimmed.startsWith('.')) {
      // Directive
      textColor = AppColors.sky;
    } else if (trimmed.startsWith('vadd') ||
        trimmed.startsWith('vmov') ||
        trimmed.startsWith('vfmadd') ||
        trimmed.startsWith('fadd') ||
        trimmed.startsWith('lea') ||
        trimmed.startsWith('mov') ||
        trimmed.startsWith('ret') ||
        trimmed.startsWith('cmov') ||
        trimmed.startsWith('csel') ||
        trimmed.startsWith('popcnt')) {
      // Key instructions highlighted
      textColor = AppColors.blue;
    }

    return InkWell(
      onTap: () {
        if (HardwareKeyboard.instance.isShiftPressed) {
          InstructionInspector.inspectInstruction(context, line, arch: arch);
        }
      },
      hoverColor: AppColors.blue.withOpacity(0.08),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 44,
              child: Text(
                '$lineNum',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: AppColors.surface1,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              line,
              style: TextStyle(
                fontFamily: 'monospace',
                color: textColor,
                fontSize: 12.5,
                fontWeight: fontWeight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
