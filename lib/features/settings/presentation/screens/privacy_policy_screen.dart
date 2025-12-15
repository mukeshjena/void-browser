import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PrivacyPolicyScreen extends ConsumerStatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  ConsumerState<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends ConsumerState<PrivacyPolicyScreen> {
  InAppWebViewController? webViewController;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  double _progress = 0.0;
  static const String privacyPolicyUrl = 'https://mukeshjena.com/vex-fast-privacy-browser-privacy-policy';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: isDark ? Colors.black : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: _hasError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load privacy policy',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    if (_errorMessage != null)
                      Text(
                        _errorMessage!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _hasError = false;
                          _errorMessage = null;
                          _isLoading = true;
                        });
                        webViewController?.reload();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(privacyPolicyUrl)),
                  initialSettings: InAppWebViewSettings(
                    // Disable zoom completely
                    supportZoom: false,
                    builtInZoomControls: false,
                    displayZoomControls: false,
                    // Make it look native
                    useWideViewPort: true,
                    loadWithOverviewMode: true,
                    // Disable other browser-like features
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    // Styling to match native Android
                    useHybridComposition: true,
                    verticalScrollBarEnabled: true,
                    horizontalScrollBarEnabled: false,
                    // Disable other browser features
                    javaScriptCanOpenWindowsAutomatically: false,
                    // Performance
                    cacheEnabled: true,
                    // Android specific
                    mediaPlaybackRequiresUserGesture: false,
                    // iOS specific
                    allowsInlineMediaPlayback: true,
                    // Disable user interaction that might feel like browser
                    disableHorizontalScroll: false,
                    disableVerticalScroll: false,
                  ),
                  onWebViewCreated: (controller) {
                    webViewController = controller;
                  },
                  onLoadStart: (controller, url) {
                    setState(() {
                      _isLoading = true;
                      _hasError = false;
                      _errorMessage = null;
                      _progress = 0.0;
                    });
                  },
                  onProgressChanged: (controller, progress) {
                    setState(() {
                      _progress = progress / 100;
                      if (progress == 100) {
                        _isLoading = false;
                      }
                    });
                  },
                  onLoadStop: (controller, url) async {
                    setState(() {
                      _isLoading = false;
                    });
                    // Inject comprehensive zoom prevention and native styling after page loads
                    await controller.evaluateJavascript(source: '''
                (function() {
                  // Disable zoom via viewport meta tag
                  var viewport = document.querySelector('meta[name="viewport"]');
                  if (viewport) {
                    viewport.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');
                  } else {
                    var meta = document.createElement('meta');
                    meta.name = 'viewport';
                    meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
                    var head = document.getElementsByTagName('head')[0];
                    if (head) {
                      head.appendChild(meta);
                    }
                  }
                  
                  // Disable pinch zoom via touch events
                  var preventZoom = function(e) {
                    if (e.touches && e.touches.length > 1) {
                      e.preventDefault();
                    }
                  };
                  
                  document.addEventListener('touchstart', preventZoom, { passive: false });
                  document.addEventListener('touchmove', preventZoom, { passive: false });
                  document.addEventListener('touchend', preventZoom, { passive: false });
                  document.addEventListener('touchcancel', preventZoom, { passive: false });
                  
                  // Disable double-tap zoom
                  var lastTouchEnd = 0;
                  document.addEventListener('touchend', function(e) {
                    var now = Date.now();
                    if (now - lastTouchEnd <= 300) {
                      e.preventDefault();
                    }
                    lastTouchEnd = now;
                  }, { passive: false });
                  
                  // Disable wheel zoom
                  document.addEventListener('wheel', function(e) {
                    if (e.ctrlKey) {
                      e.preventDefault();
                    }
                  }, { passive: false });
                  
                  // Disable keyboard zoom (Ctrl + Plus/Minus)
                  document.addEventListener('keydown', function(e) {
                    if ((e.ctrlKey || e.metaKey) && (e.key === '+' || e.key === '-' || e.key === '=')) {
                      e.preventDefault();
                    }
                  });
                  
                  // Style adjustments for native Android feel
                  var style = document.createElement('style');
                  style.innerHTML = `
                    * {
                      -webkit-tap-highlight-color: transparent;
                    }
                    body {
                      margin: 0;
                      padding: 16px;
                      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
                      line-height: 1.6;
                      -webkit-text-size-adjust: 100%;
                      text-size-adjust: 100%;
                    }
                    /* Allow text selection for readability */
                    p, li, span, div, h1, h2, h3, h4, h5, h6 {
                      -webkit-user-select: text;
                      user-select: text;
                    }
                    a {
                      -webkit-user-select: text;
                      user-select: text;
                      -webkit-touch-callout: default;
                    }
                    /* Prevent image drag/zoom */
                    img {
                      -webkit-user-drag: none;
                      user-drag: none;
                      max-width: 100%;
                      height: auto;
                    }
                  `;
                  var existingStyle = document.getElementById('void-native-style');
                  if (existingStyle) {
                    existingStyle.remove();
                  }
                  style.id = 'void-native-style';
                  document.head.appendChild(style);
                  
                  // Force viewport scale
                  var metaViewport = document.querySelector('meta[name="viewport"]');
                  if (metaViewport) {
                    metaViewport.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');
                    }
                  })();
                ''');
                  },
                  onReceivedError: (controller, request, error) {
                    setState(() {
                      _isLoading = false;
                      _hasError = true;
                      _errorMessage = error.description;
                    });
                  },
                  onReceivedHttpError: (controller, request, response) {
                    setState(() {
                      _isLoading = false;
                      _hasError = true;
                      _errorMessage = 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
                    });
                  },
                ),
          // Loading indicator
          if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
              ],
            ),
    );
  }
}

