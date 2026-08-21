import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/explorer_provider.dart';
import '../screens/docs_screen.dart';
import '../theme/app_colors.dart';
import 'tag_badge.dart';

class SnippetDatabaseDrawer extends StatelessWidget {
  const SnippetDatabaseDrawer({super.key});

  void _confirmDelete(BuildContext context, ExplorerProvider provider, String snippetId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.base,
        title: const Text('Delete Snippet', style: TextStyle(color: AppColors.text)),
        content: Text('Are you sure you want to delete "$title"?', style: const TextStyle(color: AppColors.subtext0)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.subtext0)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: AppColors.crust),
            onPressed: () {
              Navigator.of(ctx).pop();
              provider.deleteSnippet(snippetId);
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExplorerProvider>();
    final snippets = provider.snippets;
    final categories = provider.categories;

    return Drawer(
      backgroundColor: AppColors.mantle,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.base,
              child: Row(
                children: [
                  const Icon(Icons.storage, color: AppColors.blue, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'C Snippet Database',
                          style: TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Presets & Saved C Programs',
                          style: TextStyle(color: AppColors.subtext0, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.subtext0),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Hardware Docs Shortcut Tile
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Material(
                color: AppColors.surface0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppColors.blue),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.menu_book, color: AppColors.blue),
                  title: const Text(
                    'Hardware ISA & Opcodes',
                    style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: const Text(
                    'Database of instructions and encodings',
                    style: TextStyle(color: AppColors.subtext0, fontSize: 11),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, color: AppColors.blue, size: 14),
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
                style: const TextStyle(color: AppColors.text, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search snippets...',
                  hintStyle: const TextStyle(color: AppColors.surface2),
                  prefixIcon: const Icon(Icons.search, color: AppColors.blue, size: 20),
                  filled: true,
                  fillColor: AppColors.base,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.surface0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.surface0),
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
                            color: isSelected ? AppColors.crust : AppColors.text,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        backgroundColor: AppColors.base,
                        selectedColor: AppColors.blue,
                        checkmarkColor: AppColors.crust,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        onSelected: (_) => provider.setSelectedCategory(cat),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],

            const Divider(color: AppColors.surface0, height: 1),

            // Snippet List
            Expanded(
              child: snippets.isEmpty
                  ? const Center(
                      child: Text('No snippets found.', style: TextStyle(color: AppColors.overlay0)),
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
                            color: isCurrent ? AppColors.surface0 : AppColors.base,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isCurrent ? AppColors.blue : const Color(0xFF2A2B3D),
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
                                        color: isCurrent ? AppColors.blue : AppColors.text,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  if (snippet.isPreset)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.crust,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'PRESET',
                                        style: TextStyle(color: AppColors.yellow, fontSize: 9, fontWeight: FontWeight.bold),
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
                                    style: const TextStyle(color: AppColors.subtext0, fontSize: 11),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: [
                                      TagBadge(snippet.category, color: AppColors.mauve),
                                      TagBadge('${snippet.recommendedArch.id.toUpperCase()} ${snippet.recommendedOpt.flag}', color: AppColors.green),
                                      if (snippet.recommendedFeatureIds.isNotEmpty)
                                        TagBadge(snippet.recommendedFeatureIds.join('+'), color: AppColors.red),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: !snippet.isPreset
                                  ? IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppColors.red, size: 18),
                                      onPressed: () => _confirmDelete(context, provider, snippet.id, snippet.title),
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
}
