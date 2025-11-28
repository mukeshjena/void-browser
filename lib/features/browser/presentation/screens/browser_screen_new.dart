import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../shared/widgets/chrome_webview.dart';
import '../../../../shared/widgets/chrome_search_bar.dart';
import '../../../../shared/widgets/find_in_page_overlay.dart';
import '../../../bookmarks/presentation/providers/bookmarks_provider.dart';
import '../../../bookmarks/presentation/screens/bookmarks_screen.dart';
import '../../../downloads/presentation/screens/downloads_screen_new.dart';
import '../../../downloads/presentation/providers/download_manager_provider.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../reader_mode/presentation/screens/reader_mode_screen.dart';
import '../providers/desktop_mode_provider.dart';
import '../../../../core/constants/api_constants.dart';

/// Simple browser screen with Chrome-like UX
/// - No tabs, just a single WebView
/// - Swipe gestures for back/forward
/// - Pull to refresh
/// - 3-dot menu for actions
class BrowserScreenFullPage extends ConsumerStatefulWidget {
  final String? initialUrl;
  
  const BrowserScreenFullPage({
    super.key,
    this.initialUrl,
  });

  @override
  ConsumerState<BrowserScreenFullPage> createState() => _BrowserScreenFullPageState();
}

class _BrowserScreenFullPageState extends ConsumerState<BrowserScreenFullPage> {
  final TextEditingController _urlController = TextEditingController();
  ChromeWebViewController? _webViewController;
  String _currentUrl = '';
  String _currentTitle = '';
  
  // AppBar visibility management
  bool _isAppBarVisible = true;
  
  // Find in page state
  ValueNotifier<int>? _findActiveMatch;
  ValueNotifier<int>? _findTotalMatches;
  OverlayEntry? _findOverlayEntry;
  int _lastScrollY = 0;
  DateTime? _lastScrollUpdate; // Debounce scroll updates
  static const int _scrollThreshold = 20; // Increased threshold to prevent flickering
  static const int _scrollDebounceMs = 150; // Debounce time for scroll updates

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _handleScroll(int x, int y) {
    // Don't hide app bar on discover page or when URL is empty/discover
    final isDiscover = _currentUrl == 'discover' || 
                       _currentUrl.isEmpty || 
                       _currentUrl == 'http://discover' || 
                       _currentUrl == 'https://discover';
    
    if (isDiscover) {
      // Always show app bar on discover page
      if (!_isAppBarVisible) {
        setState(() {
          _isAppBarVisible = true;
        });
      }
      return;
    }
    
    final now = DateTime.now();
    
    // Debounce scroll updates to reduce setState calls and prevent flickering
    if (_lastScrollUpdate != null && now.difference(_lastScrollUpdate!).inMilliseconds < _scrollDebounceMs) {
      // Update last scroll position but don't process yet
      _lastScrollY = y;
      return;
    }
    
    // Calculate scroll delta
    final scrollDelta = y - _lastScrollY;
    
    // Only react to significant scroll changes to prevent flickering
    if (scrollDelta.abs() < _scrollThreshold) {
      _lastScrollY = y;
      return;
    }
    
    // Determine if app bar should be visible (show when scrolling up, hide when scrolling down)
    final shouldShow = scrollDelta < 0; // Negative delta means scrolling up
    
    // Only update if state actually changed to prevent unnecessary rebuilds
    if (shouldShow != _isAppBarVisible && mounted) {
      _lastScrollUpdate = now;
      _lastScrollY = y;
      setState(() {
        _isAppBarVisible = shouldShow;
      });
    } else {
      // Update scroll position even if state didn't change
      _lastScrollY = y;
    }
  }

  void _loadUrl(String input, WidgetRef ref) {
    if (input.isEmpty) return;
    
    // Format URL properly
    String url;
    if (input.contains('.') && !input.contains(' ')) {
      // Looks like a URL
      if (!input.startsWith('http://') && !input.startsWith('https://')) {
        url = 'https://$input';
      } else {
        url = input;
      }
    } else {
      // It's a search query - use selected search engine
      final settings = ref.read(settingsProvider);
      url = ApiConstants.getSearchUrl(settings.searchEngine, input);
    }
    
    _webViewController?.loadUrl(url);
  }

  void _showChromeMenu() {
    // Chrome-style slide from right with better visibility
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Menu',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Align(
          alignment: Alignment.topRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 280,
              height: MediaQuery.of(context).size.height * 0.85, // Reduced height
              margin: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10, // Moved down by 70px
                right: 8,
                bottom: 8,
              ), // Moved down
              decoration: BoxDecoration(
                color: isDark 
                  ? const Color(0xFF2D2D2D) // Lighter gray for dark mode
                  : Colors.white,
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
                  // Quick Action Icons Row (no header)
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
                            if (await _webViewController?.canGoForward() ?? false) {
                              _webViewController?.goForward();
                            }
                          },
                        ),
                        _buildQuickActionButton(
                          context,
                          icon: Icons.refresh,
                          label: '',
                          onTap: () {
                            Navigator.pop(context);
                            _webViewController?.reload();
                          },
                        ),
                        _buildQuickActionButton(
                          context,
                          icon: Icons.bookmark_add,
                          label: '',
                          onTap: () async {
                            Navigator.pop(context);
                            if (_currentUrl.isNotEmpty) {
                              final wasAdded = await ref.read(bookmarksProvider.notifier).addBookmark(
                                title: _currentTitle.isEmpty ? 'New Bookmark' : _currentTitle,
                                url: _currentUrl,
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(wasAdded 
                                      ? '✓ Bookmark added!' 
                                      : '✓ Bookmark already exists (updated)'),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  // Menu Items
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        // Page Actions
                        _buildBrowserMenuItem(
                          context,
                          icon: Icons.bookmarks,
                          title: 'View Bookmarks',
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
                          title: 'Share Page',
                          onTap: () async {
                            Navigator.pop(context);
                            if (_currentUrl.isNotEmpty) {
                              await Share.share(_currentUrl, subject: _currentTitle);
                            }
                          },
                        ),
                        _buildBrowserMenuItem(
                          context,
                          icon: Icons.content_copy,
                          title: 'Copy Link',
                          onTap: () async {
                            Navigator.pop(context);
                            if (_currentUrl.isNotEmpty) {
                              await Clipboard.setData(ClipboardData(text: _currentUrl));
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
                        
                        // View Options
                        _buildBrowserMenuItemWithCheckbox(
                          context,
                          icon: Icons.desktop_windows,
                          title: 'Desktop Site',
                          value: ref.watch(desktopModeProvider),
                          onTap: () async {
                            final currentMode = ref.read(desktopModeProvider);
                            final newMode = !currentMode;
                            
                            // Update state and save to storage
                            await ref.read(desktopModeProvider.notifier).setDesktopMode(newMode);
                            
                            // Close menu
                            Navigator.pop(context);
                            
                            // Apply desktop mode and reload page
                            if (_webViewController != null && _currentUrl.isNotEmpty) {
                              _webViewController!.setDesktopMode(newMode);
                              // Page will reload automatically in setDesktopMode
                            }
                            
                            // Show feedback
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(newMode 
                                    ? '✓ Desktop mode enabled' 
                                    : '✓ Mobile mode enabled'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                        _buildBrowserMenuItem(
                          context,
                          icon: Icons.article,
                          title: 'Reader Mode',
                          onTap: () async {
                            Navigator.pop(context);
                            if (_currentUrl.isNotEmpty && _webViewController != null) {
                              try {
                                final content = await _webViewController!.extractArticleContent();
                                final pageTitle = _currentTitle.isNotEmpty 
                                    ? _currentTitle 
                                    : await _webViewController!.currentTitle() ?? 'Untitled';
                                if (mounted && content.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ReaderModeScreen(
                                        url: _currentUrl,
                                        title: pageTitle,
                                        content: content,
                                      ),
                                    ),
                                  );
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Unable to extract article content')),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Error opening reader mode')),
                                  );
                                }
                              }
                            }
                          },
                        ),
                        _buildBrowserMenuItem(
                          context,
                          icon: Icons.search,
                          title: 'Find in Page',
                          onTap: () {
                            Navigator.pop(context);
                            _showFindInPage();
                          },
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                        
                        // Other Features
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
                            _showExitDialog(context);
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

  Widget _buildBrowserMenuItemWithCheckbox(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            Checkbox(
              value: value,
              onChanged: (newValue) => onTap(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
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

  void _showFindInPage() {
    if (_webViewController == null) return;
    
    final TextEditingController findController = TextEditingController();
    final ValueNotifier<int> activeMatchNotifier = ValueNotifier<int>(0);
    final ValueNotifier<int> totalMatchesNotifier = ValueNotifier<int>(0);
    final FocusNode focusNode = FocusNode();
    
    _findActiveMatch = activeMatchNotifier;
    _findTotalMatches = totalMatchesNotifier;
    
    // Show find in page overlay at top using OverlayEntry (doesn't block scroll)
    final overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            top: true,
            bottom: false,
            child: Material(
              elevation: 4,
              child: FindInPageOverlay(
                controller: findController,
                focusNode: focusNode,
                activeMatch: activeMatchNotifier,
                totalMatches: totalMatchesNotifier,
                onFind: (text) {
                  if (text.isNotEmpty) {
                    _webViewController?.findInPage(text);
                  } else {
                    _webViewController?.clearFind();
                    activeMatchNotifier.value = 0;
                    totalMatchesNotifier.value = 0;
                  }
                },
                onFindNext: () => _webViewController?.findNext(),
                onFindPrevious: () => _webViewController?.findPrevious(),
                onClose: () {
                  _webViewController?.clearFind();
                  _findActiveMatch = null;
                  _findTotalMatches = null;
                  _findOverlayEntry?.remove();
                  _findOverlayEntry = null;
                },
              ),
            ),
          ),
        );
      },
    );
    
    _findOverlayEntry = overlayEntry;
    Overlay.of(context).insert(overlayEntry);
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Exit App'),
          content: const Text('Are you sure you want to exit Void?'),
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
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
      // Load URL after widget is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadUrl(widget.initialUrl!, ref);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Animated AppBar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            height: (_currentUrl == 'discover' || _currentUrl.isEmpty || _isAppBarVisible) 
                ? kToolbarHeight + MediaQuery.of(context).padding.top 
                : MediaQuery.of(context).padding.top,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: (_currentUrl == 'discover' || _currentUrl.isEmpty || _isAppBarVisible) ? 1.0 : 0.0,
              child: AppBar(
                automaticallyImplyLeading: false, // Remove back button
                titleSpacing: 8,
                title: ChromeSearchBar(
                  controller: _urlController,
                  currentUrl: _currentUrl, // Pass current URL for security icon
                  onSubmitted: (value) => _loadUrl(value, ref),
                  onChanged: (value) {
                    // Update URL text as user types
                  },
                  showMenu: false, // Menu is now separate
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: _showChromeMenu,
                    tooltip: 'Menu',
                  ),
                ],
              ),
            ),
          ),
          
          // WebView
          Expanded(
            child: GestureDetector(
              onTap: () {
                // Unfocus search bar when tapping on webview
                _urlController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _urlController.text.length),
                );
                FocusScope.of(context).unfocus();
              },
              child: ChromeWebView(
              initialUrl: widget.initialUrl ?? 'https://www.google.com',
              onDownloadRequested: (url, filename) async {
                // Handle download request from WebView
                try {
                  await ref.read(downloadManagerProvider.notifier).startDownload(
                    url: url,
                    filename: filename,
                    sourceType: null, // Generic file download
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.download, color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Download started! Check Downloads page for progress.',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 3),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Download failed: ${e.toString()}'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
              onFindResult: (activeMatch, totalMatches) {
                if (_findActiveMatch != null && _findTotalMatches != null) {
                  _findActiveMatch!.value = activeMatch;
                  _findTotalMatches!.value = totalMatches;
                }
              },
              onWebViewCreated: (controller) {
                if (mounted) {
                  setState(() {
                    _webViewController = controller;
                  });
                }
                // Apply saved desktop mode preference when WebView is created
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final desktopMode = ref.read(desktopModeProvider);
                  if (desktopMode) {
                    controller.setDesktopMode(desktopMode);
                  }
                });
              },
              onUrlChanged: (url) async {
                final isDiscoverUrl = url == 'discover' || url.isEmpty;
                if (mounted) {
                  setState(() {
                    _currentUrl = url;
                    _urlController.text = url;
                    // Ensure app bar is visible on discover page
                    if (isDiscoverUrl) {
                      _isAppBarVisible = true;
                    }
                  });
                }
                // Get page title
                _currentTitle = await _webViewController?.currentTitle() ?? '';
              },
              onScrollChanged: _handleScroll, // Track scroll position
              ),
            ),
          ),
        ],
      ),
    );
  }
}

