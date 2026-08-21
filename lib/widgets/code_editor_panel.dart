import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/explorer_provider.dart';
import '../theme/app_colors.dart';

class CodeEditorPanel extends StatefulWidget {
  const CodeEditorPanel({super.key});

  @override
  State<CodeEditorPanel> createState() => _CodeEditorPanelState();
}

class _CodeEditorPanelState extends State<CodeEditorPanel> {
  late TextEditingController _controller;
  late ScrollController _scrollController;
  late ScrollController _lineScrollController;
  String? _lastLoadedSnippetId;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ExplorerProvider>();
    _controller = TextEditingController(text: provider.code);
    _lastLoadedSnippetId = provider.currentSnippet?.id;
    _scrollController = ScrollController();
    _lineScrollController = ScrollController();

    _scrollController.addListener(() {
      if (_lineScrollController.hasClients) {
        _lineScrollController.jumpTo(_scrollController.offset);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _lineScrollController.dispose();
    super.dispose();
  }

  void _showSaveSnippetDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final catController = TextEditingController(text: 'Custom');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.base,
        title: const Text('Save C Snippet to Database', style: TextStyle(color: AppColors.text)),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: AppColors.text),
                decoration: const InputDecoration(
                  labelText: 'Snippet Title',
                  labelStyle: TextStyle(color: AppColors.subtext0),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 2,
                style: const TextStyle(color: AppColors.text),
                decoration: const InputDecoration(
                  labelText: 'Description / Notes',
                  labelStyle: TextStyle(color: AppColors.subtext0),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: catController,
                style: const TextStyle(color: AppColors.text),
                decoration: const InputDecoration(
                  labelText: 'Category (e.g. SIMD, Inlining, Bitwise)',
                  labelStyle: TextStyle(color: AppColors.subtext0),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.subtext0)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: AppColors.crust,
            ),
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                context.read<ExplorerProvider>().saveSnippet(
                  title: titleController.text.trim(),
                  description: descController.text.trim(),
                  category: catController.text.trim().isEmpty ? 'General' : catController.text.trim(),
                );
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Snippet saved to local database!')),
                );
              }
            },
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExplorerProvider>();

    // Sync editor text only when an external preset / snippet is selected
    if (provider.currentSnippet?.id != _lastLoadedSnippetId) {
      _lastLoadedSnippetId = provider.currentSnippet?.id;
      if (_controller.text != provider.code) {
        _controller.text = provider.code;
      }
    }

    final lineCount = '\n'.allMatches(_controller.text).length + 1;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.mantle,
        border: Border(right: BorderSide(color: AppColors.surface0)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: AppColors.base,
              border: Border(bottom: BorderSide(color: AppColors.surface0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.code, color: AppColors.blue, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    provider.currentSnippet?.title ?? 'C Source Code',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (provider.currentSnippet?.isPreset == true) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surface0,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'PRESET',
                      style: TextStyle(color: AppColors.yellow, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Save to Snippet Database',
                  icon: const Icon(Icons.bookmark_add_outlined, color: AppColors.subtext0, size: 18),
                  onPressed: () => _showSaveSnippetDialog(context),
                ),
                IconButton(
                  tooltip: 'Insert Tab (Hard Tab)',
                  icon: const Icon(Icons.keyboard_tab, color: AppColors.subtext0, size: 18),
                  onPressed: () {
                    final text = _controller.text;
                    final selection = _controller.selection;
                    final newText = text.replaceRange(selection.start, selection.end, '\t');
                    _controller.value = TextEditingValue(
                      text: newText,
                      selection: TextSelection.collapsed(offset: selection.start + 1),
                    );
                    provider.setCode(newText);
                  },
                ),
                IconButton(
                  tooltip: 'Clear Editor',
                  icon: const Icon(Icons.clear_all, color: AppColors.subtext0, size: 18),
                  onPressed: () {
                    _controller.clear();
                    provider.setCode('');
                  },
                ),
              ],
            ),
          ),

          // Code Text Area with Line Numbers
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Line Number Gutter
                Container(
                  width: 48,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: AppColors.crust,
                  child: ListView.builder(
                    controller: _lineScrollController,
                    itemCount: lineCount,
                    itemBuilder: (context, index) {
                      return SizedBox(
                        height: 22,
                        child: Text(
                          '${index + 1}',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.firaCode(
                            color: AppColors.surface2,
                            fontSize: 13,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const VerticalDivider(color: AppColors.surface0, width: 1),

                // Editor
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: TextField(
                      controller: _controller,
                      scrollController: _scrollController,
                      maxLines: null,
                      expands: true,
                      keyboardType: TextInputType.multiline,
                      style: GoogleFonts.firaCode(
                        color: AppColors.text,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      cursorColor: AppColors.blue,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: '// Enter C source code here...\nvoid example() {\n\t// your code\n}',
                        hintStyle: TextStyle(color: AppColors.surface1),
                      ),
                      onChanged: (val) {
                        provider.setCode(val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
