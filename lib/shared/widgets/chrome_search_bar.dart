import 'package:flutter/material.dart';
import '../../core/theme/app_dimensions.dart';
import 'expanded_search_bar_overlay.dart';

/// Chrome-style search bar that detects URL vs search query
class ChromeSearchBar extends StatefulWidget {
  final String? initialText;
  final Function(String)? onSubmitted;
  final Function(String)? onChanged;
  final bool autofocus;
  final TextEditingController? controller;
  final bool showMenu;
  final VoidCallback? onMenuTap;
  final String? currentUrl; // Current URL for security icon
  final Function(bool)? onFocusChanged; // Callback when focus changes

  const ChromeSearchBar({
    super.key,
    this.initialText,
    this.onSubmitted,
    this.onChanged,
    this.autofocus = false,
    this.controller,
    this.showMenu = false,
    this.onMenuTap,
    this.currentUrl,
    this.onFocusChanged,
  });

  @override
  State<ChromeSearchBar> createState() => _ChromeSearchBarState();
}

class _ChromeSearchBarState extends State<ChromeSearchBar> {
  late TextEditingController _controller;
  bool _isSecure = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController(text: widget.initialText);
    _controller.addListener(_checkSecure);
    _checkSecure(); // Check security on init
  }

  @override
  void didUpdateWidget(ChromeSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update security status when currentUrl changes
    if (widget.currentUrl != oldWidget.currentUrl) {
      _checkSecure();
    }
    // Sync controller if external controller changed
    if (widget.controller != oldWidget.controller) {
      if (widget.controller != null) {
        _controller.removeListener(_checkSecure);
        _controller = widget.controller!;
        _controller.addListener(_checkSecure);
      }
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _checkSecure() {
    // Check both the controller text and the currentUrl prop
    final text = widget.currentUrl ?? _controller.text;
    setState(() {
      _isSecure = text.startsWith('https://');
    });
  }

  void _showExpandedSearchBar() {
    // Show overlay with expanded search bar
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, animation, secondaryAnimation) => ExpandedSearchBarOverlay(
          controller: _controller,
          currentUrl: widget.currentUrl,
          isSecure: _isSecure,
          onSubmitted: (value) {
            widget.onSubmitted?.call(value);
            // Pop using root navigator
            Navigator.of(context, rootNavigator: true).pop();
          },
          onChanged: widget.onChanged,
          onDismiss: () {
            // This callback is called by the overlay's _dismiss method
            // The actual pop is handled in _dismiss, so we don't need to do anything here
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    ).then((_) {
      // Notify parent that overlay was dismissed
      widget.onFocusChanged?.call(false);
    }).catchError((error) {
      // Handle any navigation errors
      debugPrint('Error dismissing overlay: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: _showExpandedSearchBar,
      child: Container(
        height: 48,
        width: screenWidth * 0.7, // Normal width (70% of screen)
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E1E1E)
              : const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            const SizedBox(width: AppDimensions.md),
            
            // Lock/Search icon
            Icon(
              _isSecure ? Icons.lock : Icons.search,
              size: 20,
              color: _isSecure ? Colors.green : (isDark ? Colors.grey[400] : Colors.grey[700]),
            ),
            
            const SizedBox(width: AppDimensions.sm),
            
            // Text field (read-only, just shows current text)
            Expanded(
              child: Text(
                _controller.text.isEmpty ? 'Search or type URL' : _controller.text,
                style: TextStyle(
                  fontSize: 15,
                  color: _controller.text.isEmpty
                      ? (isDark ? Colors.grey[500] : Colors.grey[600])
                      : (isDark ? Colors.white : Colors.black87),
                  fontWeight: FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            const SizedBox(width: AppDimensions.sm),
          ],
        ),
      ),
    );
  }
}
