import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/cpu_capability.dart';
import '../models/executable_binary.dart';
import '../providers/executable_provider.dart';
import '../providers/lab_provider.dart';
import '../theme/app_colors.dart';
import '../utils/instruction_inspector.dart';
import '../widgets/app_mode_switcher.dart';
import 'docs_screen.dart';
import 'lab_screen.dart';

class ExecutableScreen extends StatefulWidget {
  final VoidCallback? onSwitchToCodeExplorer;

  const ExecutableScreen({super.key, this.onSwitchToCodeExplorer});

  @override
  State<ExecutableScreen> createState() => _ExecutableScreenState();
}

class _ExecutableScreenState extends State<ExecutableScreen> with SingleTickerProviderStateMixin {
  late TabController _rightTabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _disasmScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _rightTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _rightTabController.dispose();
    _searchController.dispose();
    _disasmScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExecutableProvider>();

    return Scaffold(
      backgroundColor: AppColors.crust,
      body: SafeArea(
        child: Column(
          children: [
            // Top Toolbar & Mode Switcher
            _buildTopToolbar(context, provider),

            // Binary Overview Metadata Header
            if (provider.binary != null) _buildBinaryHeaderCard(context, provider.binary!.header, provider.binary!.fileName),

            // Error Banner if present
            if (provider.errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.red.withValues(alpha: 0.2),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: AppColors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        provider.errorMessage!,
                        style: const TextStyle(color: AppColors.red, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            // Main Workspace Split View
            Expanded(
              child: provider.isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppColors.blue),
                          SizedBox(height: 12),
                          Text('Analyzing binary headers, sections & disassembly...', style: TextStyle(color: AppColors.subtext0)),
                        ],
                      ),
                    )
                  : provider.binary == null
                      ? _buildEmptyState(context, provider)
                      : Row(
                          children: [
                            // Left Pane: Sections & Functions Explorer
                            Expanded(
                              flex: 5,
                              child: _buildLeftStructurePanel(context, provider),
                            ),

                            // Center Divider
                            Container(width: 2, color: AppColors.surface0),

                            // Right Pane: Disassembly, Machine Code Hex, Patches
                            Expanded(
                              flex: 7,
                              child: _buildRightInspectionPanel(context, provider),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Top Navigation Toolbar ---
  Widget _buildTopToolbar(BuildContext context, ExecutableProvider provider) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.mantle,
        border: Border(bottom: BorderSide(color: AppColors.surface0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
          // App Title & Mode Switcher
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.mauve.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.memory, color: AppColors.mauve, size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'BinAnalyzer',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text),
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Workspace Mode Switcher
          AppModeSwitcher(
            currentMode: AppViewMode.executableAnalyzer,
            onSelectMode: (mode) {
              if (mode == AppViewMode.cSourceCompiler) {
                if (widget.onSwitchToCodeExplorer != null) {
                  widget.onSwitchToCodeExplorer!();
                } else {
                  Navigator.of(context).pop();
                }
              } else if (mode == AppViewMode.theLab) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LabScreen(
                      onSwitchToCodeExplorer: () {
                        Navigator.of(context).pop();
                        if (widget.onSwitchToCodeExplorer != null) {
                          widget.onSwitchToCodeExplorer!();
                        }
                      },
                      onSwitchToExecutableAnalyzer: () => Navigator.of(context).pop(),
                    ),
                  ),
                );
              }
            },
          ),

          const SizedBox(width: 16),

          // Send Snippet to The Lab Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.peach,
              foregroundColor: AppColors.base,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: const Icon(Icons.science, size: 16),
            label: const Text('Send to Lab', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: () {
              final labProvider = context.read<LabProvider>();
              final instructions = provider.filteredInstructions;
              labProvider.loadFromExecutable(
                functionName: provider.selectedFunction ?? 'Active Block',
                instructions: instructions,
                fileName: provider.binary?.fileName ?? 'binary.exe',
                arch: provider.binary?.header.arch ?? TargetArch.amd64,
              );
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LabScreen(
                    onSwitchToCodeExplorer: () {
                      Navigator.of(context).pop();
                      if (widget.onSwitchToCodeExplorer != null) {
                        widget.onSwitchToCodeExplorer!();
                      }
                    },
                    onSwitchToExecutableAnalyzer: () => Navigator.of(context).pop(),
                  ),
                ),
              );
            },
          ),

          const SizedBox(width: 16),

          // Open Binary File
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surface0,
              foregroundColor: AppColors.blue,
              side: const BorderSide(color: AppColors.blue),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: const Icon(Icons.file_open, size: 16),
            label: const Text('Open Binary File...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                dialogTitle: 'Select Executable Binary (PE, ELF, Mach-O)',
                type: FileType.any,
              );
              if (result != null && result.files.isNotEmpty) {
                final path = result.files.single.path;
                if (path != null) {
                  provider.loadExecutableFile(path);
                }
              }
            },
          ),
          const SizedBox(width: 8),

          // Compile C Source to Binary Modal
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.green,
              side: const BorderSide(color: AppColors.green),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: const Icon(Icons.build_circle_outlined, size: 16, color: AppColors.green),
            label: const Text('Compile from C...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: () => _showCompileFromCModal(context, provider),
          ),
          const SizedBox(width: 8),

          // Demo Presets Dropdown
          PopupMenuButton<BinaryOutputFormat>(
            tooltip: 'Load Sample Executable Presets',
            color: AppColors.base,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface0,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.surface1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.layers, size: 14, color: AppColors.subtext0),
                  SizedBox(width: 6),
                  Text('Demo Presets', style: TextStyle(fontSize: 12, color: AppColors.subtext0, fontWeight: FontWeight.bold)),
                  Icon(Icons.arrow_drop_down, size: 16, color: AppColors.subtext0),
                ],
              ),
            ),
            onSelected: (fmt) => provider.loadDemoBinary(fmt),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: BinaryOutputFormat.peExe,
                child: Row(
                  children: [
                    Icon(Icons.window, size: 16, color: AppColors.blue),
                    SizedBox(width: 8),
                    Text('Windows PE Executable (.exe x86_64)', style: TextStyle(fontSize: 12, color: AppColors.text)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: BinaryOutputFormat.elfBinary,
                child: Row(
                  children: [
                    Icon(Icons.terminal, size: 16, color: AppColors.green),
                    SizedBox(width: 8),
                    Text('Linux ELF Executable (.elf x86_64)', style: TextStyle(fontSize: 12, color: AppColors.text)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: BinaryOutputFormat.machOBinary,
                child: Row(
                  children: [
                    Icon(Icons.apple, size: 16, color: AppColors.mauve),
                    SizedBox(width: 8),
                    Text('macOS Mach-O Binary (.macho)', style: TextStyle(fontSize: 12, color: AppColors.text)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),

          // Hardware Docs Button
          IconButton(
            tooltip: 'Hardware ISA & Opcode Documentation',
            icon: const Icon(Icons.menu_book, color: AppColors.subtext0, size: 18),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DocsScreen())),
          ),
        ],
      ),
    ),
  );
}

  // --- Binary Overview Header Bar ---
  Widget _buildBinaryHeaderCard(BuildContext context, ExecutableHeader header, String fileName) {
    Color formatColor = AppColors.blue;
    if (header.format == ExecutableFormat.elf) formatColor = AppColors.green;
    if (header.format == ExecutableFormat.macho) formatColor = AppColors.mauve;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.base,
        border: Border(bottom: BorderSide(color: AppColors.surface0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
          // File Name & Format Badge
          Row(
            children: [
              Icon(Icons.description, size: 16, color: formatColor),
              const SizedBox(width: 6),
              Text(
                fileName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: formatColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: formatColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  header.formatDetail.split(' ').first,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: formatColor),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Architecture Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.peach.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.peach.withValues(alpha: 0.4)),
            ),
            child: Text(
              header.arch.name,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.peach),
            ),
          ),
          const SizedBox(width: 14),

          // Entry Point Address
          Row(
            children: [
              const Text('Entry: ', style: TextStyle(fontSize: 11, color: AppColors.subtext0)),
              Text(
                '0x${header.entryPointAddress.toRadixString(16).toUpperCase()}',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.yellow, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Size
          Row(
            children: [
              const Text('Size: ', style: TextStyle(fontSize: 11, color: AppColors.subtext0)),
              Text(
                '${(header.fileSizeBytes / 1024).toStringAsFixed(1)} KB',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.text),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Sections Count
          Row(
            children: [
              const Text('Sections: ', style: TextStyle(fontSize: 11, color: AppColors.subtext0)),
              Text(
                '${header.sectionCount}',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.text, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(width: 24),

          // SHA-256 Hash
          Tooltip(
            message: 'Click to copy full SHA-256: ${header.sha256}',
            child: InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: header.sha256));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(backgroundColor: AppColors.surface0, content: Text('SHA-256 copied to clipboard!')),
                );
              },
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.crust,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.fingerprint, size: 12, color: AppColors.subtext0),
                    const SizedBox(width: 4),
                    Text(
                      '${header.sha256.substring(0, 10)}...',
                      style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.subtext0),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  // --- Left Panel: Sections & Symbols ---
  Widget _buildLeftStructurePanel(BuildContext context, ExecutableProvider provider) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Sub-Tab Bar
          Container(
            height: 38,
            color: AppColors.mantle,
            child: const TabBar(
              indicatorColor: AppColors.blue,
              indicatorWeight: 2,
              labelColor: AppColors.blue,
              unselectedLabelColor: AppColors.subtext0,
              labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: [
                Tab(icon: Icon(Icons.view_agenda, size: 14), text: 'Sections & Segments'),
                Tab(icon: Icon(Icons.functions, size: 14), text: 'Functions & Symbols'),
              ],
            ),
          ),

          // Sub-Tab Views
          Expanded(
            child: TabBarView(
              children: [
                // Tab 1: Sections Table
                _buildSectionsTableView(context, provider),

                // Tab 2: Functions & Symbols List
                _buildSymbolsListView(context, provider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionsTableView(BuildContext context, ExecutableProvider provider) {
    final sections = provider.filteredSections;

    return Column(
      children: [
        // Section Filter Chips Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: AppColors.crust,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: provider.availableSectionNames.map((name) {
                final isSel = provider.selectedSection == name;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(name, style: TextStyle(fontSize: 11, color: isSel ? AppColors.crust : AppColors.text)),
                    selected: isSel,
                    selectedColor: AppColors.blue,
                    backgroundColor: AppColors.surface0,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => provider.setSelectedSection(name),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Section Headers
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: AppColors.surface0,
          child: const Row(
            children: [
              Expanded(flex: 3, child: Text('Section', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.subtext0))),
              Expanded(flex: 3, child: Text('Virtual Addr', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.subtext0))),
              Expanded(flex: 2, child: Text('Size', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.subtext0))),
              Expanded(flex: 2, child: Text('Perms', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.subtext0))),
              Expanded(flex: 2, child: Text('Entropy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.subtext0))),
            ],
          ),
        ),

        // Section Rows List
        Expanded(
          child: ListView.builder(
            itemCount: sections.length,
            itemBuilder: (context, index) {
              final sec = sections[index];
              final isSel = provider.selectedSection == sec.name;

              return InkWell(
                onTap: () => provider.setSelectedSection(isSel ? 'All' : sec.name),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel ? AppColors.surface0.withValues(alpha: 0.7) : (index % 2 == 0 ? AppColors.base : AppColors.mantle),
                    border: Border(bottom: BorderSide(color: AppColors.surface0.withValues(alpha: 0.5))),
                  ),
                  child: Row(
                    children: [
                      // Name
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Icon(
                              sec.isExecutable ? Icons.play_arrow : (sec.isWritable ? Icons.edit : Icons.lock),
                              size: 13,
                              color: sec.isExecutable ? AppColors.green : (sec.isWritable ? AppColors.peach : AppColors.blue),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                sec.name,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                  color: isSel ? AppColors.blue : AppColors.text,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // VA
                      Expanded(
                        flex: 3,
                        child: Text(
                          '0x${sec.virtualAddress.toRadixString(16).toUpperCase()}',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.yellow),
                        ),
                      ),

                      // Size
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${sec.rawSize} B',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.subtext0),
                        ),
                      ),

                      // Perms Badge
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: sec.isExecutable ? AppColors.green.withValues(alpha: 0.15) : AppColors.surface1,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            sec.permissions,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: sec.isExecutable ? AppColors.green : AppColors.subtext0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                      // Entropy Bar
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: sec.entropy / 8.0,
                                  backgroundColor: AppColors.surface1,
                                  color: sec.entropy > 7.0 ? AppColors.red : AppColors.blue,
                                  minHeight: 4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              sec.entropy.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: AppColors.subtext0),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSymbolsListView(BuildContext context, ExecutableProvider provider) {
    final symbols = provider.filteredSymbols;

    return Column(
      children: [
        // Search Filter Field & All Functions Header
        Container(
          padding: const EdgeInsets.all(8),
          color: AppColors.crust,
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: (q) => provider.setSearchQuery(q),
                style: const TextStyle(fontSize: 12, color: AppColors.text),
                decoration: InputDecoration(
                  hintText: 'Search functions & symbols...',
                  hintStyle: const TextStyle(fontSize: 12, color: AppColors.surface2),
                  prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.subtext0),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 14, color: AppColors.subtext0),
                          onPressed: () {
                            _searchController.clear();
                            provider.setSearchQuery('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.base,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  FilterChip(
                    label: Text('All Functions (${provider.binary?.symbols.length ?? 0})'),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: provider.selectedFunction == null ? FontWeight.bold : FontWeight.normal,
                      color: provider.selectedFunction == null ? AppColors.crust : AppColors.text,
                    ),
                    selected: provider.selectedFunction == null,
                    selectedColor: AppColors.blue,
                    backgroundColor: AppColors.surface0,
                    checkmarkColor: AppColors.crust,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    onSelected: (_) {
                      provider.setSelectedFunction(null);
                      provider.setHighlightAddress(null);
                    },
                  ),
                  const Spacer(),
                  if (provider.selectedFunction != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.clear, size: 12, color: AppColors.subtext0),
                      label: const Text('Clear Filter', style: TextStyle(fontSize: 11, color: AppColors.subtext0)),
                      onPressed: () {
                        provider.setSelectedFunction(null);
                        provider.setHighlightAddress(null);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),

        // Symbols List
        Expanded(
          child: symbols.isEmpty
              ? const Center(
                  child: Text('No matching symbols detected', style: TextStyle(color: AppColors.subtext0, fontSize: 12)),
                )
              : ListView.builder(
                  itemCount: symbols.length,
                  itemBuilder: (context, index) {
                    final sym = symbols[index];
                    final isSel = provider.selectedFunction == sym.name;

                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      tileColor: isSel ? AppColors.surface0 : (index % 2 == 0 ? AppColors.base : AppColors.mantle),
                      leading: Icon(
                        sym.isExported ? Icons.upload : Icons.code,
                        size: 14,
                        color: sym.isExported ? AppColors.green : AppColors.blue,
                      ),
                      title: Text(
                        sym.name,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          color: isSel ? AppColors.blue : AppColors.text,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '0x${sym.virtualAddress.toRadixString(16).toUpperCase()}  (${sym.sectionName})',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppColors.yellow),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 14, color: AppColors.subtext0),
                      onTap: () {
                        provider.setSelectedFunction(sym.name);
                        provider.setHighlightAddress(sym.virtualAddress);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- Right Panel: Disassembly, Machine Code Hex, Patches ---
  Widget _buildRightInspectionPanel(BuildContext context, ExecutableProvider provider) {
    return Column(
      children: [
        // Tab Bar Header
        Container(
          height: 38,
          color: AppColors.mantle,
          child: TabBar(
            controller: _rightTabController,
            indicatorColor: AppColors.mauve,
            indicatorWeight: 2,
            labelColor: AppColors.mauve,
            unselectedLabelColor: AppColors.subtext0,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            tabs: [
              const Tab(icon: Icon(Icons.terminal, size: 14), text: 'Disassembly'),
              const Tab(icon: Icon(Icons.data_array, size: 14), text: 'Machine Code (Hex)'),
              Tab(
                icon: const Icon(Icons.history, size: 14),
                text: provider.binary?.patches.isNotEmpty == true
                    ? 'Patches (${provider.binary!.patches.length})'
                    : 'Patches & Export',
              ),
            ],
          ),
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _rightTabController,
            children: [
              // 1. Disassembly View
              _buildDisassemblyView(context, provider),

              // 2. Machine Code Hex View
              _buildHexDumpView(context, provider),

              // 3. Patches & Export View
              _buildPatchesView(context, provider),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDisassemblyView(BuildContext context, ExecutableProvider provider) {
    final instructions = provider.filteredInstructions;
    final arch = provider.binary?.header.arch ?? TargetArch.amd64;

    return Column(
      children: [
        // Navigation Back Button + Active Function Filter Banner
        if (provider.selectedFunction != null || provider.canGoBack)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: AppColors.surface0,
            child: Row(
              children: [
                if (provider.canGoBack) ...[
                  InkWell(
                    onTap: () {
                      provider.navigateBack();
                      _scrollToHighlight(provider);
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_back, size: 12, color: AppColors.green),
                          const SizedBox(width: 4),
                          Text(
                            'Back (${provider.navigationHistory.length})',
                            style: const TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (provider.selectedFunction != null) ...[
                  const Icon(Icons.filter_alt, size: 14, color: AppColors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Filtered Function: <${provider.selectedFunction}>',
                    style: const TextStyle(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  ),
                ],
                const Spacer(),
                if (provider.selectedFunction != null) ...[
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.science, size: 14, color: AppColors.peach),
                    label: const Text('Test in Lab', style: TextStyle(color: AppColors.peach, fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      final labProvider = context.read<LabProvider>();
                      final funcInstructions = provider.filteredInstructions;
                      labProvider.loadFromExecutable(
                        functionName: provider.selectedFunction ?? 'Active Function',
                        instructions: funcInstructions,
                        fileName: provider.binary?.fileName ?? 'binary.exe',
                        arch: provider.binary?.header.arch ?? TargetArch.amd64,
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LabScreen(
                            onSwitchToCodeExplorer: () {
                              Navigator.of(context).pop();
                              if (widget.onSwitchToCodeExplorer != null) {
                                widget.onSwitchToCodeExplorer!();
                              }
                            },
                            onSwitchToExecutableAnalyzer: () => Navigator.of(context).pop(),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.clear_all, size: 14, color: AppColors.mauve),
                    label: const Text('Show All Disassembly', style: TextStyle(color: AppColors.mauve, fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      provider.setSelectedFunction(null);
                      provider.setHighlightAddress(null);
                    },
                  ),
                ],
              ],
            ),
          ),

        // Instructions List or Empty Warning
        Expanded(
          child: instructions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_off, size: 36, color: AppColors.subtext0),
                      const SizedBox(height: 8),
                      Text(
                        provider.selectedFunction != null
                            ? 'No instructions found matching function "${provider.selectedFunction}".'
                            : 'No instructions in current filter.',
                        style: const TextStyle(color: AppColors.subtext0, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surface0,
                          foregroundColor: AppColors.blue,
                        ),
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('Reset All Filters', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          provider.setSelectedFunction(null);
                          provider.setSelectedSection('All');
                          provider.setSearchQuery('');
                          provider.setHighlightAddress(null);
                        },
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _disasmScrollController,
                  itemCount: instructions.length,
                  itemBuilder: (context, index) {
        final insn = instructions[index];

        final isHighlighted = provider.highlightAddress == insn.virtualAddress;

        if (insn.isFunctionHeader) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: isHighlighted ? AppColors.mauve.withValues(alpha: 0.35) : AppColors.surface0,
              border: isHighlighted ? const Border(left: BorderSide(color: AppColors.mauve, width: 4)) : null,
            ),
            child: Row(
              children: [
                const Icon(Icons.label, size: 14, color: AppColors.mauve),
                const SizedBox(width: 8),
                Text(
                  insn.mnemonic,
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.mauve),
                ),
                const Spacer(),
                Text(
                  '0x${insn.virtualAddress.toRadixString(16).toUpperCase()}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.yellow),
                ),
              ],
            ),
          );
        }

        return InkWell(
          onTap: () {
            if (HardwareKeyboard.instance.isShiftPressed) {
              InstructionInspector.inspectInstruction(context, insn.mnemonic, arch: arch);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? AppColors.mauve.withValues(alpha: 0.25)
                  : (insn.isPatched ? AppColors.peach.withValues(alpha: 0.15) : (index % 2 == 0 ? AppColors.base : AppColors.mantle)),
              border: isHighlighted ? const Border(left: BorderSide(color: AppColors.mauve, width: 3)) : null,
            ),
            child: Row(
              children: [
                // Virtual Address
                SizedBox(
                  width: 90,
                  child: Text(
                    '0x${insn.virtualAddress.toRadixString(16).toUpperCase()}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.yellow),
                  ),
                ),

                // Hex Bytes
                SizedBox(
                  width: 140,
                  child: Text(
                    insn.hexBytes,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.subtext0),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Instruction Mnemonic & Operands
                Expanded(
                  child: _buildInstructionSpans(context, insn, provider),
                ),
              ],
            ),
          ),
        );
      },
    ),
  ),
],
);
}

  // --- Branch Target Navigation Helpers ---

  static final _branchMnemonics = <String>{
    // x86 / x64
    'call', 'callq', 'jmp', 'jmpq', 'ljmp', 'lcall',
    'je', 'jne', 'jz', 'jnz', 'jg', 'jge', 'jl', 'jle',
    'ja', 'jae', 'jb', 'jbe', 'jo', 'jno', 'js', 'jns', 'jp', 'jnp', 'jpe', 'jpo',
    'jcxz', 'jecxz', 'jrcxz', 'loop', 'loope', 'loopne', 'loopz', 'loopnz',
    // ARM / ARM64
    'bl', 'b', 'bx', 'blx', 'bxj',
    'beq', 'bne', 'bcs', 'bhs', 'bcc', 'blo', 'bmi', 'bpl', 'bvs', 'bvc',
    'bhi', 'bls', 'bge', 'blt', 'bgt', 'ble', 'bal',
    'cbz', 'cbnz', 'tbz', 'tbnz',
    // RISC-V
    'jal', 'jalr', 'j', 'jr',
    'beqz', 'bnez', 'blez', 'bgez', 'bltz', 'bgtz', 'bltu', 'bgeu',
  };

  bool _isBranchMnemonic(String mnemonic) {
    final m = mnemonic.toLowerCase().trim();
    if (_branchMnemonics.contains(m)) return true;
    if (m.startsWith('j') || m.startsWith('call') || m.startsWith('loop')) return true;
    if (m.startsWith('b.') || (m.startsWith('b') && m.length <= 5)) return true;
    return false;
  }

  /// Parse a target address from call/jmp operands.
  /// Handles all toolchain output formats, such as:
  /// - `0xad <main+0x4d>`
  /// - `ad <main+0x4d>`
  /// - `0x140001378`
  /// - `140001378 <check_managed_app>`
  /// - `<main>` / `<_start>`
  /// - `*0x140005000`
  int? _parseBranchTarget(String operands, ExecutableBinary? binary) {
    final clean = operands.trim();
    if (clean.isEmpty) return null;

    // 1. Direct hex at start, e.g. "0xad <main+0x4d>", "0x1400013a0", "ad <main+0x4d>", "*0x140005000"
    final stripped = clean.startsWith('*') ? clean.substring(1).trim() : clean;
    final hexMatch = RegExp(r'^(?:0x)?([0-9a-fA-F]+)').firstMatch(stripped);
    if (hexMatch != null) {
      final hexStr = hexMatch.group(1)!;
      // Skip if it's a register name (e.g. eax, ebx, edx, ecx, esp, ebp, esi, edi, r8-r15, etc.)
      const registers = {
        'rax', 'rbx', 'rcx', 'rdx', 'rsi', 'rdi', 'rbp', 'rsp', 'rip',
        'r8', 'r9', 'r10', 'r11', 'r12', 'r13', 'r14', 'r15',
        'eax', 'ebx', 'ecx', 'edx', 'esi', 'edi', 'ebp', 'esp', 'eip',
        'r8d', 'r9d', 'r10d', 'r11d', 'r12d', 'r13d', 'r14d', 'r15d',
        'ax', 'bx', 'cx', 'dx', 'si', 'di', 'bp', 'sp', 'ip',
        'al', 'bl', 'cl', 'dl', 'ah', 'bh', 'ch', 'dh',
        'w0', 'w1', 'w2', 'w3', 'w4', 'w5', 'w6', 'w7', 'w8', 'w9', 'w10', 'w11', 'w12', 'w13', 'w14', 'w15',
        'x0', 'x1', 'x2', 'x3', 'x4', 'x5', 'x6', 'x7', 'x8', 'x9', 'x10', 'x11', 'x12', 'x13', 'x14', 'x15',
        'lr', 'pc', 'fp',
      };
      if (!registers.contains(hexStr.toLowerCase())) {
        final addr = int.tryParse(hexStr, radix: 16);
        if (addr != null) {
          return addr;
        }
      }
    }

    // 2. Extract symbol from <symbol> or <symbol+0xoffset>
    final symbolMatch = RegExp(r'<([^>]+)>').firstMatch(clean);
    if (symbolMatch != null && binary != null) {
      final fullSym = symbolMatch.group(1)!;
      String symName = fullSym;
      int offset = 0;
      if (fullSym.contains('+')) {
        final parts = fullSym.split('+');
        symName = parts[0].trim();
        final offStr = parts[1].trim().replaceFirst('0x', '');
        offset = int.tryParse(offStr, radix: 16) ?? int.tryParse(offStr) ?? 0;
      } else if (fullSym.contains('-')) {
        final parts = fullSym.split('-');
        symName = parts[0].trim();
        final offStr = parts[1].trim().replaceFirst('0x', '');
        offset = -(int.tryParse(offStr, radix: 16) ?? int.tryParse(offStr) ?? 0);
      }

      // Lookup in binary symbol table
      final sym = binary.symbols.where((s) => s.name == symName).firstOrNull;
      if (sym != null) {
        return sym.virtualAddress + offset;
      }

      // Lookup in instruction function headers or instruction names
      final insn = binary.instructions.where((i) => i.functionName == symName && i.isFunctionHeader).firstOrNull ??
                   binary.instructions.where((i) => i.functionName == symName).firstOrNull;
      if (insn != null) {
        return insn.virtualAddress + offset;
      }
    }

    return null;
  }

  /// Extract the function name from operands like `0x140001378 <check_managed_app>`
  String? _parseBranchFunctionName(String operands) {
    final match = RegExp(r'<([^>]+)>').firstMatch(operands);
    if (match != null) {
      final name = match.group(1)!;
      // Strip offset suffixes like "pre_c_init+0x2c"
      final plusIdx = name.indexOf('+');
      return plusIdx > 0 ? name.substring(0, plusIdx) : name;
    }
    return null;
  }

  Widget _buildInstructionSpans(BuildContext context, ExecutableInstruction insn, ExecutableProvider provider) {
    final isBranch = _isBranchMnemonic(insn.mnemonic);
    final targetAddr = isBranch ? _parseBranchTarget(insn.operands, provider.binary) : null;
    final targetFunc = isBranch ? _parseBranchFunctionName(insn.operands) : null;
    final bool isClickable = targetAddr != null;

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: insn.mnemonic,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: insn.isPatched ? AppColors.peach : AppColors.blue,
            ),
          ),
          if (insn.operands.isNotEmpty) ...[
            const TextSpan(text: '  '),
            if (isClickable)
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      provider.navigateToAddress(targetAddr, sourceAddress: insn.virtualAddress);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scrollToHighlight(provider);
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          insn.operands,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: AppColors.green,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          targetFunc != null ? Icons.call_made : Icons.arrow_forward,
                          size: 11,
                          color: AppColors.green,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              TextSpan(
                text: insn.operands,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.text),
              ),
          ],
          if (insn.comment.isNotEmpty) ...[
            TextSpan(
              text: '  # ${insn.comment}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.surface2, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  /// Scroll the disassembly ListView to the currently highlighted address.
  void _scrollToHighlight(ExecutableProvider provider) {
    final targetAddr = provider.highlightAddress;
    if (targetAddr == null) return;

    final instructions = provider.filteredInstructions;
    if (instructions.isEmpty) return;

    // 1. Look for exact address match
    int targetIndex = instructions.indexWhere((insn) => insn.virtualAddress == targetAddr);

    // 2. If not exact, find the closest preceding instruction or header
    if (targetIndex < 0) {
      for (int i = instructions.length - 1; i >= 0; i--) {
        if (instructions[i].virtualAddress <= targetAddr) {
          targetIndex = i;
          break;
        }
      }
    }

    if (targetIndex >= 0 && _disasmScrollController.hasClients) {
      // Estimate item height (~28px per row) and scroll with an offset so the target is centered/visible
      final estimatedOffset = math.max(0.0, (targetIndex * 28.0) - 100.0);
      final maxScroll = _disasmScrollController.position.maxScrollExtent;
      _disasmScrollController.animateTo(
        estimatedOffset.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildHexDumpView(BuildContext context, ExecutableProvider provider) {
    final bytes = provider.binary?.byteBuffer;
    if (bytes == null || bytes.isEmpty) {
      return const Center(child: Text('No binary data loaded', style: TextStyle(color: AppColors.subtext0)));
    }

    final rowCount = (bytes.length / 16).ceil();
    final imageBase = provider.binary?.header.imageBase ?? 0;

    return ListView.builder(
      itemCount: rowCount,
      itemBuilder: (context, rowIndex) {
        final offset = rowIndex * 16;
        final rowBytes = bytes.sublist(offset, (offset + 16 < bytes.length) ? offset + 16 : bytes.length);

        final hexCols = <String>[];
        final asciiCols = StringBuffer();

        for (int i = 0; i < 16; i++) {
          if (i < rowBytes.length) {
            final b = rowBytes[i];
            hexCols.add(b.toRadixString(16).padLeft(2, '0').toUpperCase());
            if (b >= 32 && b <= 126) {
              asciiCols.write(String.fromCharCode(b));
            } else {
              asciiCols.write('.');
            }
          } else {
            hexCols.add('  ');
            asciiCols.write(' ');
          }
        }

        final hex1 = hexCols.sublist(0, 8).join(' ');
        final hex2 = hexCols.sublist(8, 16).join(' ');

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          color: rowIndex % 2 == 0 ? AppColors.base : AppColors.mantle,
          child: Row(
            children: [
              // File Offset & VA
              SizedBox(
                width: 140,
                child: Text(
                  '${offset.toRadixString(16).padLeft(8, '0').toUpperCase()} (0x${(imageBase + offset).toRadixString(16).toUpperCase()})',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.yellow),
                ),
              ),
              const SizedBox(width: 10),

              // Hex bytes
              Expanded(
                flex: 4,
                child: Text(
                  '$hex1  $hex2',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.text),
                ),
              ),

              // ASCII Representation
              Expanded(
                flex: 2,
                child: Text(
                  asciiCols.toString(),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.green),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPatchesView(BuildContext context, ExecutableProvider provider) {
    final patches = provider.binary?.patches ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.base,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: AppColors.mauve, size: 20),
              const SizedBox(width: 8),
              const Text('Binary Mutation & Patch History', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text)),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: AppColors.crust,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.save_alt, size: 16),
                label: const Text('Save / Export Binary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () async {
                  final outputPath = await FilePicker.platform.saveFile(
                    dialogTitle: 'Export Patched Binary File',
                    fileName: 'patched_${provider.binary?.fileName ?? "binary.exe"}',
                  );
                  if (outputPath != null) {
                    await provider.exportPatchedBinary(outputPath);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(backgroundColor: AppColors.surface0, content: Text('Exported binary to $outputPath')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (patches.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_note, size: 36, color: AppColors.subtext0),
                    SizedBox(height: 8),
                    Text('No byte patches applied yet', style: TextStyle(color: AppColors.subtext0, fontSize: 13)),
                    SizedBox(height: 4),
                    Text('Byte buffers and patch pipelines are ready for manual hex & assembly patching.', style: TextStyle(color: AppColors.surface2, fontSize: 11)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: patches.length,
                itemBuilder: (context, index) {
                  final p = patches[index];
                  final origHex = p.originalBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
                  final patchHex = p.patchedBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.mantle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.peach.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Text('Patch #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.peach, fontSize: 12)),
                        const SizedBox(width: 12),
                        Text('Offset: 0x${p.fileOffset.toRadixString(16)}', style: const TextStyle(fontFamily: 'monospace', color: AppColors.yellow, fontSize: 11)),
                        const SizedBox(width: 12),
                        Text('- [$origHex]', style: const TextStyle(fontFamily: 'monospace', color: AppColors.red, fontSize: 11)),
                        const SizedBox(width: 6),
                        Text('+ [$patchHex]', style: const TextStyle(fontFamily: 'monospace', color: AppColors.green, fontSize: 11)),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ExecutableProvider provider) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.biotech, size: 48, color: AppColors.blue),
          const SizedBox(height: 12),
          const Text('No Executable Loaded', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
          const SizedBox(height: 6),
          const Text('Open a .exe, .elf, or Mach-O binary file or compile from C.', style: TextStyle(color: AppColors.subtext0, fontSize: 13)),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.layers, size: 16),
                label: const Text('Load Demo PE Executable'),
                onPressed: () => provider.loadDemoBinary(BinaryOutputFormat.peExe),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.build_circle_outlined, size: 16),
                label: const Text('Compile from C Code'),
                onPressed: () => _showCompileFromCModal(context, provider),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- In-App C Compilation to Executable Modal ---
  void _showCompileFromCModal(BuildContext context, ExecutableProvider provider) {
    final codeController = TextEditingController(text: '''int multiply_accumulate(int* a, int* b, int n) {
    int sum = 0;
    for (int i = 0; i < n; i++) {
        sum += a[i] * b[i];
    }
    return sum;
}

int main() {
    int x[4] = {1, 2, 3, 4};
    int y[4] = {5, 6, 7, 8};
    return multiply_accumulate(x, y, 4);
}
''');
    BinaryOutputFormat chosenFormat = provider.selectedOutputFormat;
    TargetArch chosenArch = TargetArch.amd64;
    OptimizationLevel chosenOpt = OptimizationLevel.O3;
    final Set<String> selectedFeatureIds = {'avx2', 'fma'};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final availableFeatures = CpuCapabilitiesData.allFeatures
              .where((f) => f.applicableArchs.contains(chosenArch))
              .toList();

          return AlertDialog(
            backgroundColor: AppColors.base,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Row(
              children: [
                Icon(Icons.build_circle, color: AppColors.green, size: 24),
                SizedBox(width: 10),
                Text(
                  'Compile C Source to Executable Binary',
                  style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            content: SizedBox(
              width: 720,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configure output format, target architecture, optimization level, and CPU capability flags:',
                      style: TextStyle(color: AppColors.subtext0, fontSize: 12),
                    ),
                    const SizedBox(height: 12),

                    // Top Row: Binary Format & Target Architecture
                    Row(
                      children: [
                        // Binary Format Dropdown
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Output Binary Format:', style: TextStyle(color: AppColors.subtext0, fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.crust,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.surface1),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<BinaryOutputFormat>(
                                    value: chosenFormat,
                                    isExpanded: true,
                                    dropdownColor: AppColors.base,
                                    items: BinaryOutputFormat.values.map((f) {
                                      return DropdownMenuItem(
                                        value: f,
                                        child: Text(f.label, style: const TextStyle(fontSize: 12, color: AppColors.text)),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setModalState(() => chosenFormat = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Architecture Dropdown
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Target Architecture:', style: TextStyle(color: AppColors.subtext0, fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.crust,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.surface1),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<TargetArch>(
                                    value: chosenArch,
                                    isExpanded: true,
                                    dropdownColor: AppColors.base,
                                    items: TargetArch.values.map((a) {
                                      return DropdownMenuItem(
                                        value: a,
                                        child: Text(a.name, style: const TextStyle(fontSize: 12, color: AppColors.text)),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setModalState(() {
                                          chosenArch = val;
                                          selectedFeatureIds.removeWhere(
                                            (id) => !CpuCapabilitiesData.allFeatures.any((f) => f.id == id && f.applicableArchs.contains(val)),
                                          );
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Second Row: Optimization Level
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Optimization Level:', style: TextStyle(color: AppColors.subtext0, fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.crust,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.surface1),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<OptimizationLevel>(
                                    value: chosenOpt,
                                    isExpanded: true,
                                    dropdownColor: AppColors.base,
                                    items: OptimizationLevel.values.map((opt) {
                                      return DropdownMenuItem(
                                        value: opt,
                                        child: Row(
                                          children: [
                                            Text(opt.flag, style: const TextStyle(fontSize: 12, color: AppColors.green, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                                            const SizedBox(width: 8),
                                            Text('(${opt.label})', style: const TextStyle(fontSize: 12, color: AppColors.text)),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setModalState(() => chosenOpt = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Third Section: CPU Capabilities & ISA Flags
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.memory, size: 14, color: AppColors.mauve),
                            const SizedBox(width: 6),
                            Text(
                              'CPU Features & ISA Flags (${selectedFeatureIds.length} enabled):',
                              style: const TextStyle(color: AppColors.subtext0, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                setModalState(() => selectedFeatureIds.clear());
                              },
                              child: const Text('Clear Flags', style: TextStyle(fontSize: 11, color: AppColors.subtext0)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.crust,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.surface1),
                          ),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: availableFeatures.map((feat) {
                              final isSelected = selectedFeatureIds.contains(feat.id);
                              return FilterChip(
                                label: Text(feat.name),
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? AppColors.crust : AppColors.text,
                                ),
                                selected: isSelected,
                                selectedColor: AppColors.mauve,
                                backgroundColor: AppColors.surface0,
                                checkmarkColor: AppColors.crust,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                onSelected: (sel) {
                                  setModalState(() {
                                    if (sel) {
                                      selectedFeatureIds.add(feat.id);
                                    } else {
                                      selectedFeatureIds.remove(feat.id);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // C Source Code Editor
                    const Text('C Source Code:', style: TextStyle(color: AppColors.subtext0, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: codeController,
                      maxLines: 7,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.text),
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: AppColors.crust,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: AppColors.subtext0)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: AppColors.crust,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Compile & Analyze Binary', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  Navigator.of(ctx).pop();

                  final List<String> activeFlags = [];
                  for (final id in selectedFeatureIds) {
                    final feat = CpuCapabilitiesData.allFeatures.where((f) => f.id == id).firstOrNull;
                    if (feat != null && feat.applicableArchs.contains(chosenArch)) {
                      activeFlags.add(feat.flag);
                    }
                  }

                  await provider.compileFromSourceCode(
                    sourceCode: codeController.text,
                    format: chosenFormat,
                    arch: chosenArch,
                    optLevel: chosenOpt,
                    cpuFlags: activeFlags,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
