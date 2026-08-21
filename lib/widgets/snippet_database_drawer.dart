import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/snippet.dart';
import '../providers/explorer_provider.dart';
import '../screens/docs_screen.dart';

class SnippetDatabaseDrawer extends StatelessWidget {
  const SnippetDatabaseDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExplorerProvider>();
    final snippets = provider.snippets;
    final categories = provider.categories;

    return Drawer(
      backgroundColor: const Color(0xFF181825),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF1E1E2E),
              child: Row(
                children: [
                  const Icon(Icons.storage, color: Color(0xFF89B4FA), size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'C Snippet Database',
                          style: TextStyle(
                            color: Color(0xFFCDD6F4),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Presets & Saved C Programs',
                          style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 12),
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
            ),

            // Hardware Docs Shortcut Tile
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Material(
                color: const Color(0xFF313244),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFF89B4FA)),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.menu_book, color: Color(0xFF89B4FA)),
                  title: const Text(
                    'Hardware ISA & Opcodes',
                    style: TextStyle(color: Color(0xFFCDD6F4), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: const Text(
                    'Database of instructions and encodings',
                    style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 11),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF89B4FA), size: 14),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DocsScreen()),
                    );
                  },
                ),
              ),
            ),

            // Search Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: TextField(
                style: const TextStyle(color: Color(0xFFCDD6F4), fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search snippets...',
                  hintStyle: const TextStyle(color: Color(0xFF585B70)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF89B4FA), size: 20),
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
                onChanged: (val) => provider.setSearchQuery(val),
              ),
            ),

            // Category Filter Chips
            if (categories.isNotEmpty) ...[
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = provider.selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected ? const Color(0xFF11111B) : const Color(0xFFCDD6F4),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        backgroundColor: const Color(0xFF1E1E2E),
                        selectedColor: const Color(0xFF89B4FA),
                        checkmarkColor: const Color(0xFF11111B),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        onSelected: (_) => provider.setSelectedCategory(cat),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],

            const Divider(color: Color(0xFF313244), height: 1),

            // Snippet List
            Expanded(
              child: snippets.isEmpty
                  ? const Center(
                      child: Text('No snippets found.', style: TextStyle(color: Color(0xFF6C7086))),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: snippets.length,
                      itemBuilder: (context, index) {
                        final snippet = snippets[index];
                        final isCurrent = provider.currentSnippet?.id == snippet.id;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: isCurrent ? const Color(0xFF313244) : const Color(0xFF1E1E2E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isCurrent ? const Color(0xFF89B4FA) : const Color(0xFF2A2B3D),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    snippet.title,
                                    style: TextStyle(
                                      color: isCurrent ? const Color(0xFF89B4FA) : const Color(0xFFCDD6F4),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (snippet.isPreset)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF11111B),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'PRESET',
                                      style: TextStyle(color: Color(0xFFF9E2AF), fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  snippet.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Color(0xFFA6ADC8), fontSize: 11),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: [
                                    _buildTag(snippet.category, const Color(0xFFCBA6F7)),
                                    _buildTag('${snippet.recommendedArch.id.toUpperCase()} ${snippet.recommendedOpt.flag}', const Color(0xFFA6E3A1)),
                                    if (snippet.recommendedFeatureIds.isNotEmpty)
                                      _buildTag(snippet.recommendedFeatureIds.join('+'), const Color(0xFFF38BA8)),
                                  ],
                                ),
                              ],
                            ),
                            trailing: !snippet.isPreset
                                ? IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Color(0xFFF38BA8), size: 18),
                                    onPressed: () {
                                      provider.deleteSnippet(snippet.id);
                                    },
                                  )
                                : null,
                            onTap: () {
                              provider.loadSnippet(snippet);
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}
