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
  bool _isDesktopMode = false;
  String _currentUrl = '';
  String _currentTitle = '';
  
  // AppBar visibility management
  bool _isAppBarVisible = true;
  int _lastScrollY = 0;
  static const int _scrollThreshold = 10; // Minimum scroll distance to trigger hide/show

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _handleScroll(int x, int y) {
    // Calculate scroll direction
    final scrollDelta = y - _lastScrollY;
    
    // Only react to significant scroll changes
    if (scrollDelta.abs() < _scrollThreshold) return;
    
    setState(() {
      // Scrolling up (positive delta) - hide AppBar
      // Scrolling down (negative delta) - show AppBar
      if (scrollDelta > 0 && _isAppBarVisible) {
        _isAppBarVisible = false;
      } else if (scrollDelta < 0 && !_isAppBarVisible) {
        _isAppBarVisible = true;
      }
      
      _lastScrollY = y;
    });
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
                              await ref.read(bookmarksProvider.notifier).addBookmark(
                                title: _currentTitle.isEmpty ? 'New Bookmark' : _currentTitle,
                                url: _currentUrl,
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
                        _buildBrowserMenuItem(
                          context,
                          icon: _isDesktopMode ? Icons.phone_android : Icons.desktop_windows,
                          title: _isDesktopMode ? 'Mobile Site' : 'Desktop Site',
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              _isDesktopMode = !_isDesktopMode;
                            });
                            _webViewController?.setDesktopMode(_isDesktopMode);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_isDesktopMode 
                                  ? '✓ Desktop mode enabled' 
                                  : '✓ Mobile mode enabled'),
                              ),
                            );
                          },
                        ),
                        _buildBrowserMenuItem(
                          context,
                          icon: Icons.article,
                          title: 'Reader Mode',
                          onTap: () {
                            Navigator.pop(context);
                            _webViewController?.enableReaderMode();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Opening in reader mode...')),
                            );
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
    final TextEditingController findController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Find in Page'),
          content: TextField(
            controller: findController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter text to find',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                _webViewController?.findInPage(value);
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (findController.text.isNotEmpty) {
                  _webViewController?.findInPage(findController.text);
                  Navigator.pop(context);
                }
              },
              child: const Text('Find'),
            ),
          ],
        );
      },
    );
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
            height: _isAppBarVisible ? kToolbarHeight + MediaQuery.of(context).padding.top : MediaQuery.of(context).padding.top,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isAppBarVisible ? 1.0 : 0.0,
              child: AppBar(
                automaticallyImplyLeading: false, // Remove back button
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
                titleSpacing: 8,
              ),
            ),
          ),
          
          // WebView
          Expanded(
            child: ChromeWebView(
              initialUrl: widget.initialUrl ?? 'https://www.google.com',
              onWebViewCreated: (controller) {
                setState(() {
                  _webViewController = controller;
                });
              },
              onUrlChanged: (url) async {
                setState(() {
                  _currentUrl = url;
                  _urlController.text = url;
                });
                // Get page title
                _currentTitle = await _webViewController?.currentTitle() ?? '';
              },
              onScrollChanged: _handleScroll, // Track scroll position
            ),
          ),
        ],
      ),
    );
  }
}

