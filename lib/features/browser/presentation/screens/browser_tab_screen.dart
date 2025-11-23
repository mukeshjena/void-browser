import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../shared/widgets/chrome_webview.dart';
import '../../../../shared/widgets/chrome_search_bar.dart';
import '../../../bookmarks/presentation/providers/bookmarks_provider.dart';
import '../../../bookmarks/presentation/screens/bookmarks_screen.dart';
import '../../../downloads/presentation/screens/downloads_screen_new.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../discover/presentation/screens/discover_screen.dart';
import '../../../../core/constants/api_constants.dart';
import '../providers/tabs_provider.dart';
import '../screens/tab_switcher_screen.dart';

/// Browser screen with tab support
class BrowserTabScreen extends ConsumerStatefulWidget {
  const BrowserTabScreen({super.key});

  @override
  ConsumerState<BrowserTabScreen> createState() => _BrowserTabScreenState();
}

class _BrowserTabScreenState extends ConsumerState<BrowserTabScreen> {
  final Map<String, ChromeWebViewController> _webViewControllers = {};
  final Map<String, TextEditingController> _urlControllers = {};
  final Map<String, String> _currentUrls = {};
  final Map<String, String?> _currentTitles = {};
  final Map<String, bool> _isAppBarVisible = {};
  final Map<String, int> _lastScrollY = {};
  final Map<String, bool> _isLoadingUrl = {}; // Track if URL is being loaded
  final Map<String, String> _lastLoadedUrl = {}; // Track last URL we loaded to prevent duplicates
  final Map<String, DateTime> _lastLoadTime = {}; // Track when URL was last loaded for debouncing
  final Map<String, bool> _isInternalLoad = {}; // Track if we initiated the load (not external)
  final Map<String, List<String>> _navigationHistory = {}; // Track navigation history per tab
  static const int _scrollThreshold = 10;
  static const int _debounceMs = 1000; // 1 second debounce

  @override
  void dispose() {
    for (var controller in _urlControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _getValidUrlForWebView(String? url) {
    if (url == null || url.isEmpty) return null;
    final trimmed = url.trim();
    // Reject "discover" in all forms
    if (trimmed == 'discover' || 
        trimmed == 'http://discover' || 
        trimmed == 'https://discover' ||
        trimmed == 'http://discover/' ||
        trimmed == 'https://discover/') {
      return null; // Don't pass "discover" to WebView
    }
    return url;
  }

  void _goBackToDiscover(String tabId, WidgetRef ref) {
    // Clear navigation history
    _navigationHistory[tabId] = [];
    
    // Update tab to discover
    ref.read(tabsProvider.notifier).updateTab(tabId: tabId, url: 'discover');
    
    // Update local state
    setState(() {
      _currentUrls[tabId] = 'discover';
      if (_urlControllers[tabId] != null) {
        _urlControllers[tabId]!.text = '';
      }
    });
  }

  void _handleScroll(String tabId, int x, int y) {
    final delta = y - (_lastScrollY[tabId] ?? 0);
    if (delta.abs() > _scrollThreshold) {
      if (delta > 0 && (_isAppBarVisible[tabId] ?? true)) {
        setState(() {
          _isAppBarVisible[tabId] = false;
        });
      } else if (delta < 0 && !(_isAppBarVisible[tabId] ?? true)) {
        setState(() {
          _isAppBarVisible[tabId] = true;
        });
      }
      _lastScrollY[tabId] = y;
    }
  }

  void _loadUrl(String tabId, String input, WidgetRef ref, {bool addToHistory = true}) {
    if (input.isEmpty) return;
    
    // Prevent "discover" from being treated as a URL
    if (input.trim() == 'discover' || input.trim() == 'http://discover' || input.trim() == 'https://discover' || 
        input.trim() == 'http://discover/' || input.trim() == 'https://discover/') {
      return; // Don't load "discover" as a URL
    }
    
    String url;
    if (input.contains('.') && !input.contains(' ')) {
      if (!input.startsWith('http://') && !input.startsWith('https://')) {
        url = 'https://$input';
      } else {
        url = input;
      }
    } else {
      final settings = ref.read(settingsProvider);
      url = ApiConstants.getSearchUrl(settings.searchEngine, input);
    }

    // Debounce: Check if we loaded this URL very recently
    final lastLoadTime = _lastLoadTime[tabId];
    if (lastLoadTime != null && _lastLoadedUrl[tabId] == url) {
      final timeSinceLastLoad = DateTime.now().difference(lastLoadTime).inMilliseconds;
      if (timeSinceLastLoad < _debounceMs) {
        return; // Too soon, ignore
      }
    }

    // Prevent duplicate loads - check if we're already loading this exact URL
    if (_isLoadingUrl[tabId] == true && _lastLoadedUrl[tabId] == url) {
      return;
    }
    
    // Prevent duplicate loads - check if this URL is already the current URL
    if (_currentUrls[tabId] == url && _webViewControllers[tabId] != null) {
      return;
    }

    _isLoadingUrl[tabId] = true;
    _lastLoadedUrl[tabId] = url;
    _lastLoadTime[tabId] = DateTime.now();
    _isInternalLoad[tabId] = true; // Mark as internal load

    // Add current URL to navigation history before loading new one
    if (addToHistory) {
      if (!_navigationHistory.containsKey(tabId)) {
        _navigationHistory[tabId] = [];
      }
      final currentUrl = _currentUrls[tabId] ?? 'discover';
      // Only add to history if it's not discover and not already in history
      if (currentUrl != 'discover' && 
          currentUrl != url && 
          !_navigationHistory[tabId]!.contains(currentUrl)) {
        _navigationHistory[tabId]!.add(currentUrl);
      }
    }

    // Update state
    setState(() {
      _currentUrls[tabId] = url;
      if (_urlControllers[tabId] != null) {
        _urlControllers[tabId]!.text = url;
      }
    });

    // Load URL in WebView if it exists, otherwise update tab (will create WebView)
    if (_webViewControllers[tabId] != null) {
      _webViewControllers[tabId]!.loadUrl(url);
    }
    ref.read(tabsProvider.notifier).updateTab(tabId: tabId, url: url);
    
    // Reset loading flag after a delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _isLoadingUrl[tabId] = false;
        // Reset internal load flag after a bit longer to prevent rebuild triggers
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _isInternalLoad[tabId] = false;
          }
        });
      }
    });
  }

  void _showChromeMenu(String tabId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Menu',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.topRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 280,
              height: MediaQuery.of(context).size.height * 0.85,
              margin: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                right: 8,
                bottom: 8,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(-2, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildQuickActionButton(
                          context,
                          icon: Icons.arrow_forward,
                          label: '',
                          onTap: () async {
                            Navigator.pop(context);
                            if (await _webViewControllers[tabId]?.canGoForward() ?? false) {
                              _webViewControllers[tabId]?.goForward();
                            }
                          },
                        ),
                        _buildQuickActionButton(
                          context,
                          icon: Icons.refresh,
                          label: '',
                          onTap: () {
                            Navigator.pop(context);
                            _webViewControllers[tabId]?.reload();
                          },
                        ),
                        _buildQuickActionButton(
                          context,
                          icon: Icons.bookmark_add,
                          label: '',
                          onTap: () async {
                            Navigator.pop(context);
                            final url = _currentUrls[tabId] ?? '';
                            if (url.isNotEmpty && url != 'discover') {
                              await ref.read(bookmarksProvider.notifier).addBookmark(
                                title: _currentTitles[tabId]?.isEmpty ?? true
                                    ? 'New Bookmark'
                                    : _currentTitles[tabId]!,
                                url: url,
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('✓ Bookmark added!')),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _buildBrowserMenuItem(
                          context,
                          icon: Icons.add,
                          title: 'New Tab',
                          onTap: () {
                            Navigator.pop(context);
                            ref.read(tabsProvider.notifier).createNewTab();
                            // Clear the controller for the new tab when it becomes active
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              final newTabsState = ref.read(tabsProvider);
                              final newActiveTab = newTabsState.activeTab;
                              if (newActiveTab != null && newActiveTab.url == 'discover') {
                                final newTabId = newActiveTab.id;
                                if (!_urlControllers.containsKey(newTabId)) {
                                  _urlControllers[newTabId] = TextEditingController(text: '');
                                } else {
                                  _urlControllers[newTabId]!.text = '';
                                }
                                _currentUrls[newTabId] = 'discover';
                              }
                            });
                          },
                        ),
                        _buildBrowserMenuItem(
                          context,
                          icon: Icons.delete_sweep,
                          title: 'Close All Tabs',
                          onTap: () {
                            Navigator.pop(context);
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Close All Tabs?'),
                                content: const Text('Are you sure you want to close all open tabs?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      ref.read(tabsProvider.notifier).closeAllTabs();
                                      // Clear controllers for closed tabs
                                      final remainingTabsState = ref.read(tabsProvider);
                                      final remainingTabIds = remainingTabsState.tabs.map((t) => t.id).toSet();
                                      _urlControllers.removeWhere((key, value) => !remainingTabIds.contains(key));
                                      _currentUrls.removeWhere((key, value) => !remainingTabIds.contains(key));
                                      _currentTitles.removeWhere((key, value) => !remainingTabIds.contains(key));
                                      _isAppBarVisible.removeWhere((key, value) => !remainingTabIds.contains(key));
                                      _lastScrollY.removeWhere((key, value) => !remainingTabIds.contains(key));
                                      // Initialize controller for new discover tab
                                      final newActiveTab = remainingTabsState.activeTab;
                                      if (newActiveTab != null) {
                                        final newTabId = newActiveTab.id;
                                        if (!_urlControllers.containsKey(newTabId)) {
                                          _urlControllers[newTabId] = TextEditingController(text: '');
                                        } else {
                                          _urlControllers[newTabId]!.text = '';
                                        }
                                        _currentUrls[newTabId] = 'discover';
                                      }
                                    },
                                    child: const Text('Close All', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                        _buildBrowserMenuItem(
                          context,
                          icon: Icons.bookmarks,
                          title: 'Bookmarks',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const BookmarksScreen()),
                            );
                          },
                        ),
                        _buildBrowserMenuItem(
                          context,
                          icon: Icons.share,
                          title: 'Share',
                          onTap: () async {
                            Navigator.pop(context);
                            final url = _currentUrls[tabId] ?? '';
                            if (url.isNotEmpty && url != 'discover') {
                              await Share.share(url, subject: _currentTitles[tabId]);
                            }
                          },
                        ),
                        _buildBrowserMenuItem(
                          context,
                          icon: Icons.content_copy,
                          title: 'Copy Link',
                          onTap: () async {
                            Navigator.pop(context);
                            final url = _currentUrls[tabId] ?? '';
                            if (url.isNotEmpty && url != 'discover') {
                              await Clipboard.setData(ClipboardData(text: url));
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('✓ Link copied to clipboard')),
                                );
                              }
                            }
                          },
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                        _buildBrowserMenuItem(
                          context,
                          icon: Icons.download,
                          title: 'Downloads',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const DownloadsScreenNew()),
                            );
                          },
                        ),
                        _buildBrowserMenuItem(
                          context,
                          icon: Icons.settings,
                          title: 'Settings',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SettingsScreen()),
                            );
                          },
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                        
                        _buildBrowserMenuItem(
                          context,
                          icon: Icons.exit_to_app,
                          title: 'Exit',
                          onTap: () {
                            Navigator.pop(context);
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Exit Void?'),
                                content: const Text('Are you sure you want to exit the application?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      SystemNavigator.pop();
                                    },
                                    child: const Text('Exit', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Icon(icon, size: 28),
      ),
    );
  }

  Widget _buildBrowserMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabsState = ref.watch(tabsProvider);
    final activeTab = tabsState.activeTab;
    final tabCount = tabsState.tabCount;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (activeTab == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final tabId = activeTab.id;
    final isDiscover = activeTab.url == 'discover';

    // Initialize controllers for this tab if not exists
    if (!_urlControllers.containsKey(tabId)) {
      _urlControllers[tabId] = TextEditingController(text: isDiscover ? '' : activeTab.url);
      _currentUrls[tabId] = activeTab.url;
      _currentTitles[tabId] = activeTab.title;
      _isAppBarVisible[tabId] = true;
      _navigationHistory[tabId] = [];
    } else {
      // Update controller text when switching tabs to show current tab's URL
      final currentUrl = isDiscover ? '' : (_currentUrls[tabId] ?? activeTab.url);
      if (_urlControllers[tabId]!.text != currentUrl) {
        _urlControllers[tabId]!.text = currentUrl;
      }
      
      // Check if tab URL was updated externally (e.g., from TabUtils)
      // Only load if it's NOT an internal load (we didn't just call _loadUrl ourselves)
      if (!isDiscover && activeTab.url != 'discover' && 
          activeTab.url != _currentUrls[tabId] && 
          _webViewControllers[tabId] != null &&
          _isLoadingUrl[tabId] != true &&
          _lastLoadedUrl[tabId] != activeTab.url &&
          _isInternalLoad[tabId] != true) { // Only if NOT an internal load
        // Check debounce
        final lastLoadTime = _lastLoadTime[tabId];
        final shouldLoad = lastLoadTime == null || 
            DateTime.now().difference(lastLoadTime).inMilliseconds >= _debounceMs;
        
        if (shouldLoad) {
          // URL was updated externally, load it in WebView
          _isInternalLoad[tabId] = false; // Mark as external
          _loadUrl(tabId, activeTab.url, ref);
        }
      } else if (_isInternalLoad[tabId] == true) {
        // Reset internal load flag after processing
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _isInternalLoad[tabId] = false;
          }
        });
      }
    }

    final appBarHeight = kToolbarHeight + MediaQuery.of(context).padding.top;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        
        // If it's discover page, allow normal pop or exit app
        if (isDiscover) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            SystemNavigator.pop();
          }
          return;
        }
        
        // Check if WebView can go back
        final webViewController = _webViewControllers[tabId];
        if (webViewController != null) {
          final canGoBack = await webViewController.canGoBack();
          if (canGoBack) {
            // Go back in browser history
            webViewController.goBack();
          } else {
            // WebView has no history, check if we came from discover
            // If this is the first page loaded from discover, go back to discover
            final history = _navigationHistory[tabId] ?? [];
            if (history.isEmpty) {
              // This is the first page after discover, go back to discover
              _goBackToDiscover(tabId, ref);
            } else {
              // We have history, go to previous URL (don't add to history when going back)
              final previousUrl = history.removeLast();
              _loadUrl(tabId, previousUrl, ref, addToHistory: false);
            }
          }
        } else {
          // No WebView controller, go back to discover
          _goBackToDiscover(tabId, ref);
        }
      },
      child: Scaffold(
        body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            height: (_isAppBarVisible[tabId] ?? true) ? appBarHeight : MediaQuery.of(context).padding.top,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: (_isAppBarVisible[tabId] ?? true) ? 1.0 : 0.0,
              child: AppBar(
                automaticallyImplyLeading: false,
                title: ChromeSearchBar(
                  controller: _urlControllers[tabId]!,
                  currentUrl: isDiscover ? null : _currentUrls[tabId],
                  onSubmitted: (value) => _loadUrl(tabId, value, ref),
                  onChanged: (value) {},
                  showMenu: false,
                ),
                actions: [
                  // New Tab button
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      ref.read(tabsProvider.notifier).createNewTab();
                      // Clear the controller for the new tab when it becomes active
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final newTabsState = ref.read(tabsProvider);
                        final newActiveTab = newTabsState.activeTab;
                        if (newActiveTab != null && newActiveTab.url == 'discover') {
                          final newTabId = newActiveTab.id;
                          if (!_urlControllers.containsKey(newTabId)) {
                            _urlControllers[newTabId] = TextEditingController(text: '');
                          } else {
                            _urlControllers[newTabId]!.text = '';
                          }
                          _currentUrls[newTabId] = 'discover';
                        }
                      });
                    },
                    tooltip: 'New Tab',
                  ),
                  // Tab count indicator
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const TabSwitcherScreen()),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tab,
                            size: 18,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$tabCount',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showChromeMenu(tabId),
                    tooltip: 'Menu',
                  ),
                ],
                titleSpacing: 8,
                backgroundColor: isDark ? Colors.black : Colors.white,
                elevation: 0,
              ),
            ),
          ),
          Expanded(
            child: isDiscover
                ? const DiscoverScreen()
                : ChromeWebView(
                    // Use tabId as key to maintain WebView instance and preserve history
                    key: ValueKey('webview_$tabId'),
                    initialUrl: _getValidUrlForWebView(_currentUrls[tabId] ?? activeTab.url),
                    onWebViewCreated: (controller) {
                      _webViewControllers[tabId] = controller;
                      // Load URL if it was set before WebView was created
                      final urlToLoad = _currentUrls[tabId] ?? activeTab.url;
                      if (urlToLoad != 'discover' && urlToLoad.isNotEmpty && 
                          urlToLoad != 'http://discover' && urlToLoad != 'https://discover' &&
                          urlToLoad != 'http://discover/' && urlToLoad != 'https://discover/') {
                        // Small delay to ensure WebView is ready
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (mounted && _webViewControllers[tabId] != null) {
                            controller.loadUrl(urlToLoad);
                          }
                        });
                      }
                    },
                    onUrlChanged: (url) async {
                      // Prevent duplicate updates - check if URL actually changed
                      if (_currentUrls[tabId] == url) {
                        _isLoadingUrl[tabId] = false; // Reset loading flag even if URL is same
                        return;
                      }
                      
                      // Debounce: Don't update if this URL was just loaded
                      final lastLoadTime = _lastLoadTime[tabId];
                      if (lastLoadTime != null && _lastLoadedUrl[tabId] == url) {
                        final timeSinceLastLoad = DateTime.now().difference(lastLoadTime).inMilliseconds;
                        if (timeSinceLastLoad < _debounceMs) {
                          // This is likely the same load, just update state without triggering tab update
                          setState(() {
                            _currentUrls[tabId] = url;
                            _isLoadingUrl[tabId] = false;
                            if (_urlControllers[tabId] != null && _urlControllers[tabId]!.text != url) {
                              _urlControllers[tabId]!.text = url;
                            }
                          });
                          return;
                        }
                      }
                      
                      // Update controller text immediately to show current URL
                      if (_urlControllers[tabId] != null && _urlControllers[tabId]!.text != url) {
                        _urlControllers[tabId]!.text = url;
                      }
                      setState(() {
                        _currentUrls[tabId] = url;
                        _isLoadingUrl[tabId] = false; // Reset loading flag
                        _lastLoadedUrl[tabId] = url; // Update last loaded URL
                        _lastLoadTime[tabId] = DateTime.now(); // Update load time
                      });
                      final title = await _webViewControllers[tabId]?.currentTitle() ?? '';
                      setState(() {
                        _currentTitles[tabId] = title;
                      });
                      ref.read(tabsProvider.notifier).updateTab(
                            tabId: tabId,
                            url: url,
                            title: title,
                          );
                    },
                    onScrollChanged: (x, y) => _handleScroll(tabId, x, y),
                  ),
          ),
        ],
      ),
      ),
    );
  }
}

