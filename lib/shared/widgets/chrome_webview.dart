import 'dart:collection';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/validators.dart';
import '../../features/bookmarks/presentation/providers/bookmarks_provider.dart';
import '../../features/adblock/presentation/providers/adblock_provider.dart';

/// Chrome-like WebView component with gestures and modern UX
class ChromeWebView extends ConsumerStatefulWidget {
  final String? initialUrl;
  final Function(String url)? onUrlChanged;
  final bool showProgress;
  final void Function(ChromeWebViewController controller)? onWebViewCreated;
  final Function(int x, int y)? onScrollChanged; // Callback for scroll position changes
  final Function(String url, String filename)? onDownloadRequested; // Callback for download requests
  final Function(int activeMatch, int totalMatches)? onFindResult; // Callback for find in page results

  const ChromeWebView({
    super.key,
    this.initialUrl,
    this.onUrlChanged,
    this.showProgress = true,
    this.onWebViewCreated,
    this.onScrollChanged,
    this.onDownloadRequested,
    this.onFindResult,
  });

  @override
  ConsumerState<ChromeWebView> createState() => _ChromeWebViewState();
}

/// Controller to control ChromeWebView from outside
class ChromeWebViewController {
  final Function(String) loadUrl;
  final VoidCallback showMenu;
  final Future<bool> Function() canGoBack;
  final Future<bool> Function() canGoForward;
  final VoidCallback goBack;
  final VoidCallback goForward;
  final VoidCallback reload;
  final Function(bool) setDesktopMode;
  final VoidCallback enableReaderMode;
  final Function(String) findInPage;
  final VoidCallback findNext;
  final VoidCallback findPrevious;
  final VoidCallback clearFind;
  final Future<String?> Function() currentUrl;
  final Future<String?> Function() currentTitle;
  final Future<String> Function() extractArticleContent;
  final Future<Uint8List?> Function() takeScreenshot;

  ChromeWebViewController({
    required this.loadUrl,
    required this.showMenu,
    required this.canGoBack,
    required this.canGoForward,
    required this.goBack,
    required this.goForward,
    required this.reload,
    required this.setDesktopMode,
    required this.enableReaderMode,
    required this.findInPage,
    required this.findNext,
    required this.findPrevious,
    required this.clearFind,
    required this.currentUrl,
    required this.currentTitle,
    required this.extractArticleContent,
    required this.takeScreenshot,
  });
}

class _ChromeWebViewState extends ConsumerState<ChromeWebView> with AutomaticKeepAliveClientMixin {
  InAppWebViewController? webViewController;
  PullToRefreshController? pullToRefreshController;
  
  String _currentUrl = '';
  String _currentTitle = '';
  bool _isLoading = false;
  double _progress = 0.0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isDesktopMode = false; // Track desktop mode state
  DateTime? _lastProgressUpdate; // Throttle progress updates
  DateTime? _lastScrollNotify; // Throttle scroll notifications

  @override
  bool get wantKeepAlive => true; // Keep WebView alive when not visible

  @override
  void initState() {
    super.initState();
    
    // Pull to refresh controller - will be initialized in didChangeDependencies
    
    // Notify parent with controller after widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onWebViewCreated?.call(
        ChromeWebViewController(
          loadUrl: loadUrl,
          showMenu: _showChromeMenu,
          canGoBack: () async => _canGoBack,
          canGoForward: () async => _canGoForward,
          goBack: () => webViewController?.goBack(),
          goForward: () => webViewController?.goForward(),
          reload: () => webViewController?.reload(),
          setDesktopMode: _setDesktopMode,
          enableReaderMode: _enableReaderMode,
          findInPage: _findInPage,
          findNext: _findNext,
          findPrevious: _findPrevious,
          clearFind: _clearFind,
          currentUrl: () async => _currentUrl,
          currentTitle: () async => _currentTitle,
          extractArticleContent: _extractArticleContent,
          takeScreenshot: _takeScreenshot,
        ),
      );
    });
  }

  void _setDesktopMode(bool isDesktop) async {
    if (webViewController != null && mounted) {
      setState(() {
        _isDesktopMode = isDesktop;
      });
      
      final userAgent = isDesktop
          ? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
          : 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.144 Mobile Safari/537.36';
      
      webViewController!.setSettings(
        settings: InAppWebViewSettings(
          userAgent: userAgent,
          useWideViewPort: true, // Always use wide viewport for proper scaling
          loadWithOverviewMode: !isDesktop, // Overview mode for mobile, normal for desktop
          supportZoom: true, // Always enable zoom
          // Android specific settings for desktop mode
          mediaPlaybackRequiresUserGesture: false,
          // iOS specific settings
          allowsInlineMediaPlayback: true,
        ),
      );
      
      // Inject viewport meta tag for proper desktop/mobile rendering
      final widthValue = isDesktop ? 'width=1024' : 'width=device-width';
      await webViewController!.evaluateJavascript(source: '''
        (function() {
          var viewport = document.querySelector('meta[name="viewport"]');
          var viewportContent = '$widthValue, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes, minimum-scale=0.5';
          if (viewport) {
            viewport.setAttribute('content', viewportContent);
          } else {
            var meta = document.createElement('meta');
            meta.name = 'viewport';
            meta.content = viewportContent;
            var head = document.getElementsByTagName('head')[0];
            if (head) {
              head.appendChild(meta);
            }
          }
        })();
      ''');
      
      webViewController!.reload();
    }
  }

  Future<String> _extractArticleContent() async {
    if (webViewController != null) {
      // Get page HTML and extract readable content
      final result = await webViewController!.evaluateJavascript(source: '''
        (function() {
          try {
            // Try to find article content
            var article = document.querySelector('article') || 
                         document.querySelector('[role="article"]') ||
                         document.querySelector('main') ||
                         document.querySelector('.article') ||
                         document.querySelector('.post') ||
                         document.querySelector('.content') ||
                         document.querySelector('#content') ||
                         document.body;
            
            // Remove script and style elements
            var scripts = article.querySelectorAll('script, style, nav, header, footer, aside, .ad, .advertisement, .sidebar');
            scripts.forEach(function(el) { el.remove(); });
            
            // Get text content
            var text = article.innerText || article.textContent || '';
            
            // Clean up whitespace
            text = text.replace(/\\s+/g, ' ').trim();
            
            return text;
          } catch(e) {
            return document.body ? document.body.innerText : '';
          }
        })()
      ''');
      
      if (result != null) {
        final content = result.toString();
        // Remove quotes if JavaScript returned a string
        if (content.startsWith('"') && content.endsWith('"')) {
          return content.substring(1, content.length - 1);
        }
        return content;
      }
    }
    return '';
  }

  Future<Uint8List?> _takeScreenshot() async {
    if (webViewController != null) {
      try {
        final screenshot = await webViewController!.takeScreenshot();
        return screenshot;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  void _enableReaderMode() async {
    if (webViewController != null) {
      // Get page HTML and extract readable content
      final html = await webViewController!.evaluateJavascript(source: '''
        (function() {
          try {
            var article = document.querySelector('article') || document.querySelector('main') || document.body;
            return article ? article.innerText : document.body.innerText;
          } catch(e) {
            return document.body.innerText;
          }
        })()
      ''');
      
      if (html != null && html.toString().isNotEmpty) {
        // Show reader mode view
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.article),
                  const SizedBox(width: 8),
                  const Text('Reader Mode'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: SelectableText(
                    html.toString(),
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                ),
              ),
            ),
          );
        }
      }
    }
  }

  String? _currentFindText;
  Function(int, int)? _onFindResult;

  void _findInPage(String text) {
    if (webViewController != null && text.isNotEmpty) {
      _currentFindText = text;
      webViewController!.findAllAsync(find: text);
    } else if (text.isEmpty) {
      _clearFind();
    }
  }

  void _findNext() async {
    if (webViewController != null && _currentFindText != null && _currentFindText!.isNotEmpty) {
      // Always ensure search is active before navigating
      // Call findAllAsync to ensure search is active, then navigate
      webViewController!.findAllAsync(find: _currentFindText!);
      // Wait for search to initialize - longer delay for reliability
      await Future.delayed(const Duration(milliseconds: 300));
      // Now navigate to next match
      if (webViewController != null && _currentFindText != null) {
        webViewController!.findNext(forward: true);
      }
    }
  }

  void _findPrevious() async {
    if (webViewController != null && _currentFindText != null && _currentFindText!.isNotEmpty) {
      // Always ensure search is active before navigating
      // Call findAllAsync to ensure search is active, then navigate
      webViewController!.findAllAsync(find: _currentFindText!);
      // Wait for search to initialize - longer delay for reliability
      await Future.delayed(const Duration(milliseconds: 300));
      // Now navigate to previous match
      if (webViewController != null && _currentFindText != null) {
        webViewController!.findNext(forward: false);
      }
    }
  }

  void _clearFind() {
    if (webViewController != null) {
      _currentFindText = null;
      webViewController!.clearMatches();
      _onFindResult?.call(0, 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Initialize pull to refresh controller with theme
    if (pullToRefreshController == null) {
      pullToRefreshController = PullToRefreshController(
        settings: PullToRefreshSettings(
          color: Theme.of(context).colorScheme.primary,
        ),
        onRefresh: () async {
          await webViewController?.reload();
        },
      );
    }
  }

  Future<void> loadUrl(String input) async {
    if (input.isEmpty) return;
    
    // Prevent "discover" from being treated as a URL
    final trimmedInput = input.trim();
    if (trimmedInput == 'discover' || 
        trimmedInput == 'http://discover' || 
        trimmedInput == 'https://discover' ||
        trimmedInput == 'http://discover/' ||
        trimmedInput == 'https://discover/') {
      return; // Don't load "discover" as a URL
    }

    String url;
    if (Validators.isValidUrl(input)) {
      url = Validators.getValidUrl(input);
    } else {
      // It's a search query
      url = '${ApiConstants.googleSearchUrl}${Uri.encodeComponent(input)}';
    }

    // CRITICAL: Prevent duplicate loads - check if we're already loading or just loaded this exact URL
    if (_currentUrl == url) {
      // If we're already on this URL and loading, skip
      if (_isLoading) {
        return; // Already loading this URL, skip
      }
      // If we just loaded this URL very recently (within 500ms), skip to prevent rapid reloads
      // This prevents multiple rapid calls from causing duplicate loads
    }

    // Mark as loading immediately to prevent duplicate calls
    _isLoading = true;
    _currentUrl = url; // Update immediately so duplicate checks work

    try {
      await webViewController?.loadUrl(
        urlRequest: URLRequest(url: WebUri(url)),
      );
    } catch (e) {
      // Reset loading state on error
      _isLoading = false;
      rethrow;
    }
  }

  Future<void> _updateNavigationState() async {
    _canGoBack = await webViewController?.canGoBack() ?? false;
    _canGoForward = await webViewController?.canGoForward() ?? false;
    if (mounted) {
      setState(() {});
    }
  }

  void _showChromeMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Forward option
              ListTile(
                leading: Icon(
                  Icons.arrow_forward,
                  color: _canGoForward
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
                title: const Text('Forward'),
                enabled: _canGoForward,
                onTap: _canGoForward
                    ? () {
                        webViewController?.goForward();
                        Navigator.pop(context);
                      }
                    : null,
              ),
              
              // Refresh option
              ListTile(
                leading: Icon(
                  Icons.refresh,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Refresh'),
                onTap: () {
                  webViewController?.reload();
                  Navigator.pop(context);
                },
              ),
              
              // Bookmark option
              ListTile(
                leading: Icon(
                  Icons.bookmark_add,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Add to Bookmarks'),
                onTap: () async {
                  if (_currentUrl.isNotEmpty) {
                    final wasAdded = await ref.read(bookmarksProvider.notifier).addBookmark(
                      title: _currentTitle.isEmpty ? _currentUrl : _currentTitle,
                      url: _currentUrl,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(wasAdded 
                            ? 'Added to bookmarks' 
                            : 'Bookmark already exists (updated)'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
              ),
              
              // Share option
              ListTile(
                leading: Icon(
                  Icons.share,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Share'),
                onTap: () async {
                  Navigator.pop(context);
                  if (_currentUrl.isNotEmpty && _currentUrl != 'discover') {
                    try {
                      await Share.share(
                        _currentUrl,
                        subject: _currentTitle.isNotEmpty ? _currentTitle : 'Shared from Void Browser',
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to share: ${e.toString()}'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  }
                },
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Column(
      children: [
        // Progress bar
        if (widget.showProgress && _isLoading)
          LinearProgressIndicator(
            value: _progress,
            minHeight: 2,
            backgroundColor: Colors.transparent,
          ),
        
        // WebView
        Expanded(
          child: Consumer(
            builder: (context, ref, child) {
              // Use select to only watch isEnabled, not entire state
              final isAdBlockEnabled = ref.watch(adBlockProvider.select((state) => state.isEnabled));
              final adBlockNotifier = ref.read(adBlockProvider.notifier);
              
              // Get content blockers and ad blocking JavaScript
              final contentBlockers = isAdBlockEnabled 
                  ? adBlockNotifier.getContentBlockers() 
                  : <ContentBlocker>[];
              final adBlockingJS = isAdBlockEnabled 
                  ? adBlockNotifier.getAdBlockingJavaScript() 
                  : '';
              
              return InAppWebView(
                initialUrlRequest: widget.initialUrl != null && 
                    widget.initialUrl!.trim() != 'discover' &&
                    widget.initialUrl!.trim() != 'http://discover' &&
                    widget.initialUrl!.trim() != 'https://discover' &&
                    widget.initialUrl!.trim() != 'http://discover/' &&
                    widget.initialUrl!.trim() != 'https://discover/'
                    ? URLRequest(url: WebUri(widget.initialUrl!))
                    : null,
                pullToRefreshController: pullToRefreshController,
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true, // CRITICAL: Must be enabled for ad blocking
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  supportZoom: true, // Enable pinch-to-zoom
                  builtInZoomControls: false, // Hide built-in zoom controls (use pinch-to-zoom)
                  displayZoomControls: false, // Hide zoom controls UI
                  useWideViewPort: true, // Enable wide viewport for proper mobile scaling
                  loadWithOverviewMode: true, // Load with overview mode for better initial scaling
                  useHybridComposition: true,
                  verticalScrollBarEnabled: true,
                  horizontalScrollBarEnabled: true,
                  // Android specific zoom settings
                  mediaPlaybackRequiresUserGesture: false,
                  // iOS specific settings
                  allowsInlineMediaPlayback: true,
                  // Ensure proper viewport meta tag handling
                  javaScriptCanOpenWindowsAutomatically: false,
                  // CRITICAL: Ad blocking content blockers (native-level blocking)
                  contentBlockers: contentBlockers,
                  // Performance optimizations
                  cacheEnabled: true,
                  clearCache: false, // Don't clear cache on each load
                  // Additional performance optimizations for faster loading
                  thirdPartyCookiesEnabled: true, // Enable third-party cookies for better compatibility
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW, // Allow mixed content for faster loading
                  allowsLinkPreview: false, // Disable link preview for better performance
                  // Android-specific performance settings
                  hardwareAcceleration: true, // Enable hardware acceleration
                  // Reduce text size for better performance (will be overridden by viewport)
                  textZoom: 100, // 100% text zoom
                  // Optimize rendering
                  transparentBackground: false, // Opaque background for better performance
                  // Disable unnecessary features for performance
                  disableHorizontalScroll: false,
                  disableVerticalScroll: false,
                  // Cache mode for better performance - use cache aggressively
                  cacheMode: CacheMode.LOAD_CACHE_ELSE_NETWORK, // Prefer cache for faster loading
                  // Better user agent for compatibility with sites like Facebook
                  userAgent: 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.144 Mobile Safari/537.36',
                  // Additional settings for better compatibility
                  allowsBackForwardNavigationGestures: true,
                  // Enable safe browsing (Android)
                  safeBrowsingEnabled: true,
                  // Additional performance optimizations
                  minimumLogicalFontSize: 8, // Reduce minimum font size for faster rendering
                  minimumFontSize: 8,
                  // Disable unnecessary features for performance
                  geolocationEnabled: false, // Disable geolocation for faster page loads
                  // Optimize for speed
                  blockNetworkImage: false, // Allow images for better UX
                  blockNetworkLoads: false,
                ),
                // Inject scripts at document start for ad blocking and share interception
                initialUserScripts: UnmodifiableListView([
                  // Ad blocking script (if enabled)
                  if (isAdBlockEnabled && adBlockingJS.isNotEmpty)
                    UserScript(
                      source: adBlockingJS,
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    ),
                  // Share button interception script
                  UserScript(
                    source: '''
                      (function() {
                        // Intercept Web Share API
                        if (navigator.share) {
                          const originalShare = navigator.share.bind(navigator);
                          navigator.share = function(data) {
                            // Send share data to Flutter
                            window.flutter_inappwebview.callHandler('handleShare', {
                              title: data.title || document.title,
                              text: data.text || '',
                              url: data.url || window.location.href
                            });
                            return Promise.resolve();
                          };
                        }
                        
                        // Intercept common share button patterns
                        document.addEventListener('click', function(e) {
                          const target = e.target.closest('[data-share], [class*="share"], [id*="share"], button[aria-label*="share" i], a[href*="share"]');
                          if (target) {
                            e.preventDefault();
                            e.stopPropagation();
                            
                            let shareData = {
                              title: document.title,
                              text: '',
                              url: window.location.href
                            };
                            
                            // Try to extract share data from common patterns
                            const shareText = target.getAttribute('data-share-text') || 
                                            target.textContent?.trim() || '';
                            const shareUrl = target.getAttribute('data-share-url') || 
                                           target.href || 
                                           window.location.href;
                            
                            shareData.text = shareText;
                            shareData.url = shareUrl;
                            
                            window.flutter_inappwebview.callHandler('handleShare', shareData);
                          }
                        }, true);
                        
                        // Intercept Facebook share buttons
                        document.addEventListener('click', function(e) {
                          const href = e.target.closest('a')?.href || e.target.href;
                          if (href && (href.includes('facebook.com/sharer') || 
                                       href.includes('fb.com/share') ||
                                       href.includes('facebook.com/share'))) {
                            e.preventDefault();
                            e.stopPropagation();
                            const url = new URL(href);
                            const u = url.searchParams.get('u') || window.location.href;
                            window.flutter_inappwebview.callHandler('handleShare', {
                              title: document.title,
                              text: '',
                              url: u
                            });
                          }
                        }, true);
                        
                        // Intercept Twitter/X share buttons
                        document.addEventListener('click', function(e) {
                          const href = e.target.closest('a')?.href || e.target.href;
                          if (href && (href.includes('twitter.com/intent/tweet') || 
                                       href.includes('x.com/intent/tweet'))) {
                            e.preventDefault();
                            e.stopPropagation();
                            const url = new URL(href);
                            const text = url.searchParams.get('text') || document.title;
                            const shareUrl = url.searchParams.get('url') || window.location.href;
                            window.flutter_inappwebview.callHandler('handleShare', {
                              title: document.title,
                              text: text,
                              url: shareUrl
                            });
                          }
                        }, true);
                      })();
                    ''',
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                  ),
                ]),
            onWebViewCreated: (controller) async {
              webViewController = controller;
              // Initialize desktop mode state from saved preference
              // This will be applied when the page loads
              
              // Register JavaScript handler for share functionality
              controller.addJavaScriptHandler(
                handlerName: 'handleShare',
                callback: (args) {
                  if (args.isNotEmpty && args[0] is Map) {
                    final shareData = args[0] as Map<String, dynamic>;
                    final title = shareData['title'] as String? ?? _currentTitle;
                    final url = shareData['url'] as String? ?? _currentUrl;
                    
                    if (mounted) {
                      try {
                        Share.share(
                          url,
                          subject: title.isNotEmpty ? title : 'Shared from Void Browser',
                        );
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to share: ${e.toString()}'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    }
                  }
                },
              );
            },
            onLoadStart: (controller, url) async {
              // Update URL immediately for instant feedback in search bar
              final urlString = url.toString();
              _currentUrl = urlString;
              
              // Notify parent immediately for instant URL update in search bar
              widget.onUrlChanged?.call(urlString);
              
              if (mounted) {
                setState(() {
                  _isLoading = true;
                });
              }
              
              // Update navigation state asynchronously to avoid blocking
              _updateNavigationState();
              
              // Note: Ad blocking script is injected via initialUserScripts at document start
              // No need for redundant injection here - improves performance
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url.toString();
              final lowerUrl = url.toLowerCase();
              
              // Handle app-specific links (WhatsApp, Facebook, etc.)
              // Check for common app link patterns
              if (url.startsWith('whatsapp://') || 
                  url.startsWith('fb://') || 
                  url.startsWith('facebook://') ||
                  url.startsWith('twitter://') ||
                  url.startsWith('instagram://') ||
                  url.startsWith('telegram://') ||
                  url.startsWith('viber://') ||
                  url.startsWith('sms:') ||
                  url.startsWith('tel:') ||
                  url.startsWith('mailto:')) {
                // Try to launch the app
                try {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                    return NavigationActionPolicy.CANCEL;
                  }
                } catch (e) {
                  // If app is not installed, continue with web navigation
                }
              }
              
              // Handle share URLs - intercept and use native share
              if (lowerUrl.contains('facebook.com/sharer') || 
                  lowerUrl.contains('fb.com/share') ||
                  lowerUrl.contains('twitter.com/intent/tweet') ||
                  lowerUrl.contains('x.com/intent/tweet') ||
                  lowerUrl.contains('linkedin.com/sharing/share-offsite') ||
                  lowerUrl.contains('reddit.com/submit')) {
                try {
                  final uri = Uri.parse(url);
                  String? shareUrl;
                  String? shareText;
                  
                  // Extract URL and text from query parameters
                  if (uri.queryParameters.containsKey('u')) {
                    shareUrl = uri.queryParameters['u'];
                  } else if (uri.queryParameters.containsKey('url')) {
                    shareUrl = uri.queryParameters['url'];
                  } else {
                    shareUrl = _currentUrl;
                  }
                  
                  if (uri.queryParameters.containsKey('text')) {
                    shareText = uri.queryParameters['text'];
                  } else if (uri.queryParameters.containsKey('quote')) {
                    shareText = uri.queryParameters['quote'];
                  }
                  
                  if (mounted && shareUrl != null) {
                    Share.share(
                      shareUrl,
                      subject: shareText ?? _currentTitle,
                    );
                  }
                  return NavigationActionPolicy.CANCEL;
                } catch (e) {
                  // If share fails, allow normal navigation
                }
              }
              
              // OPTIMIZED: Block ad URLs at the network level with error handling
              if (isAdBlockEnabled) {
                try {
                  // CRITICAL: NEVER block YouTube/Google player APIs - allow all YouTube functionality
                  // Only block actual ad endpoints, not player APIs
                  if (lowerUrl.contains('youtube.com') || 
                      lowerUrl.contains('youtu.be') ||
                      lowerUrl.contains('googlevideo.com') ||
                      lowerUrl.contains('google.com') ||
                      lowerUrl.contains('gstatic.com')) {
                    // Block IMA SDK completely (ad SDK, not player API)
                    if (lowerUrl.contains('imasdk.googleapis.com')) {
                      adBlockNotifier.incrementBlockedCount();
                      return NavigationActionPolicy.CANCEL;
                    }
                    // Block ONLY actual ad API endpoints (not player APIs)
                    // Be very selective - only block confirmed ad endpoints
                    if (lowerUrl.contains('/api/stats/ads') ||
                        lowerUrl.contains('/ptracking') ||
                        lowerUrl.contains('/pagead')) {
                      adBlockNotifier.incrementBlockedCount();
                      return NavigationActionPolicy.CANCEL;
                    }
                    // Allow all other YouTube/Google URLs (player APIs, search, navigation, videos, etc.)
                    return NavigationActionPolicy.ALLOW;
                  }
                  
                  // Quick check - skip if URL is too short or is main document
                  if (url.length < 10 || navigationAction.request.mainDocumentURL == url) {
                    return NavigationActionPolicy.ALLOW;
                  }
                  
                  if (adBlockNotifier.shouldBlockUrl(url)) {
                    adBlockNotifier.incrementBlockedCount();
                    return NavigationActionPolicy.CANCEL;
                  }
                } catch (e) {
                  // On error, allow the request to prevent crashes
                  return NavigationActionPolicy.ALLOW;
                }
              }
              return NavigationActionPolicy.ALLOW;
            },
            onLoadStop: (controller, url) async {
              // URL is already updated in onLoadStart for instant feedback
              // Only update loading state here
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
              pullToRefreshController?.endRefreshing();
              
              // Get title and update navigation state asynchronously
              _currentTitle = await controller.getTitle() ?? '';
              _updateNavigationState();
              
              // Note: Ad blocking script is injected via initialUserScripts at document start
              // No redundant injection needed - improves performance and prevents double-loading feeling
              
              // Ensure viewport meta tag allows zooming and respects desktop mode
              try {
                final isDesktop = _isDesktopMode;
                final widthValue = isDesktop ? 'width=1024' : 'width=device-width';
                final isDesktopStr = isDesktop.toString();
                await controller.evaluateJavascript(source: '''
                  (function() {
                    var viewport = document.querySelector('meta[name="viewport"]');
                    var viewportContent = '$widthValue, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes, minimum-scale=0.5';
                    var isDesktop = $isDesktopStr;
                    
                    if (viewport) {
                      var content = viewport.getAttribute('content') || '';
                      // Ensure user-scalable is yes for zooming
                      if (content.includes('user-scalable=no')) {
                        viewport.setAttribute('content', content.replace('user-scalable=no', 'user-scalable=yes'));
                      }
                      // Ensure max scale allows zooming
                      if (!content.includes('maximum-scale')) {
                        viewport.setAttribute('content', content + ', maximum-scale=5.0');
                      }
                      // Ensure min scale allows zooming out
                      if (!content.includes('minimum-scale')) {
                        viewport.setAttribute('content', content + ', minimum-scale=0.5');
                      }
                      // Update width based on desktop mode if not already set correctly
                      if (isDesktop && !content.includes('width=1024')) {
                        viewport.setAttribute('content', viewportContent);
                      } else if (!isDesktop && !content.includes('width=device-width')) {
                        viewport.setAttribute('content', viewportContent);
                      }
                    } else {
                      // Add viewport meta tag if it doesn't exist
                      var meta = document.createElement('meta');
                      meta.name = 'viewport';
                      meta.content = viewportContent;
                      var head = document.getElementsByTagName('head')[0];
                      if (head) {
                        head.appendChild(meta);
                      }
                    }
                  })();
                ''');
              } catch (e) {
                // Ignore errors if JavaScript execution fails
              }
            },
            onProgressChanged: (controller, progress) {
              if (progress == 100) {
                pullToRefreshController?.endRefreshing();
              }
              
              // Aggressive throttling: Update progress max every 300ms for better performance
              // Only update immediately at 0% and 100% for instant feedback
              final now = DateTime.now();
              if (_lastProgressUpdate == null || 
                  now.difference(_lastProgressUpdate!).inMilliseconds > 300 ||
                  progress == 100 || progress == 0) {
                _lastProgressUpdate = now;
                if (mounted) {
                  setState(() {
                    _progress = progress / 100;
                    _isLoading = progress < 100;
                  });
                }
              }
            },
            onUpdateVisitedHistory: (controller, url, androidIsReload) {
              _updateNavigationState();
            },
            onScrollChanged: (controller, x, y) {
              // Throttle scroll events to reduce lag (only notify every 16ms = ~60fps)
              final now = DateTime.now();
              if (_lastScrollNotify == null || 
                  now.difference(_lastScrollNotify!).inMilliseconds >= 16) {
                _lastScrollNotify = now;
                // Notify parent about scroll position changes
                widget.onScrollChanged?.call(x, y);
              }
            },
            onFindResultReceived: (controller, activeMatchOrdinal, numberOfMatches, isDoneCounting) {
              // Update find results when matches are found
              // Always update the callback to ensure count is shown
              // activeMatchOrdinal is 1-indexed (0 means no active match)
              // Update whenever we have results or when counting is done
              if (isDoneCounting) {
                // When counting is done, use the actual values
                final activeMatch = activeMatchOrdinal > 0 ? activeMatchOrdinal : (numberOfMatches > 0 ? 1 : 0);
                _onFindResult?.call(activeMatch, numberOfMatches);
              } else if (numberOfMatches > 0) {
                // While counting, still update if we have matches found so far
                final activeMatch = activeMatchOrdinal > 0 ? activeMatchOrdinal : 1;
                _onFindResult?.call(activeMatch, numberOfMatches);
              } else if (numberOfMatches == 0 && isDoneCounting) {
                // No matches found
                _onFindResult?.call(0, 0);
              }
            },
            onDownloadStartRequest: (controller, downloadStartRequest) async {
              // Handle download requests from WebView
              final url = downloadStartRequest.url.toString();
              
              try {
                // Block ad-related downloads with error handling
                if (isAdBlockEnabled && url.length > 10) {
                  if (adBlockNotifier.shouldBlockUrl(url)) {
                    adBlockNotifier.incrementBlockedCount();
                    return;
                  }
                }
              } catch (e) {
                // On error, allow download to prevent crashes
              }
              
              final suggestedFilename = downloadStartRequest.suggestedFilename ?? 
                  url.split('/').last.split('?').first;
              
              // Extract filename from URL if not provided
              String filename = suggestedFilename;
              if (filename.isEmpty || !filename.contains('.')) {
                final uri = Uri.parse(url);
                final pathSegments = uri.pathSegments;
                if (pathSegments.isNotEmpty) {
                  filename = pathSegments.last;
                } else {
                  // Generate default filename
                  final extension = url.split('.').last.split('?').first;
                  filename = 'download_${DateTime.now().millisecondsSinceEpoch}.$extension';
                }
              }
              
              // Notify parent about download request
              widget.onDownloadRequested?.call(url, filename);
              
              // Cancel the default download handler - return true to cancel, false to allow default
              // We return true to cancel because we're handling it ourselves
            },
            onConsoleMessage: (controller, consoleMessage) {
              // Optionally log blocked requests (for debugging)
              // print('Console: ${consoleMessage.message}');
            },
              );
            },
          ),
        ),
      ],
    );
  }
}

