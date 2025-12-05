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
import '../../../discover/presentation/screens/discover_screen.dart';
import '../../../reader_mode/presentation/screens/reader_mode_screen.dart';
import '../providers/desktop_mode_provider.dart';
import '../../../../core/constants/api_constants.dart';
import '../providers/tabs_provider.dart';
import '../screens/tab_switcher_screen.dart';
import '../widgets/qr_code_dialog.dart';
import '../widgets/screenshot_dialog.dart';

/// Browser screen with tab support
class BrowserTabScreen extends ConsumerStatefulWidget {
  const BrowserTabScreen({super.key});

  @override
  ConsumerState<BrowserTabScreen> createState() => _BrowserTabScreenState();
}

class _BrowserTabScreenState extends ConsumerState<BrowserTabScreen> {
  final Map<String, ChromeWebViewController> _webViewControllers = {};
  final Map<String, TextEditingController> _urlControllers = {};
  final Map<String, ValueNotifier<int>> _findActiveMatches = {};
  final Map<String, ValueNotifier<int>> _findTotalMatches = {};
  final Map<String, OverlayEntry?> _findOverlayEntries = {};
  final Map<String, String> _currentUrls = {};
  final Map<String, String?> _currentTitles = {};
  final Map<String, bool> _isAppBarVisible = {};
  final Map<String, int> _lastScrollY = {};
  final Map<String, bool> _isLoadingUrl = {}; // Track if URL is being loaded
  final Map<String, String> _lastLoadedUrl = {}; // Track last URL we loaded to prevent duplicates
  final Map<String, DateTime> _lastLoadTime = {}; // Track when URL was last loaded for debouncing
  final Map<String, bool> _isInternalLoad = {}; // Track if we initiated the load (not external)
  final Map<String, List<String>> _navigationHistory = {}; // Track navigation history per tab
  final Map<String, DateTime> _lastScrollUpdate = {}; // Debounce scroll updates
  final Map<String, int> _scrollDirection = {}; // Track scroll direction (1 = down, -1 = up, 0 = none)
  final Map<String, int> _scrollAccumulator = {}; // Accumulate scroll delta to prevent flickering
  final Map<String, DateTime> _lastStateChange = {}; // Track when app bar state last changed
  final Map<String, ValueNotifier<bool>> _appBarVisibilityNotifiers = {}; // Use ValueNotifier for smooth updates
  static const int _scrollThreshold = 25; // Minimum scroll distance before changing state (increased for stability)
  static const int _scrollDebounceMs = 200; // Debounce time for scroll updates (increased for smoothness)
  static const int _scrollAccumulatorThreshold = 40; // Accumulated scroll needed to change state (increased)
  static const int _stateChangeCooldownMs = 600; // Cooldown period after state change to prevent flickering
  static const int _scrollThrottleMs = 16; // Throttle scroll events to ~60fps (16ms = 60fps)
  static const int _debounceMs = 300; // Debounce time for URL loading (reduced from 1000ms for faster response)

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
    // Don't hide app bar on discover page
    final currentUrl = _currentUrls[tabId] ?? '';
    final isDiscover = currentUrl == 'discover' || 
                       currentUrl.isEmpty || 
                       currentUrl == 'http://discover' || 
                       currentUrl == 'https://discover';
    
    if (isDiscover) {
      // Always show app bar on discover page
      if (_isAppBarVisible[tabId] != true) {
        _isAppBarVisible[tabId] = true;
        // Ensure ValueNotifier exists
        if (!_appBarVisibilityNotifiers.containsKey(tabId)) {
          _appBarVisibilityNotifiers[tabId] = ValueNotifier<bool>(true);
        } else {
          _appBarVisibilityNotifiers[tabId]!.value = true;
        }
      }
      return;
    }
    
    final now = DateTime.now();
    final lastUpdate = _lastScrollUpdate[tabId];
    final lastScrollY = _lastScrollY[tabId] ?? 0;
    final lastStateChange = _lastStateChange[tabId];
    
    // CRITICAL: Throttle scroll events to ~60fps to reduce lag
    if (lastUpdate != null && now.difference(lastUpdate).inMilliseconds < _scrollThrottleMs) {
      return;
    }
    _lastScrollUpdate[tabId] = now;
    
    // CRITICAL: Prevent state changes too soon after last change (cooldown period)
    if (lastStateChange != null) {
      final timeSinceLastChange = now.difference(lastStateChange).inMilliseconds;
      if (timeSinceLastChange < _stateChangeCooldownMs) {
        // Still in cooldown, ignore scroll events to prevent flickering
        return;
      }
    }
    
    // Calculate scroll delta (positive = scrolling down, negative = scrolling up)
    final delta = y - lastScrollY;
    
    // Update tracking variables
    _lastScrollY[tabId] = y;
    
    // Ignore very small movements to prevent micro-adjustments from causing flickering
    if (delta.abs() < 8) {
      return;
    }
    
    // Determine current scroll direction
    int currentDirection = 0;
    if (delta > _scrollThreshold) {
      currentDirection = 1; // Scrolling down
    } else if (delta < -_scrollThreshold) {
      currentDirection = -1; // Scrolling up
    } else {
      // Movement below threshold, maintain previous direction but don't accumulate
      currentDirection = _scrollDirection[tabId] ?? 0;
      // Don't process further if movement is too small
      if (currentDirection == 0) {
        return;
      }
    }
    
    // Update scroll direction
    final previousDirection = _scrollDirection[tabId] ?? 0;
    _scrollDirection[tabId] = currentDirection;
    
    // Accumulate scroll delta in the same direction to prevent flickering
    int accumulator = _scrollAccumulator[tabId] ?? 0;
    
    if (currentDirection != 0) {
      // If direction changed, reset accumulator immediately
      if (currentDirection != previousDirection && previousDirection != 0) {
        accumulator = 0;
      }
      
      // Only accumulate if direction is consistent
      if (currentDirection == previousDirection || previousDirection == 0) {
        accumulator += delta.abs();
        _scrollAccumulator[tabId] = accumulator;
      } else {
        // Direction changed, reset
        accumulator = 0;
        _scrollAccumulator[tabId] = 0;
      }
    } else {
      // No significant movement, gradually reduce accumulator
      accumulator = (accumulator * 0.7).round();
      if (accumulator < 5) {
        accumulator = 0;
      }
      _scrollAccumulator[tabId] = accumulator;
    }
    
    // Additional debounce for state changes (separate from throttle)
    final lastStateUpdate = _lastStateChange[tabId];
    if (lastStateUpdate != null && now.difference(lastStateUpdate).inMilliseconds < _scrollDebounceMs) {
      return;
    }
    
    // Only change state if we have accumulated enough scroll in one direction
    // This prevents flickering when holding scroll position
    if (accumulator < _scrollAccumulatorThreshold) {
      return;
    }
    
    // Determine if app bar should be visible (show when scrolling up, hide when scrolling down)
    // Chrome behavior: hide when scrolling down, show when scrolling up
    final shouldShow = currentDirection < 0; // Negative direction means scrolling up
    final currentlyVisible = _isAppBarVisible[tabId] ?? true;
    
    // Only update if state actually changed
    if (shouldShow != currentlyVisible && mounted) {
      _lastStateChange[tabId] = now; // Track when state changed
      // Reset accumulator after state change to prevent immediate reversal
      _scrollAccumulator[tabId] = 0;
      // Reset scroll direction to prevent immediate re-triggering
      _scrollDirection[tabId] = 0;
      
      // Ensure ValueNotifier exists before updating
      if (!_appBarVisibilityNotifiers.containsKey(tabId)) {
        _appBarVisibilityNotifiers[tabId] = ValueNotifier<bool>(shouldShow);
      }
      
      // Update state using ValueNotifier for smoother updates
      _isAppBarVisible[tabId] = shouldShow;
      _appBarVisibilityNotifiers[tabId]!.value = shouldShow;
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

    // Update URL controller text IMMEDIATELY for instant feedback (no setState needed)
    if (_urlControllers[tabId] != null) {
      _urlControllers[tabId]!.text = url;
    }
    _currentUrls[tabId] = url; // Update immediately to prevent duplicate loads

    // Update state asynchronously to avoid blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          // State already updated above, just trigger rebuild
        });
      }
    });

    // Load URL in WebView if it exists, otherwise update tab (will create WebView)
    if (_webViewControllers[tabId] != null) {
      // Load URL immediately - WebView's loadUrl has its own duplicate prevention
      _webViewControllers[tabId]!.loadUrl(url);
    }
    
    // Update tab provider AFTER setting flags to prevent external update check from loading again
    // The _isInternalLoad flag will prevent the external update check from triggering
    ref.read(tabsProvider.notifier).updateTab(tabId: tabId, url: url);
    
    // Reset loading flag quickly (reduced delay for faster response)
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _isLoadingUrl[tabId] = false;
        // Keep _isInternalLoad true a bit longer to prevent external update check
        Future.delayed(const Duration(milliseconds: 100), () {
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
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.topRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 240,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              margin: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                right: 8,
                bottom: 8,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
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
                              final wasAdded = await ref.read(bookmarksProvider.notifier).addBookmark(
                                title: _currentTitles[tabId]?.isEmpty ?? true
                                    ? 'New Bookmark'
                                    : _currentTitles[tabId]!,
                                url: url,
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
                  Flexible(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
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
                              final newActiveTab = ref.read(tabsProvider).activeTab;
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
                                      final remainingTabIds = ref.read(tabsProvider).tabs.map((t) => t.id).toSet();
                                      _urlControllers.removeWhere((key, value) => !remainingTabIds.contains(key));
                                      _currentUrls.removeWhere((key, value) => !remainingTabIds.contains(key));
                                      _currentTitles.removeWhere((key, value) => !remainingTabIds.contains(key));
                                      _isAppBarVisible.removeWhere((key, value) => !remainingTabIds.contains(key));
                                      _lastScrollY.removeWhere((key, value) => !remainingTabIds.contains(key));
                                      // Initialize controller for new discover tab
                                      final newActiveTab = ref.read(tabsProvider).activeTab;
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
                        _buildBrowserMenuItem(
                          context,
                          icon: Icons.qr_code,
                          title: 'Generate QR Code',
                          onTap: () {
                            Navigator.pop(context);
                            final url = _currentUrls[tabId] ?? '';
                            final title = _currentTitles[tabId];
                            showDialog(
                              context: context,
                              builder: (context) => QRCodeDialog(
                                initialUrl: url.isNotEmpty && url != 'discover' ? url : null,
                                title: title,
                              ),
                            );
                          },
                        ),
                        _buildBrowserMenuItem(
                          context,
                          icon: Icons.camera_alt,
                          title: 'Take Screenshot',
                          onTap: () async {
                            Navigator.pop(context);
                            final url = _currentUrls[tabId] ?? '';
                            final title = _currentTitles[tabId];
                            
                            // Don't allow screenshots of discover page
                            if (url.isEmpty || url == 'discover') {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Screenshot not available for this page'),
                                  ),
                                );
                              }
                              return;
                            }

                            // Show loading indicator
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      SizedBox(width: 12),
                                      Text('Capturing screenshot...'),
                                    ],
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }

                            try {
                              // Get webview controller
                              final webViewCtrl = _webViewControllers[tabId];
                              if (webViewCtrl == null) {
                                throw Exception('WebView not available');
                              }

                              // Take screenshot
                              final screenshot = await webViewCtrl.takeScreenshot();
                              if (screenshot == null) {
                                throw Exception('Failed to capture screenshot');
                              }

                              // Show screenshot dialog with share and save options
                              if (mounted) {
                                showDialog(
                                  context: context,
                                  builder: (context) => ScreenshotDialog(
                                    screenshotData: screenshot,
                                    url: url,
                                    title: title,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to capture screenshot: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
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
                            final url = _currentUrls[tabId] ?? '';
                            if (_webViewControllers[tabId] != null && url.isNotEmpty && url != 'discover') {
                              _webViewControllers[tabId]!.setDesktopMode(newMode);
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
                            final url = _currentUrls[tabId] ?? '';
                            final title = _currentTitles[tabId] ?? '';
                            if (url.isNotEmpty && url != 'discover' && _webViewControllers[tabId] != null) {
                              // Extract content from page
                              try {
                                final content = await _webViewControllers[tabId]!.extractArticleContent();
                                final pageTitle = title.isNotEmpty ? title : await _webViewControllers[tabId]!.currentTitle() ?? 'Untitled';
                                if (mounted && content.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ReaderModeScreen(
                                        url: url,
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
                            _showFindInPage(tabId);
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
            curve: Curves.easeOut,
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Icon(icon, size: 20),
      ),
    );
  }

  void _showFindInPage(String tabId) {
    if (!_webViewControllers.containsKey(tabId) || _webViewControllers[tabId] == null) return;
    
    final TextEditingController findController = TextEditingController();
    final ValueNotifier<int> activeMatchNotifier = ValueNotifier<int>(0);
    final ValueNotifier<int> totalMatchesNotifier = ValueNotifier<int>(0);
    final FocusNode focusNode = FocusNode();
    
    _findActiveMatches[tabId] = activeMatchNotifier;
    _findTotalMatches[tabId] = totalMatchesNotifier;
    
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
                    _webViewControllers[tabId]?.findInPage(text);
                  } else {
                    _webViewControllers[tabId]?.clearFind();
                    activeMatchNotifier.value = 0;
                    totalMatchesNotifier.value = 0;
                  }
                },
                onFindNext: () => _webViewControllers[tabId]?.findNext(),
                onFindPrevious: () => _webViewControllers[tabId]?.findPrevious(),
                onClose: () {
                  _webViewControllers[tabId]?.clearFind();
                  _findActiveMatches.remove(tabId);
                  _findTotalMatches.remove(tabId);
                  _findOverlayEntries[tabId]?.remove();
                  _findOverlayEntries.remove(tabId);
                },
              ),
            ),
          ),
        );
      },
    );
    
    _findOverlayEntries[tabId] = overlayEntry;
    Overlay.of(context).insert(overlayEntry);
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

  @override
  Widget build(BuildContext context) {
    // Use select to only watch specific fields to reduce rebuilds
    final tabsState = ref.watch(tabsProvider);
    final activeTab = tabsState.activeTab;
    final allTabs = tabsState.tabs;
    final tabCount = tabsState.tabCount;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (activeTab == null || allTabs.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final tabId = activeTab.id;
    final isDiscover = activeTab.url == 'discover';
    
    // Find the index of the active tab for IndexedStack
    final activeTabIndex = allTabs.indexWhere((tab) => tab.id == tabId);

    // Initialize controllers for this tab if not exists
    if (!_urlControllers.containsKey(tabId)) {
      _urlControllers[tabId] = TextEditingController(text: isDiscover ? '' : activeTab.url);
      _currentUrls[tabId] = activeTab.url;
      _currentTitles[tabId] = activeTab.title;
      _isAppBarVisible[tabId] = true; // Always show app bar initially
      _appBarVisibilityNotifiers[tabId] = ValueNotifier<bool>(true); // Initialize ValueNotifier
      _navigationHistory[tabId] = [];
    } else {
      // Ensure app bar is visible on discover page
      if (isDiscover && _isAppBarVisible[tabId] != true) {
        _isAppBarVisible[tabId] = true;
        // Ensure ValueNotifier exists and update it
        if (!_appBarVisibilityNotifiers.containsKey(tabId)) {
          _appBarVisibilityNotifiers[tabId] = ValueNotifier<bool>(true);
        } else {
          _appBarVisibilityNotifiers[tabId]!.value = true;
        }
      }
      
      // Ensure ValueNotifier exists for all tabs (even if not discover)
      if (!_appBarVisibilityNotifiers.containsKey(tabId)) {
        _appBarVisibilityNotifiers[tabId] = ValueNotifier<bool>(_isAppBarVisible[tabId] ?? true);
      }
      // Update controller text when switching tabs to show current tab's URL
      // Also handle case where tab URL changes from "discover" to a real URL
      final shouldShowUrl = !isDiscover && activeTab.url != 'discover';
      final currentUrl = shouldShowUrl ? activeTab.url : '';
      
      // Update URL controller text if it doesn't match the current tab URL
      if (shouldShowUrl && _urlControllers[tabId]!.text != currentUrl) {
        _urlControllers[tabId]!.text = currentUrl;
      } else if (!shouldShowUrl && _urlControllers[tabId]!.text.isNotEmpty) {
        _urlControllers[tabId]!.text = '';
      }
      
      // Check if tab URL was updated externally (e.g., from TabUtils)
      // This handles the case where URL changes from "discover" to a real URL
      // OR when URL changes from one real URL to another (e.g., clicking news after browsing)
      // IMPORTANT: Only load if this is NOT an internal load (to prevent duplicate loads)
      // AND if the WebView doesn't already have this URL loaded (to prevent reloading when switching tabs)
      if (activeTab.url != 'discover' && 
          activeTab.url != _currentUrls[tabId] &&
          _isInternalLoad[tabId] != true && // Skip if we just loaded via _loadUrl
          _webViewControllers[tabId] != null) { // Only load if WebView exists
        // For external updates (from TabUtils), load the URL
        if (mounted) {
          // Format URL properly
          String formattedUrl = activeTab.url;
          if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
            if (formattedUrl.contains('.') && !formattedUrl.contains(' ')) {
              formattedUrl = 'https://$formattedUrl';
            }
          }
          
          // Prevent duplicate load - check if we're already loading this exact URL
          if (!(_isLoadingUrl[tabId] == true && _lastLoadedUrl[tabId] == formattedUrl)) {
            // Mark as external load to prevent _loadUrl from loading again
            _isInternalLoad[tabId] = false;
            _isLoadingUrl[tabId] = true;
            _lastLoadedUrl[tabId] = formattedUrl;
            _lastLoadTime[tabId] = DateTime.now();
            
            // Update controller text immediately
            if (_urlControllers[tabId] != null) {
              _urlControllers[tabId]!.text = formattedUrl;
            }
            _currentUrls[tabId] = formattedUrl;
            
            // Load URL in WebView if it exists, otherwise it will be loaded when WebView is created
            if (_webViewControllers[tabId] != null) {
              _webViewControllers[tabId]!.loadUrl(formattedUrl);
              
              // Update state asynchronously
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    // State already updated above
                  });
                }
              });
              
              // Reset loading flag quickly
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted) {
                  _isLoadingUrl[tabId] = false;
                }
              });
            } else {
              // Webview doesn't exist yet, just update the URL state
              // It will be loaded when webview is created
              setState(() {
                _currentUrls[tabId] = formattedUrl;
              });
            }
          } else {
            // Already loading this URL, just update the controller text to ensure it's in sync
            if (_urlControllers[tabId] != null && _urlControllers[tabId]!.text != formattedUrl) {
              _urlControllers[tabId]!.text = formattedUrl;
            }
            _currentUrls[tabId] = formattedUrl;
          }
        }
      } else if (_isInternalLoad[tabId] == true) {
        // Reset internal load flag after processing
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _isInternalLoad[tabId] = false;
          }
        });
      }
      
      // Update current URL if tab URL changed (even if it's discover)
      // Only update if URL actually changed to avoid unnecessary rebuilds
      if (activeTab.url != _currentUrls[tabId] && mounted) {
        _currentUrls[tabId] = activeTab.url;
        // Only call setState if this will cause a visible change
        if (!isDiscover || activeTab.url != 'discover') {
          setState(() {});
        }
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
      child: GestureDetector(
        onTap: () {
          // Unfocus search bar when tapping outside
          final activeTab = ref.read(tabsProvider).activeTab;
          if (activeTab != null) {
            final tabId = activeTab.id;
            if (_urlControllers.containsKey(tabId)) {
              _urlControllers[tabId]!.selection = TextSelection.fromPosition(
                TextPosition(offset: _urlControllers[tabId]!.text.length),
              );
              FocusScope.of(context).unfocus();
            }
          }
        },
        child: Scaffold(
          body: Column(
          children: [
          ValueListenableBuilder<bool>(
            valueListenable: _appBarVisibilityNotifiers[tabId]!,
            builder: (context, isVisible, child) {
              final shouldShow = isDiscover || isVisible;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                height: shouldShow ? appBarHeight : MediaQuery.of(context).padding.top,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  opacity: shouldShow ? 1.0 : 0.0,
                  child: RepaintBoundary(
                    child: AppBar(
                automaticallyImplyLeading: false,
                titleSpacing: 8,
                title: ChromeSearchBar(
                  controller: _urlControllers[tabId]!,
                  currentUrl: isDiscover ? null : _currentUrls[tabId],
                  onSubmitted: (value) => _loadUrl(tabId, value, ref),
                  onChanged: (value) {},
                  showMenu: false,
                ),
                actions: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                          // New Tab button
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              ref.read(tabsProvider.notifier).createNewTab();
                              // Clear the controller for the new tab when it becomes active
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                final newActiveTab = ref.read(tabsProvider).activeTab;
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
                      ),
                ],
                backgroundColor: isDark ? Colors.black : Colors.white,
                elevation: 0,
                      ),
                    ),
                  ),
                );
              },
            ),
          Expanded(
            child: IndexedStack(
              index: activeTabIndex >= 0 ? activeTabIndex : 0,
              children: allTabs.map<Widget>((tab) {
                final currentTabId = tab.id;
                final currentIsDiscover = tab.url == 'discover';
                
                // Initialize controllers for all tabs if not exists
                if (!_urlControllers.containsKey(currentTabId)) {
                  _urlControllers[currentTabId] = TextEditingController(
                    text: currentIsDiscover ? '' : tab.url,
                  );
                  _currentUrls[currentTabId] = tab.url;
                  _currentTitles[currentTabId] = tab.title;
                  _isAppBarVisible[currentTabId] = true;
                  if (!_appBarVisibilityNotifiers.containsKey(currentTabId)) {
                    _appBarVisibilityNotifiers[currentTabId] = ValueNotifier<bool>(true);
                  }
                  _navigationHistory[currentTabId] = [];
                }
                
                // Return the appropriate widget for each tab
                return currentIsDiscover
                    ? const DiscoverScreen()
                    : ChromeWebView(
                        // Use tabId as key to maintain WebView instance and preserve state
                        key: ValueKey('webview_$currentTabId'),
                        initialUrl: _getValidUrlForWebView(tab.url),
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
                      if (_findActiveMatches.containsKey(currentTabId) && _findTotalMatches.containsKey(currentTabId)) {
                        _findActiveMatches[currentTabId]!.value = activeMatch;
                        _findTotalMatches[currentTabId]!.value = totalMatches;
                      }
                    },
                    onWebViewCreated: (controller) {
                      _webViewControllers[currentTabId] = controller;
                      // Load URL if it was set before WebView was created
                      // Use tab.url to get the most up-to-date URL (might have been updated by TabUtils)
                      final urlToLoad = tab.url;
                      if (urlToLoad != 'discover' && urlToLoad.isNotEmpty && 
                          urlToLoad != 'http://discover' && urlToLoad != 'https://discover' &&
                          urlToLoad != 'http://discover/' && urlToLoad != 'https://discover/') {
                        // Only load URL if this tab doesn't already have a loaded URL
                        // This prevents reloading when switching back to a tab
                        if (_currentUrls[currentTabId] != urlToLoad || 
                            !_webViewControllers.containsKey(currentTabId)) {
                          // Update current URL state
                          if (mounted) {
                            setState(() {
                              _currentUrls[currentTabId] = urlToLoad;
                              if (_urlControllers[currentTabId] != null) {
                                _urlControllers[currentTabId]!.text = urlToLoad;
                              }
                              // Clear loading flags to allow immediate load
                              _isLoadingUrl[currentTabId] = false;
                              _lastLoadedUrl[currentTabId] = '';
                              _lastLoadTime.remove(currentTabId);
                            });
                          }
                          
                          // Load URL immediately when WebView is created (no delay for faster loading)
                          // Use microtask to ensure WebView is ready but don't wait
                          Future.microtask(() {
                            if (mounted && _webViewControllers[currentTabId] != null) {
                              // Ensure we're loading the most current URL
                              final currentTab = ref.read(tabsProvider).tabs.firstWhere(
                                (t) => t.id == currentTabId,
                                orElse: () => tab,
                              );
                              final currentTabUrl = currentTab.url;
                              if (currentTabUrl != 'discover' && currentTabUrl.isNotEmpty) {
                                // Check if we're not already loading this URL to prevent duplicates
                                if (_lastLoadedUrl[currentTabId] != currentTabUrl || !(_isLoadingUrl[currentTabId] ?? false)) {
                                  _isLoadingUrl[currentTabId] = true;
                                  _lastLoadedUrl[currentTabId] = currentTabUrl;
                                  _lastLoadTime[currentTabId] = DateTime.now();
                                  
                                  controller.loadUrl(currentTabUrl);
                                  
                                  // Update state to reflect the load
                                  setState(() {
                                    _currentUrls[currentTabId] = currentTabUrl;
                                  });
                                  
                                  // Apply saved desktop mode preference after loading
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    final desktopMode = ref.read(desktopModeProvider);
                                    if (desktopMode) {
                                      controller.setDesktopMode(desktopMode);
                                    }
                                  });
                                }
                              }
                            }
                          });
                        }
                      } else {
                        // Apply saved desktop mode preference even for discover page
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final desktopMode = ref.read(desktopModeProvider);
                          if (desktopMode && urlToLoad != 'discover') {
                            controller.setDesktopMode(desktopMode);
                          }
                        });
                      }
                    },
                    onUrlChanged: (url) async {
                      // Prevent duplicate updates - check if URL actually changed
                      if (_currentUrls[currentTabId] == url) {
                        _isLoadingUrl[currentTabId] = false; // Reset loading flag even if URL is same
                        return;
                      }
                      
                      // Debounce: Don't update if this URL was just loaded
                      final lastLoadTime = _lastLoadTime[currentTabId];
                      if (lastLoadTime != null && _lastLoadedUrl[currentTabId] == url) {
                        final timeSinceLastLoad = DateTime.now().difference(lastLoadTime).inMilliseconds;
                        if (timeSinceLastLoad < _debounceMs) {
                          // This is likely the same load, just update state without triggering tab update
                          if (_urlControllers[currentTabId] != null && _urlControllers[currentTabId]!.text != url) {
                            _urlControllers[currentTabId]!.text = url;
                          }
                          // Update state without setState if only URL controller changed
                          _currentUrls[currentTabId] = url;
                          _isLoadingUrl[currentTabId] = false;
                          return;
                        }
                      }
                      
                      // CRITICAL: Update controller text IMMEDIATELY for instant search bar feedback
                      // This happens synchronously before any async operations
                      if (_urlControllers[currentTabId] != null && _urlControllers[currentTabId]!.text != url) {
                        _urlControllers[currentTabId]!.text = url;
                      }
                      
                      // Update URL state immediately (no await)
                      _currentUrls[currentTabId] = url;
                      _isLoadingUrl[currentTabId] = false;
                      _lastLoadedUrl[currentTabId] = url;
                      _lastLoadTime[currentTabId] = DateTime.now();
                      
                      final isDiscoverUrl = url == 'discover' || url.isEmpty;
                      
                      // Update UI state immediately (before title fetch)
                      if (mounted) {
                        setState(() {
                          // State already updated above, just trigger rebuild
                          if (isDiscoverUrl) {
                            _isAppBarVisible[currentTabId] = true;
                          }
                        });
                      }
                      
                      // Fetch title asynchronously AFTER updating URL (non-blocking)
                      // This prevents title fetch from delaying search bar update
                      _webViewControllers[currentTabId]?.currentTitle().then((title) {
                        if (mounted && _currentUrls[currentTabId] == url) {
                          // Only update if URL hasn't changed since we started fetching title
                          setState(() {
                            _currentTitles[currentTabId] = title ?? '';
                          });
                          
                          ref.read(tabsProvider.notifier).updateTab(
                            tabId: currentTabId,
                            url: url,
                            title: title ?? '',
                          );
                        }
                      }).catchError((_) {
                        // If title fetch fails, still update tab with URL
                        if (mounted && _currentUrls[currentTabId] == url) {
                          ref.read(tabsProvider.notifier).updateTab(
                            tabId: currentTabId,
                            url: url,
                            title: '',
                          );
                        }
                      });
                      
                      // Update tab immediately with URL (title will be updated later)
                      ref.read(tabsProvider.notifier).updateTab(
                        tabId: currentTabId,
                        url: url,
                        title: _currentTitles[currentTabId] ?? '', // Use existing title temporarily
                      );
                    },
                    onScrollChanged: (x, y) => _handleScroll(currentTabId, x, y),
                      );
              }).toList(),
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}

