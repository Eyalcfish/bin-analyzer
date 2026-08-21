import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/explorer_provider.dart';

class AssemblyViewer extends StatelessWidget {
  const AssemblyViewer({super.key});

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
            Text('Compiling with GCC...', style: TextStyle(color: Color(0xFFA6ADC8))),
          ],
        ),
      );
    }

    if (result == null) {
      return const Center(
        child: Text('No compilation result yet. Click Compile.', style: TextStyle(color: Color(0xFF6C7086))),
      );
    }

    if (!result.success) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: const Color(0xFF1E1E2E),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFF38BA8)),
                const SizedBox(width: 8),
                const Text(
                  'Compilation Error',
                  style: TextStyle(color: Color(0xFFF38BA8), fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                Text('Exit code: ${result.exitCode}', style: const TextStyle(color: Color(0xFF6C7086), fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF11111B),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Command: ${result.commandExecuted.split('\n').first}',
                style: GoogleFonts.firaCode(color: const Color(0xFFF9E2AF), fontSize: 11),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF11111B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    result.stderr.isNotEmpty ? result.stderr : result.stdout,
                    style: GoogleFonts.firaCode(color: const Color(0xFFF38BA8), fontSize: 12),
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
            color: Color(0xFF181825),
            border: Border(bottom: BorderSide(color: Color(0xFF313244))),
          ),
          child: Row(
            children: [
              Text(
                '${lines.length} lines',
                style: const TextStyle(color: Color(0xFFA6ADC8), fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF313244),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${result.durationMs} ms',
                  style: const TextStyle(color: Color(0xFFA6E3A1), fontSize: 11),
                ),
              ),
              const Spacer(),
              // Filter Directives Toggle
              Row(
                children: [
                  const Text('Filter Noise', style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 12)),
                  Switch(
                    value: provider.cleanDirectives,
                    activeColor: const Color(0xFF89B4FA),
                    onChanged: (val) => provider.setCleanDirectives(val),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Copy Assembly',
                icon: const Icon(Icons.copy, color: Color(0xFFA6ADC8), size: 16),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: asmContent));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Assembly copied to clipboard!')),
                  );
                },
              ),
            ],
          ),
        ),

        // Assembly Lines Area
        Expanded(
          child: Container(
            color: const Color(0xFF11111B),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: lines.length,
              itemBuilder: (context, index) {
                final line = lines[index];
                return _buildAssemblyLine(index + 1, line);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssemblyLine(int lineNum, String line) {
    final trimmed = line.trim();

    Color textColor = const Color(0xFFCDD6F4);
    FontWeight fontWeight = FontWeight.normal;

    if (trimmed.endsWith(':')) {
      // Label
      textColor = const Color(0xFFF9E2AF);
      fontWeight = FontWeight.bold;
    } else if (trimmed.startsWith('#') || trimmed.startsWith('//') || trimmed.startsWith(';')) {
      // Comment
      textColor = const Color(0xFF585B70);
    } else if (trimmed.startsWith('.')) {
      // Directive
      textColor = const Color(0xFF89DCEB);
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
      textColor = const Color(0xFF89B4FA);
    }

    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '$lineNum',
              textAlign: TextAlign.right,
              style: GoogleFonts.firaCode(color: const Color(0xFF45475A), fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              line,
              style: GoogleFonts.firaCode(
                color: textColor,
                fontSize: 12.5,
                fontWeight: fontWeight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
