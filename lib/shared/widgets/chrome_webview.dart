import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/validators.dart';
import '../../features/bookmarks/presentation/providers/bookmarks_provider.dart';

/// Chrome-like WebView component with gestures and modern UX
class ChromeWebView extends ConsumerStatefulWidget {
  final String? initialUrl;
  final Function(String url)? onUrlChanged;
  final bool showProgress;
  final void Function(ChromeWebViewController controller)? onWebViewCreated;
  final Function(int x, int y)? onScrollChanged; // Callback for scroll position changes

  const ChromeWebView({
    super.key,
    this.initialUrl,
    this.onUrlChanged,
    this.showProgress = true,
    this.onWebViewCreated,
    this.onScrollChanged,
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
  final Future<String?> Function() currentUrl;
  final Future<String?> Function() currentTitle;

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
    required this.currentUrl,
    required this.currentTitle,
  });
}

class _ChromeWebViewState extends ConsumerState<ChromeWebView> {
  InAppWebViewController? webViewController;
  PullToRefreshController? pullToRefreshController;
  
  String _currentUrl = '';
  String _currentTitle = '';
  bool _isLoading = false;
  double _progress = 0.0;
  bool _canGoBack = false;
  bool _canGoForward = false;

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
          currentUrl: () async => _currentUrl,
          currentTitle: () async => _currentTitle,
        ),
      );
    });
  }

  void _setDesktopMode(bool isDesktop) {
    if (webViewController != null) {
      final userAgent = isDesktop
          ? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
          : 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.144 Mobile Safari/537.36';
      
      webViewController!.setSettings(
        settings: InAppWebViewSettings(
          userAgent: userAgent,
          useWideViewPort: isDesktop,
          loadWithOverviewMode: isDesktop,
        ),
      );
      webViewController!.reload();
    }
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

  void _findInPage(String text) {
    if (webViewController != null && text.isNotEmpty) {
      webViewController!.findAllAsync(find: text);
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

    await webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(url)),
    );
  }

  Future<void> _updateNavigationState() async {
    _canGoBack = await webViewController?.canGoBack() ?? false;
    _canGoForward = await webViewController?.canGoForward() ?? false;
    setState(() {});
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
                    await ref.read(bookmarksProvider.notifier).addBookmark(
                      title: _currentTitle.isEmpty ? _currentUrl : _currentTitle,
                      url: _currentUrl,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Added to bookmarks'),
                          duration: Duration(seconds: 2),
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
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement share functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Share functionality coming soon'),
                      duration: Duration(seconds: 2),
                    ),
                  );
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
          child: InAppWebView(
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
              javaScriptEnabled: true,
              domStorageEnabled: true,
              databaseEnabled: true,
              supportZoom: true,
              builtInZoomControls: false,
              displayZoomControls: false,
              useHybridComposition: true,
              verticalScrollBarEnabled: true,
              horizontalScrollBarEnabled: true,
            ),
            onWebViewCreated: (controller) {
              webViewController = controller;
            },
            onLoadStart: (controller, url) {
              setState(() {
                _isLoading = true;
                _currentUrl = url.toString();
              });
              widget.onUrlChanged?.call(url.toString());
              _updateNavigationState();
            },
            onLoadStop: (controller, url) async {
              setState(() {
                _isLoading = false;
                _currentUrl = url.toString();
              });
              pullToRefreshController?.endRefreshing();
              _currentTitle = await controller.getTitle() ?? '';
              _updateNavigationState();
              widget.onUrlChanged?.call(url.toString());
            },
            onProgressChanged: (controller, progress) {
              if (progress == 100) {
                pullToRefreshController?.endRefreshing();
              }
              setState(() {
                _progress = progress / 100;
                _isLoading = progress < 100;
              });
            },
            onUpdateVisitedHistory: (controller, url, androidIsReload) {
              _updateNavigationState();
            },
            onScrollChanged: (controller, x, y) {
              // Notify parent about scroll position changes
              widget.onScrollChanged?.call(x, y);
            },
          ),
        ),
      ],
    );
  }
}

