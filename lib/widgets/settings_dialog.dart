import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/explorer_provider.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _gccController;
  late TextEditingController _objdumpController;
  late TextEditingController _clangController;
  late TextEditingController _llvmObjdumpController;
  String _testStatus = '';
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    final cs = context.read<ExplorerProvider>().compilerService;
    _gccController = TextEditingController(text: cs.gccPath);
    _objdumpController = TextEditingController(text: cs.objdumpPath);
    _clangController = TextEditingController(text: cs.clangPath);
    _llvmObjdumpController = TextEditingController(text: cs.llvmObjdumpPath);
  }

  @override
  void dispose() {
    _gccController.dispose();
    _objdumpController.dispose();
    _clangController.dispose();
    _llvmObjdumpController.dispose();
    super.dispose();
  }

  Future<void> _testToolchains() async {
    setState(() {
      _isTesting = true;
      _testStatus = 'Testing toolchains...\n';
    });

    final buffer = StringBuffer();

    try {
      final gccRes = await Process.run(_gccController.text, ['--version']);
      if (gccRes.exitCode == 0) {
        final firstLine = gccRes.stdout.toString().split('\n').first;
        buffer.writeln('✔ GCC: $firstLine');
      } else {
        buffer.writeln('✖ GCC: Error (${gccRes.stderr})');
      }
    } catch (e) {
      buffer.writeln('✖ GCC not found at path');
    }

    try {
      final objRes = await Process.run(_objdumpController.text, ['--version']);
      if (objRes.exitCode == 0) {
        final firstLine = objRes.stdout.toString().split('\n').first;
        buffer.writeln('✔ Objdump: $firstLine');
      } else {
        buffer.writeln('✖ Objdump error');
      }
    } catch (e) {
      buffer.writeln('✖ Objdump not found');
    }

    try {
      final clangRes = await Process.run(_clangController.text, ['--version']);
      if (clangRes.exitCode == 0) {
        final firstLine = clangRes.stdout.toString().split('\n').first;
        buffer.writeln('✔ Clang (Cross-targets): $firstLine');
      } else {
        buffer.writeln('✖ Clang error');
      }
    } catch (e) {
      buffer.writeln('✖ Clang not found');
    }

    setState(() {
      _isTesting = false;
      _testStatus = buffer.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExplorerProvider>();

    return Dialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 650,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings, color: Color(0xFF89B4FA), size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Toolchain & Compiler Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFCDD6F4),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFFA6ADC8)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: Color(0xFF313244), height: 24),

            _buildPathField('GCC Executable Path', _gccController),
            const SizedBox(height: 12),
            _buildPathField('Objdump Executable Path', _objdumpController),
            const SizedBox(height: 12),
            _buildPathField('Clang Executable Path (for ARM/RISC-V cross-target)', _clangController),
            const SizedBox(height: 12),
            _buildPathField('LLVM-Objdump Executable Path', _llvmObjdumpController),

            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  icon: _isTesting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Test Toolchain Binaries'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF89B4FA),
                    side: const BorderSide(color: Color(0xFF89B4FA)),
                  ),
                  onPressed: _isTesting ? null : _testToolchains,
                ),
              ],
            ),

            if (_testStatus.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF11111B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _testStatus,
                  style: GoogleFonts.firaCode(
                    color: _testStatus.contains('✖') ? const Color(0xFFF9E2AF) : const Color(0xFFA6E3A1),
                    fontSize: 11,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFFA6ADC8))),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF89B4FA),
                    foregroundColor: const Color(0xFF11111B),
                  ),
                  onPressed: () {
                    provider.compilerService.gccPath = _gccController.text.trim();
                    provider.compilerService.objdumpPath = _objdumpController.text.trim();
                    provider.compilerService.clangPath = _clangController.text.trim();
                    provider.compilerService.llvmObjdumpPath = _llvmObjdumpController.text.trim();
                    provider.compile();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save & Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPathField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFFA6ADC8), fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: GoogleFonts.firaCode(color: const Color(0xFFCDD6F4), fontSize: 12),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: const Color(0xFF181825),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF313244)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF313244)),
            ),
          ),
        ),
      ],
    );
  }
}
