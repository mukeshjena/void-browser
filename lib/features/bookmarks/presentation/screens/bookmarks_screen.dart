import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../providers/bookmarks_provider.dart';
import '../widgets/bookmark_item_widget.dart';
import '../../../browser/presentation/utils/tab_utils.dart';

class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use select to only watch bookmarks list, not entire state
    final bookmarks = ref.watch(bookmarksProvider.select((state) => state));
    final filteredBookmarks = _searchQuery.isEmpty
        ? bookmarks
        : ref.read(bookmarksProvider.notifier).searchBookmarks(_searchQuery);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () {
              // Export bookmarks
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export coming soon')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search bookmarks...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: filteredBookmarks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bookmark_border, size: 64),
                        const SizedBox(height: AppDimensions.md),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No bookmarks yet'
                              : 'No results found',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppDimensions.sm),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Tap the star icon while browsing to save pages'
                              : 'Try a different search term',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : RepaintBoundary(
                    child: ListView.builder(
                      itemCount: filteredBookmarks.length,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.sm,
                      ),
                      itemBuilder: (context, index) {
                        final bookmark = filteredBookmarks[index];
                        return BookmarkItemWidget(
                          key: ValueKey('bookmark_${bookmark.id}_$index'),
                          bookmark: bookmark,
                          onTap: () {
                            // Navigate to URL in browser
                            Navigator.pop(context);
                            // Open bookmark URL in current tab
                            TabUtils.openInCurrentTab(ref, bookmark.url);
                          },
                          onDelete: () async {
                            await ref
                                .read(bookmarksProvider.notifier)
                                .deleteBookmark(bookmark.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Bookmark deleted'),
                                ),
                              );
                            }
                          },
                          onEdit: () {
                            _showEditDialog(context, bookmark);
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, bookmark) {
    final titleController = TextEditingController(text: bookmark.title);
    final urlController = TextEditingController(text: bookmark.url);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Bookmark'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(bookmarksProvider.notifier).updateBookmark(
                    bookmark.copyWith(
                      title: titleController.text,
                      url: urlController.text,
                    ),
                  );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

