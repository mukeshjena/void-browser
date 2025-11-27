import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/utils/debouncer.dart';
import 'qr_scanner_screen.dart';
import '../../core/services/voice_search_service.dart';
import '../../features/search/presentation/providers/search_history_provider.dart';
import '../../features/search/presentation/providers/search_suggestions_provider.dart';

/// Overlay widget that shows expanded search bar when focused
class ExpandedSearchBarOverlay extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final Function(String)? onSubmitted;
  final Function(String)? onChanged;
  final Function()? onDismiss;
  final String? currentUrl;
  final bool isSecure;

  const ExpandedSearchBarOverlay({
    super.key,
    required this.controller,
    this.onSubmitted,
    this.onChanged,
    this.onDismiss,
    this.currentUrl,
    this.isSecure = false,
  });

  @override
  ConsumerState<ExpandedSearchBarOverlay> createState() => _ExpandedSearchBarOverlayState();
}

class _ExpandedSearchBarOverlayState extends ConsumerState<ExpandedSearchBarOverlay> with WidgetsBindingObserver {
  late FocusNode _focusNode;
  final VoiceSearchService _voiceService = VoiceSearchService();
  bool _isListening = false;
  double _lastKeyboardHeight = 0.0;
  late Debouncer _searchDebouncer;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _searchDebouncer = Debouncer(delay: const Duration(milliseconds: 300));
    WidgetsBinding.instance.addObserver(this);
    // Auto-focus when overlay appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
        // Select all text if present
        if (widget.controller.text.isNotEmpty) {
          widget.controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: widget.controller.text.length,
          );
        }
        // Load initial suggestions
        _loadSuggestions(widget.controller.text);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    _voiceService.dispose();
    _searchDebouncer.dispose();
    super.dispose();
  }

  /// Load suggestions with debouncing
  void _loadSuggestions(String query) {
    _searchDebouncer.call(() {
      if (!mounted) return;
      
      // Update suggestions asynchronously (non-blocking)
      ref.read(searchSuggestionsProvider.notifier).getSuggestions(query).catchError((_) {});
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Detect keyboard dismissal via back gesture
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        
        try {
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          
          // If keyboard was visible and now it's gone, dismiss overlay
          if (_lastKeyboardHeight > 0 && keyboardHeight == 0 && _focusNode.hasFocus) {
            // Keyboard was dismissed (via back gesture, swipe down, etc.)
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                _dismiss();
              }
            });
          }
          
          _lastKeyboardHeight = keyboardHeight;
        } catch (e) {
          // Handle errors gracefully
        }
      });
    }
  }

  void _dismiss() {
    if (!mounted) return;
    
    // Unfocus first to release keyboard
    _focusNode.unfocus();
    
    // Pop the route using root navigator
    // Use a microtask to ensure focus is released before popping
    Future.microtask(() {
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      // Call onDismiss callback after pop (it won't try to pop again)
      widget.onDismiss?.call();
    });
  }

  Future<void> _openQRScanner() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRScannerScreen(
          onQRCodeScanned: (code) {
            if (code.isNotEmpty) {
              widget.controller.text = code;
              // Add QR code to search history asynchronously (don't block UI)
              ref.read(searchHistoryProvider.notifier).addUrlNavigation(code).catchError((_) {});
              widget.onSubmitted?.call(code);
              _dismiss();
            }
          },
        ),
      ),
    );
  }

  Future<void> _startVoiceSearch() async {
    if (_isListening) {
      await _voiceService.stopListening();
      setState(() {
        _isListening = false;
      });
      return;
    }

    final isAvailable = await _voiceService.initialize();
    if (!isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice search is not available. Please grant microphone permission.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() {
      _isListening = true;
    });

    await _voiceService.startListening(
      onResult: (text) {
        if (mounted && text.isNotEmpty) {
          setState(() {
            _isListening = false;
          });
          widget.controller.text = text;
          // Add voice search to history asynchronously (don't block UI)
          ref.read(searchHistoryProvider.notifier).addSearchQuery(text).catchError((_) {});
          widget.onSubmitted?.call(text);
          // Dismiss overlay after voice search
          if (mounted) {
            _dismiss();
          }
        }
      },
      onError: () {
        if (mounted) {
          setState(() {
            _isListening = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop && mounted) {
          // Route is being popped, just cleanup focus
          _focusNode.unfocus();
        }
      },
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: _dismiss,
          child: Container(
            color: Colors.black.withOpacity(0.3),
            child: SafeArea(
              child: Column(
                children: [
                  // AppBar area with expanded search bar
                  GestureDetector(
                    onTap: () {
                      // Prevent dismissing when tapping on search bar area
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      color: isDark ? Colors.black : Colors.white,
                      child: Row(
                        children: [
                          // Expanded search bar
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                // Prevent dismissing when tapping on search bar
                              },
                              child: Container(
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
                                      widget.isSecure ? Icons.lock : Icons.search,
                                      size: 20,
                                      color: widget.isSecure
                                          ? Colors.green
                                          : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                    ),
                                    const SizedBox(width: AppDimensions.sm),
                                    // Text field
                                    Expanded(
                                      child: TextField(
                                        controller: widget.controller,
                                        focusNode: _focusNode,
                                        decoration: InputDecoration(
                                          hintText: 'Search or type URL',
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          errorBorder: InputBorder.none,
                                          focusedErrorBorder: InputBorder.none,
                                          disabledBorder: InputBorder.none,
                                          errorText: null,
                                          errorStyle: const TextStyle(height: 0),
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
                                        onTap: () {
                                          // Select all text when search bar is tapped and has content
                                          if (widget.controller.text.isNotEmpty) {
                                            WidgetsBinding.instance.addPostFrameCallback((_) {
                                              if (mounted && widget.controller.text.isNotEmpty) {
                                                widget.controller.selection = TextSelection(
                                                  baseOffset: 0,
                                                  extentOffset: widget.controller.text.length,
                                                );
                                              }
                                            });
                                          }
                                        },
                                        onChanged: (value) {
                                          widget.onChanged?.call(value);
                                          // Load suggestions with debouncing
                                          _loadSuggestions(value);
                                        },
                                  onSubmitted: (value) {
                                    if (value.isNotEmpty && value.trim().isNotEmpty) {
                                      final trimmedValue = value.trim();
                                      
                                      // Cancel any pending debounced calls
                                      _searchDebouncer.cancel();
                                      
                                      // Add to search history asynchronously (don't block UI)
                                      ref.read(searchHistoryProvider.notifier).addSearchQuery(trimmedValue).catchError((_) {});
                                      
                                      widget.onSubmitted?.call(trimmedValue);
                                      // Pop immediately after submission
                                      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
                                        Navigator.of(context, rootNavigator: true).pop();
                                      }
                                    }
                                  },
                                      ),
                                    ),
                                    // QR Scanner button
                                    IconButton(
                                      icon: const Icon(Icons.qr_code_scanner, size: 22),
                                      onPressed: _openQRScanner,
                                      tooltip: 'Scan QR Code',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                                    ),
                                    const SizedBox(width: 4),
                                    // Voice search button
                                    IconButton(
                                      icon: Icon(
                                        _isListening ? Icons.mic : Icons.mic_none,
                                        size: 22,
                                        color: _isListening
                                            ? Colors.red
                                            : (isDark ? Colors.grey[300] : Colors.grey[700]),
                                      ),
                                      onPressed: _startVoiceSearch,
                                      tooltip: 'Voice Search',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Rest of the screen (transparent overlay)
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

