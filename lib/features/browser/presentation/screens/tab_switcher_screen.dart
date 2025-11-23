import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tabs_provider.dart';
import '../../domain/entities/tab_entity.dart';

class TabSwitcherScreen extends ConsumerWidget {
  const TabSwitcherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabsState = ref.watch(tabsProvider);
    final tabs = tabsState.tabs;
    final activeTabId = tabsState.activeTabId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Tabs (${tabs.length})',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDark ? Colors.black : Colors.grey[100],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              ref.read(tabsProvider.notifier).createNewTab();
              Navigator.pop(context);
            },
            tooltip: 'New Tab',
          ),
          if (tabs.length > 1)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'close_all') {
                  ref.read(tabsProvider.notifier).closeAllTabs();
                  Navigator.pop(context);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'close_all',
                  child: Row(
                    children: [
                      Icon(Icons.close, size: 20),
                      SizedBox(width: 12),
                      Text('Close All Tabs'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: tabs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.tab,
                    size: 64,
                    color: isDark ? Colors.grey[700] : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tabs open',
                    style: TextStyle(
                      fontSize: 18,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(tabsProvider.notifier).createNewTab();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('New Tab'),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: tabs.length,
              itemBuilder: (context, index) {
                final tab = tabs[index];
                final isActive = tab.id == activeTabId;
                return _TabCard(
                  tab: tab,
                  isActive: isActive,
                  onTap: () {
                    ref.read(tabsProvider.notifier).switchToTab(tab.id);
                    Navigator.pop(context);
                  },
                  onClose: () {
                    ref.read(tabsProvider.notifier).closeTab(tab.id);
                  },
                );
              },
            ),
    );
  }
}

class _TabCard extends StatelessWidget {
  final TabEntity tab;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TabCard({
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDiscover = tab.url == 'discover';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? Colors.grey[900] : Colors.white)
              : (isDark ? Colors.grey[800] : Colors.grey[200]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? (isDark ? Colors.blue : Colors.blue[300]!)
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Tab content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Favicon or icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDiscover
                          ? (isDark ? Colors.blue[900] : Colors.blue[100])
                          : (isDark ? Colors.grey[700] : Colors.grey[300]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isDiscover ? Icons.explore : Icons.language,
                      color: isDiscover
                          ? (isDark ? Colors.blue[300] : Colors.blue[700])
                          : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Title
                  Expanded(
                    child: Text(
                      isDiscover
                          ? 'Discover'
                          : (tab.title ?? _getDomainFromUrl(tab.url)),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // URL
                  Text(
                    isDiscover ? 'Home' : _getDomainFromUrl(tab.url),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Close button
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDomainFromUrl(String url) {
    try {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        final uri = Uri.parse(url);
        return uri.host;
      }
      return url.length > 30 ? '${url.substring(0, 30)}...' : url;
    } catch (e) {
      return url.length > 30 ? '${url.substring(0, 30)}...' : url;
    }
  }
}

