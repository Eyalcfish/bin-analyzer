import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/cpu_capability.dart';
import '../models/executable_binary.dart';
import '../providers/executable_provider.dart';
import '../providers/explorer_provider.dart';
import '../widgets/assembly_viewer.dart';
import '../widgets/code_editor_panel.dart';
import '../widgets/comparison_view.dart';
import '../widgets/cpu_capabilities_dialog.dart';
import '../widgets/machine_code_viewer.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/snippet_database_drawer.dart';
import 'docs_screen.dart';
import 'executable_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExplorerProvider>();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF11111B),
      drawer: const SnippetDatabaseDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Top Main Toolbar
            _buildTopToolbar(context, provider),

            // Main Split Workspace
            Expanded(
              child: Row(
                children: [
                  // Left Pane: Code Editor
                  const Expanded(
                    flex: 5,
                    child: CodeEditorPanel(),
                  ),

                  // Right Pane: Output Tabs
                  Expanded(
                    flex: 6,
                    child: Container(
                      color: const Color(0xFF181825),
                      child: Column(
                        children: [
                          // Tab Bar
                          Container(
                            height: 42,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1E1E2E),
                              border: Border(bottom: BorderSide(color: Color(0xFF313244))),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              isScrollable: true,
                              indicatorColor: const Color(0xFF89B4FA),
                              indicatorWeight: 3,
                              labelColor: const Color(0xFF89B4FA),
                              unselectedLabelColor: const Color(0xFFA6ADC8),
                              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              tabs: [
                                const Tab(
                                  icon: Icon(Icons.code, size: 16),
                                  text: 'Assembly (.s)',
                                ),
                                const Tab(
                                  icon: Icon(Icons.data_array, size: 16),
                                  text: 'Machine Code & Opcodes',
                                ),
                                Tab(
                                  icon: const Icon(Icons.compare_arrows, size: 16),
                                  text: provider.isComparisonMode ? 'Comparison (Active)' : 'Side-by-Side Comparison',
                                ),
                                const Tab(
                                  icon: Icon(Icons.terminal, size: 16),
                                  text: 'Diagnostics & Logs',
                                ),
                              ],
                            ),
                          ),

                          // Tab Views
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                const AssemblyViewer(),
                                const MachineCodeViewer(),
                                const ComparisonView(),
                                _buildDiagnosticsView(provider),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopToolbar(BuildContext context, ExplorerProvider provider) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2E),
        border: Border(bottom: BorderSide(color: Color(0xFF313244))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Logo & Snippet Drawer Button
            InkWell(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF313244),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.folder_open, color: Color(0xFF89B4FA), size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Snippets DB',
                      style: TextStyle(color: Color(0xFFCDD6F4), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            const SizedBox(
              height: 24,
              child: VerticalDivider(color: Color(0xFF313244), width: 1),
            ),
            const SizedBox(width: 12),

            // Architecture Selector
            const Text('Arch: ', style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 12)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF181825),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF313244)),
              ),
              child: DropdownButton<TargetArch>(
                value: provider.arch,
                underline: const SizedBox(),
                dropdownColor: const Color(0xFF1E1E2E),
                isDense: true,
                style: const TextStyle(color: Color(0xFFCDD6F4), fontSize: 12, fontWeight: FontWeight.bold),
                items: TargetArch.values.map((a) {
                  return DropdownMenuItem(value: a, child: Text(a.name));
                }).toList(),
                onChanged: (val) {
                  if (val != null) provider.setArch(val);
                },
              ),
            ),
            const SizedBox(width: 10),

            // Optimization Level Selector
            const Text('Opt: ', style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 12)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF181825),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF313244)),
              ),
              child: DropdownButton<OptimizationLevel>(
                value: provider.optLevel,
                underline: const SizedBox(),
                dropdownColor: const Color(0xFF1E1E2E),
                isDense: true,
                style: const TextStyle(color: Color(0xFFA6E3A1), fontSize: 12, fontWeight: FontWeight.bold),
                items: OptimizationLevel.values.map((opt) {
                  return DropdownMenuItem(
                    value: opt,
                    child: Text('${opt.flag} (${opt.label})'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) provider.setOptLevel(val);
                },
              ),
            ),
            const SizedBox(width: 10),

            // CPU Capabilities Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: provider.selectedFeatureIds.isNotEmpty ? const Color(0xFF313244) : Colors.transparent,
                side: BorderSide(
                  color: provider.selectedFeatureIds.isNotEmpty ? const Color(0xFF89B4FA) : const Color(0xFF45475A),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              icon: const Icon(Icons.memory, color: Color(0xFF89B4FA), size: 16),
              label: Text(
                provider.selectedFeatureIds.isEmpty
                    ? 'CPU Features (AVX512, etc.)'
                    : 'CPU Features (${provider.selectedFeatureIds.length})',
                style: const TextStyle(color: Color(0xFFCDD6F4), fontSize: 12),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const CpuCapabilitiesDialog(isComparison: false),
                );
              },
            ),
            const SizedBox(width: 10),

            // Syntax Switch (Intel / AT&T)
            if (provider.arch == TargetArch.amd64 || provider.arch == TargetArch.i386) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF181825),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF313244)),
                ),
                child: Row(
                  children: [
                    _buildSyntaxChip('Intel', provider.syntax == 'intel', () => provider.setSyntax('intel')),
                    _buildSyntaxChip('AT&T', provider.syntax == 'att', () => provider.setSyntax('att')),
                  ],
                ),
              ),
              const SizedBox(width: 10),
            ],

            // Mode Switcher (C Source Compiler vs Executable Analyzer)
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFF11111B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF313244)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModeTabButton('C Source Compiler', Icons.code, true, () {}),
                  _buildModeTabButton('Executable Analyzer', Icons.biotech, false, () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ExecutableScreen()),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const SizedBox(
              height: 24,
              child: VerticalDivider(color: Color(0xFF313244), width: 1),
            ),
            const SizedBox(width: 12),

            // Run / Compile Assembly Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF89B4FA),
                foregroundColor: const Color(0xFF11111B),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              icon: provider.isCompiling
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF11111B)),
                    )
                  : const Icon(Icons.play_arrow, size: 18),
              label: const Text('Compile ASM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              onPressed: provider.isCompiling ? null : () => provider.compile(),
            ),
            const SizedBox(width: 8),

            // Build Binary Executable Dropdown Button
            PopupMenuButton<BinaryOutputFormat>(
              tooltip: 'Compile C Code to Executable Binary & Analyze',
              color: const Color(0xFF1E1E2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF313244),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFA6E3A1)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.build_circle, size: 16, color: Color(0xFFA6E3A1)),
                    SizedBox(width: 6),
                    Text('Build Binary...', style: TextStyle(color: Color(0xFFA6E3A1), fontWeight: FontWeight.bold, fontSize: 12)),
                    Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFFA6E3A1)),
                  ],
                ),
              ),
              onSelected: (format) async {
                final execProvider = context.read<ExecutableProvider>();
                final success = await execProvider.compileFromSourceCode(
                  sourceCode: provider.code,
                  format: format,
                  arch: provider.arch,
                  optLevel: provider.optLevel,
                  cpuFlags: provider.activeCpuFlags,
                  extraFlags: provider.extraFlags,
                );
                if (success && context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ExecutableScreen()),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: BinaryOutputFormat.peExe,
                  child: Row(
                    children: [
                      Icon(Icons.window, size: 16, color: Color(0xFF89B4FA)),
                      SizedBox(width: 8),
                      Text('Compile to Windows PE (.exe)', style: TextStyle(fontSize: 12, color: Color(0xFFCDD6F4))),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: BinaryOutputFormat.elfBinary,
                  child: Row(
                    children: [
                      Icon(Icons.terminal, size: 16, color: Color(0xFFA6E3A1)),
                      SizedBox(width: 8),
                      Text('Compile to Linux ELF (.elf)', style: TextStyle(fontSize: 12, color: Color(0xFFCDD6F4))),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: BinaryOutputFormat.machOBinary,
                  child: Row(
                    children: [
                      Icon(Icons.apple, size: 16, color: Color(0xFFCBA6F7)),
                      SizedBox(width: 8),
                      Text('Compile to macOS Mach-O (.macho)', style: TextStyle(fontSize: 12, color: Color(0xFFCDD6F4))),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: BinaryOutputFormat.relocatableObject,
                  child: Row(
                    children: [
                      Icon(Icons.layers, size: 16, color: Color(0xFFFAB387)),
                      SizedBox(width: 8),
                      Text('Compile to Object File (.o)', style: TextStyle(fontSize: 12, color: Color(0xFFCDD6F4))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),

            // Hardware Docs Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFF313244),
                foregroundColor: const Color(0xFF89B4FA),
                side: const BorderSide(color: Color(0xFF89B4FA)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              icon: const Icon(Icons.menu_book, size: 16),
              label: const Text('Hardware Docs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DocsScreen()),
                );
              },
            ),
            const SizedBox(width: 8),

            // Settings Button
            IconButton(
              tooltip: 'Toolchain Settings',
              icon: const Icon(Icons.settings, color: Color(0xFFA6ADC8), size: 20),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const SettingsDialog(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTabButton(String title, IconData icon, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF313244) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isSelected ? const Color(0xFFCBA6F7) : const Color(0xFFA6ADC8)),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFFCDD6F4) : const Color(0xFFA6ADC8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyntaxChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF89B4FA) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF11111B) : const Color(0xFFA6ADC8),
          ),
        ),
      ),
    );
  }

  Widget _buildDiagnosticsView(ExplorerProvider provider) {
    final result = provider.result;
    if (result == null) {
      return const Center(
        child: Text('No diagnostics available.', style: TextStyle(color: Color(0xFF6C7086))),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF11111B),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'COMMAND EXECUTION PIPELINE',
              style: TextStyle(color: Color(0xFF89B4FA), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF181825),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF313244)),
              ),
              child: SelectableText(
                result.commandExecuted,
                style: GoogleFonts.firaCode(color: const Color(0xFFF9E2AF), fontSize: 11),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'COMPILER OUTPUT & MESSAGES',
              style: TextStyle(color: Color(0xFF89B4FA), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF181825),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF313244)),
              ),
              child: SelectableText(
                result.stderr.isNotEmpty
                    ? result.stderr
                    : (result.stdout.isNotEmpty ? result.stdout : 'No compiler warnings or diagnostics emitted.'),
                style: GoogleFonts.firaCode(
                  color: result.stderr.isNotEmpty ? const Color(0xFFF38BA8) : const Color(0xFFA6ADC8),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
