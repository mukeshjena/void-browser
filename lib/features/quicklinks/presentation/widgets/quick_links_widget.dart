import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/quick_links_provider.dart';
import '../../../browser/presentation/utils/tab_utils.dart';
import '../../domain/entities/quick_link_entity.dart';
import 'add_quick_link_dialog.dart';

class QuickLinksWidget extends ConsumerWidget {
  const QuickLinksWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quickLinksState = ref.watch(quickLinksProvider);
    final links = quickLinksState.links;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        height: 80,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: links.length + 1, // +1 for add button
          itemBuilder: (context, index) {
          if (index == links.length) {
            // Add button
            return _AddQuickLinkButton(
              onTap: () async {
                final result = await showDialog<Map<String, String>>(
                  context: context,
                  builder: (context) => const AddQuickLinkDialog(),
                );
                if (result != null && context.mounted) {
                  try {
                    await ref.read(quickLinksProvider.notifier).addQuickLink(
                      result['name']!,
                      result['url']!,
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to add quick link: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
            );
          }
          final link = links[index];
          return _QuickLinkItem(
            link: link,
            onTap: () {
              TabUtils.openInCurrentTab(ref, link.url);
            },
            onLongPress: () async {
              // Show delete option
              final shouldDelete = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Quick Link'),
                  content: Text('Are you sure you want to delete "${link.name}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (shouldDelete == true && context.mounted) {
                await ref.read(quickLinksProvider.notifier).removeQuickLink(link.id);
              }
            },
          );
        },
        ),
      ),
    );
  }
}

class _QuickLinkItem extends StatelessWidget {
  final QuickLinkEntity link;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _QuickLinkItem({
    required this.link,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 70,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: link.iconUrl != null
                  ? CachedNetworkImage(
                      imageUrl: link.iconUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        width: 56,
                        height: 56,
                        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
                        child: Icon(
                          Icons.link,
                          color: isDark ? Colors.white70 : Colors.black54,
                          size: 24,
                        ),
                      ),
                      placeholder: (context, url) => Container(
                        width: 56,
                        height: 56,
                        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
                      child: Icon(
                        Icons.link,
                        color: isDark ? Colors.white70 : Colors.black54,
                        size: 24,
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            // Name
            Text(
              link.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddQuickLinkButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddQuickLinkButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Add icon container
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.add,
                color: isDark ? Colors.white70 : Colors.black54,
                size: 28,
              ),
            ),
            const SizedBox(height: 6),
            // Add text
            Text(
              'Add',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

