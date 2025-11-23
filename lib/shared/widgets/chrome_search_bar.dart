import 'package:flutter/material.dart';
import '../../core/theme/app_dimensions.dart';

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
  });

  @override
  State<ChromeSearchBar> createState() => _ChromeSearchBarState();
}

class _ChromeSearchBarState extends State<ChromeSearchBar> {
  late TextEditingController _controller;
  bool _isSecure = false;
  String _lastSubmittedValue = ''; // Track last submitted value to prevent duplicates

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 48,
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
          
          // Text field
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: widget.autofocus,
              decoration: InputDecoration(
                hintText: 'Search or type URL',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                filled: false,
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                  fontSize: 15,
                  fontWeight: FontWeight.normal,
                ),
              ),
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.normal,
              ),
              cursorColor: theme.colorScheme.primary,
              onChanged: (value) {
                widget.onChanged?.call(value);
                // Reset last submitted value when user types
                if (value != _lastSubmittedValue) {
                  _lastSubmittedValue = '';
                }
              },
              onSubmitted: (value) {
                if (value.isNotEmpty && value.trim().isNotEmpty) {
                  final trimmedValue = value.trim();
                  // Prevent duplicate submissions of the same value
                  if (_lastSubmittedValue != trimmedValue) {
                    _lastSubmittedValue = trimmedValue;
                    widget.onSubmitted?.call(trimmedValue);
                  }
                }
              },
            ),
          ),
          
          const SizedBox(width: AppDimensions.sm),
        ],
      ),
    );
  }
}

