import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../models/cpu_capability.dart';
import '../models/instruction_doc.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../widgets/instruction_detail_dialog.dart';
import '../widgets/tag_badge.dart';

class DocsScreen extends StatefulWidget {
  final TargetArch? initialArch;
  final String? initialIsa;
  final String? initialCategory;
  final String? initialQuery;

  const DocsScreen({
    super.key,
    this.initialArch,
    this.initialIsa,
    this.initialCategory,
    this.initialQuery,
  });

  @override
  State<DocsScreen> createState() => _DocsScreenState();
}

class _DocsScreenState extends State<DocsScreen> {
  static const int _pageSize = 80;

  final DatabaseService _dbService = DatabaseService.instance;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _filterTagsScrollController = ScrollController();

  List<InstructionDoc> _instructions = [];
  List<String> _isaExtensions = ['All'];
  List<String> _categories = ['All'];

  TargetArch? _selectedArch;
  String _selectedIsa = 'All';
  String _selectedCategory = 'All';

  int _totalCount = 0;
  int _currentOffset = 0;
  bool _hasMore = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _selectedArch = widget.initialArch;
    _selectedIsa = widget.initialIsa ?? 'All';
    _selectedCategory = widget.initialCategory ?? 'All';
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
    }
    _scrollController.addListener(_onScroll);
    _loadFiltersAndData();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      if (maxScroll - currentScroll <= 400 && !_isLoading && !_isLoadingMore && _hasMore) {
        _loadNextPage();
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _filterTagsScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFiltersAndData() async {
    setState(() => _isLoading = true);

    final isas = await _dbService.getAvailableIsaExtensions(arch: _selectedArch);
    final cats = await _dbService.getAvailableInstructionCategories(arch: _selectedArch);

    _isaExtensions = ['All', ...isas];
    _categories = ['All', ...cats];

    if (_selectedIsa != 'All' && !_isaExtensions.contains(_selectedIsa)) {
      final matching = _isaExtensions.firstWhere(
        (i) => i.toLowerCase() == _selectedIsa.toLowerCase() ||
               i.toLowerCase().contains(_selectedIsa.toLowerCase()) ||
               _selectedIsa.toLowerCase().contains(i.toLowerCase()),
        orElse: () => '',
      );
      if (matching.isNotEmpty) {
        _selectedIsa = matching;
      } else {
        if (_searchController.text.isEmpty) {
          _searchController.text = _selectedIsa;
        }
        _selectedIsa = 'All';
      }
    }
    if (!_categories.contains(_selectedCategory)) {
      _selectedCategory = 'All';
    }

    await _fetchInstructions();
  }

  Future<void> _fetchInstructions() async {
    setState(() {
      _isLoading = true;
      _currentOffset = 0;
      _hasMore = true;
    });

    final query = _searchController.text.trim();
    final countFuture = _dbService.countInstructions(
      query: query,
      arch: _selectedArch,
      isaExtension: _selectedIsa,
      category: _selectedCategory,
    );

    final resultsFuture = _dbService.getInstructions(
      query: query,
      arch: _selectedArch,
      isaExtension: _selectedIsa,
      category: _selectedCategory,
      limit: _pageSize,
      offset: 0,
    );

    final results = await resultsFuture;
    final total = await countFuture;

    if (mounted) {
      setState(() {
        _instructions = results;
        _totalCount = total;
        _currentOffset = results.length;
        _hasMore = results.length < total;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    final query = _searchController.text.trim();
    final nextBatch = await _dbService.getInstructions(
      query: query,
      arch: _selectedArch,
      isaExtension: _selectedIsa,
      category: _selectedCategory,
      limit: _pageSize,
      offset: _currentOffset,
    );

    if (mounted) {
      setState(() {
        _instructions.addAll(nextBatch);
        _currentOffset += nextBatch.length;
        _hasMore = _instructions.length < _totalCount;
        _isLoadingMore = false;
      });
    }
  }

  void _onSearchChanged(String text) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      _fetchInstructions();
    });
  }

  Future<void> _pickAndImportJsonFile({bool clearExisting = false}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select Hardware Documentation JSON File',
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.single.path;
        if (path != null) {
          final file = File(path);
          if (await file.exists()) {
            final content = await file.readAsString();
            final count = await _dbService.importInstructionsFromJson(content, clearFirst: clearExisting);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF313244),
                  content: Text(
                    'Successfully imported $count instructions from ${p.basename(path)}!',
                    style: const TextStyle(color: Color(0xFFA6E3A1), fontWeight: FontWeight.bold),
                  ),
                ),
              );
              _loadFiltersAndData();
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFF38BA8),
            content: Text('File import error: $e'),
          ),
        );
      }
    }
  }

  void _showImportDialog() {
    final jsonTextController = TextEditingController();
    bool clearExisting = false;
    String? selectedFilePath;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: const Row(
            children: [
              Icon(Icons.file_upload, color: Color(0xFF89B4FA)),
              SizedBox(width: 8),
              Text('Import Database JSON', style: TextStyle(color: Color(0xFFCDD6F4))),
            ],
          ),
          content: SizedBox(
            width: 580,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select a .json file from your computer or paste raw JSON conforming to the Hardware Documentation schema.',
                  style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 13),
                ),
                const SizedBox(height: 14),

                // File Picker Button
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF313244),
                        foregroundColor: const Color(0xFF89B4FA),
                        side: const BorderSide(color: Color(0xFF89B4FA)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      icon: const Icon(Icons.folder_open, size: 16),
                      label: const Text('Browse .JSON File...', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        try {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['json'],
                            dialogTitle: 'Select JSON Spec File',
                          );
                          if (result != null && result.files.isNotEmpty) {
                            final path = result.files.single.path;
                            if (path != null) {
                              final file = File(path);
                              final content = await file.readAsString();
                              setModalState(() {
                                selectedFilePath = path;
                                jsonTextController.text = content;
                              });
                            }
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(backgroundColor: const Color(0xFFF38BA8), content: Text('Error: $e')),
                          );
                        }
                      },
                    ),
                    if (selectedFilePath != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          p.basename(selectedFilePath!),
                          style: const TextStyle(
                            color: Color(0xFFA6E3A1),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                const Text(
                  'Or paste raw JSON content below:',
                  style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 12),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: jsonTextController,
                  maxLines: 7,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFFCDD6F4),
                  ),
                  decoration: const InputDecoration(
                    hintText: '{\n  "version": "1.0",\n  "instructions": [\n    ...\n  ]\n}',
                    hintStyle: TextStyle(color: Color(0xFF45475A)),
                    filled: true,
                    fillColor: Color(0xFF11111B),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: clearExisting,
                      activeColor: const Color(0xFF89B4FA),
                      onChanged: (val) {
                        setModalState(() => clearExisting = val ?? false);
                      },
                    ),
                    const Text(
                      'Replace all existing instructions (clear database first)',
                      style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFFA6ADC8))),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF89B4FA),
                foregroundColor: const Color(0xFF11111B),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Import & Index into SQLite', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                final content = jsonTextController.text.trim();
                if (content.isNotEmpty) {
                  try {
                    final importedCount = await _dbService.importInstructionsFromJson(
                      content,
                      clearFirst: clearExisting,
                    );
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF313244),
                        content: Text(
                          'Successfully imported $importedCount instructions into SQLite!',
                          style: const TextStyle(color: Color(0xFFA6E3A1), fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                    _loadFiltersAndData();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: const Color(0xFFF38BA8), content: Text('Import error: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportDatabase() async {
    try {
      final jsonString = await _dbService.exportInstructionsToJson();
      final now = DateTime.now();
      final defaultFileName = 'isa_instructions_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';

      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Instructions Database JSON File',
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (outputFile != null) {
        String finalPath = outputFile;
        if (!finalPath.toLowerCase().endsWith('.json')) {
          finalPath += '.json';
        }
        final file = File(finalPath);
        await file.writeAsString(jsonString);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF313244),
              content: Text(
                'Successfully exported database to ${p.basename(finalPath)}!',
                style: const TextStyle(color: Color(0xFFA6E3A1), fontWeight: FontWeight.bold),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFF38BA8),
            content: Text('Export error: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF11111B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFCDD6F4)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hardware ISA & Opcode Documentation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFCDD6F4)),
            ),
            Text(
              'Database-Driven Instruction & Encoding Reference',
              style: TextStyle(fontSize: 11, color: Color(0xFFA6ADC8)),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF313244),
              foregroundColor: const Color(0xFF89B4FA),
              side: const BorderSide(color: Color(0xFF89B4FA)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: const Icon(Icons.folder_open, size: 16),
            label: const Text('Import JSON File', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: () => _pickAndImportJsonFile(),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFCDD6F4),
              side: const BorderSide(color: Color(0xFF313244)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: const Icon(Icons.paste, size: 16),
            label: const Text('Paste / Custom Import', style: TextStyle(fontSize: 12)),
            onPressed: _showImportDialog,
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFA6E3A1),
              side: const BorderSide(color: Color(0xFF313244)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: const Icon(Icons.file_download, size: 16, color: Color(0xFFA6E3A1)),
            label: const Text('Export to .JSON File', style: TextStyle(fontSize: 12)),
            onPressed: _exportDatabase,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Filter & Search Controls Header
          _buildFilterHeader(),

          // Main Instruction List (Virtual Chunked Rendering with Infinite Scroll)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF89B4FA)))
                : _instructions.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        cacheExtent: 1000,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _instructions.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _instructions.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Color(0xFF89B4FA),
                                  ),
                                ),
                              ),
                            );
                          }
                          final doc = _instructions[index];
                          return _buildInstructionCard(doc);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF181825),
        border: Border(bottom: BorderSide(color: Color(0xFF313244))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar & Stats
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Color(0xFFCDD6F4), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search by mnemonic, opcode encoding, or keyword (e.g. vaddps, EVEX, dotprod)...',
                    hintStyle: const TextStyle(color: Color(0xFF585B70)),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF89B4FA), size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Color(0xFFA6ADC8), size: 16),
                            onPressed: () {
                              _searchController.clear();
                              _fetchInstructions();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF1E1E2E),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF313244)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF313244)),
                    ),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF313244)),
                ),
                child: Text(
                  '$_totalCount matching',
                  style: const TextStyle(color: Color(0xFFA6E3A1), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Unified Scrollable Filter Tags Panel (Architecture, ISA Extension, Category)
          Container(
            constraints: const BoxConstraints(maxHeight: 145),
            decoration: BoxDecoration(
              color: const Color(0xFF141420),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF313244)),
            ),
            child: RawScrollbar(
              controller: _filterTagsScrollController,
              thumbVisibility: true,
              trackVisibility: true,
              thumbColor: const Color(0xFF585B70),
              trackColor: const Color(0xFF11111B),
              thickness: 8,
              radius: const Radius.circular(4),
              child: SingleChildScrollView(
                controller: _filterTagsScrollController,
                scrollDirection: Axis.vertical,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Architecture Selector Chips
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 100,
                          child: Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text('Architecture:', style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildArchChip('All', null),
                              _buildArchChip('AMD64 / x86_64', TargetArch.amd64),
                              _buildArchChip('ARM64 / AArch64', TargetArch.arm64),
                              _buildArchChip('RISC-V', TargetArch.riscv64),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ISA Extension Chips
                    if (_isaExtensions.length > 1) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(
                            width: 100,
                            child: Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text('ISA Extension:', style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _isaExtensions.map((isa) => _buildIsaChip(isa)).toList(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Category Chips
                    if (_categories.length > 1) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(
                            width: 100,
                            child: Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text('Category:', style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _categories.map((cat) => _buildCategoryChip(cat)).toList(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchChip(String label, TargetArch? arch) {
    final isSelected = _selectedArch == arch;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF11111B) : const Color(0xFFCDD6F4),
          ),
        ),
        backgroundColor: const Color(0xFF1E1E2E),
        selectedColor: const Color(0xFF89B4FA),
        checkmarkColor: const Color(0xFF11111B),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        onSelected: (_) {
          setState(() {
            _selectedArch = arch;
          });
          _loadFiltersAndData();
        },
      ),
    );
  }

  Widget _buildIsaChip(String isa) {
    final isSelected = _selectedIsa == isa;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text(
          isa,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF11111B) : const Color(0xFFCDD6F4),
          ),
        ),
        backgroundColor: const Color(0xFF1E1E2E),
        selectedColor: const Color(0xFFF38BA8),
        checkmarkColor: const Color(0xFF11111B),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        onSelected: (_) {
          setState(() => _selectedIsa = isa);
          _fetchInstructions();
        },
      ),
    );
  }

  Widget _buildCategoryChip(String cat) {
    final isSelected = _selectedCategory == cat;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text(
          cat,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF11111B) : const Color(0xFFCDD6F4),
          ),
        ),
        backgroundColor: const Color(0xFF1E1E2E),
        selectedColor: const Color(0xFFCBA6F7),
        checkmarkColor: const Color(0xFF11111B),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        onSelected: (_) {
          setState(() => _selectedCategory = cat);
          _fetchInstructions();
        },
      ),
    );
  }

  Widget _buildInstructionCard(InstructionDoc doc) {
    return Container(
      key: ValueKey(doc.id),
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF313244)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => InstructionDetailDialog(
                doc: doc,
                onFilterByIsa: () {
                  setState(() {
                    _selectedArch = doc.arch;
                    _selectedIsa = doc.isaExtension;
                  });
                  _loadFiltersAndData();
                },
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mnemonic badge
                Container(
                  width: 110,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF11111B),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF89B4FA).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.mnemonic,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: Color(0xFF89B4FA),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        doc.arch.id.toUpperCase(),
                        style: const TextStyle(color: Color(0xFF585B70), fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Main Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${doc.mnemonic} ${doc.operands}',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: Color(0xFFCDD6F4),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF11111B),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              doc.opcodeEncoding,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: Color(0xFFA6E3A1),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        doc.summary,
                        style: const TextStyle(color: Color(0xFFA6ADC8), fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          TagBadge(doc.isaExtension, color: AppColors.red),
                          TagBadge(doc.category, color: AppColors.mauve),
                          if (doc.vectorLength.isNotEmpty)
                            TagBadge(doc.vectorLength, color: AppColors.green),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppColors.surface2, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book, color: Color(0xFF45475A), size: 48),
          const SizedBox(height: 12),
          const Text(
            'No instructions match your search or filter criteria.',
            style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Reset Filters'),
            onPressed: () {
              setState(() {
                _searchController.clear();
                _selectedArch = null;
                _selectedIsa = 'All';
                _selectedCategory = 'All';
              });
              _loadFiltersAndData();
            },
          ),
        ],
      ),
    );
  }
}
