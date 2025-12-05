import 'package:flutter/material.dart';

/// Find in Page overlay widget - Chrome-like search bar
class FindInPageOverlay extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueNotifier<int> activeMatch;
  final ValueNotifier<int> totalMatches;
  final Function(String) onFind;
  final VoidCallback onFindNext;
  final VoidCallback onFindPrevious;
  final VoidCallback onClose;

  const FindInPageOverlay({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.activeMatch,
    required this.totalMatches,
    required this.onFind,
    required this.onFindNext,
    required this.onFindPrevious,
    required this.onClose,
  });

  @override
  State<FindInPageOverlay> createState() => _FindInPageOverlayState();
}

class _FindInPageOverlayState extends State<FindInPageOverlay> {
  @override
  void initState() {
    super.initState();
    // Focus the text field when overlay opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.focusNode.requestFocus();
    });
    
    // Listen to text changes
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    widget.onFind(widget.controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
              // Search icon
              Icon(
                Icons.search,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              
              // Text field
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  autofocus: true,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Find in page',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    isDense: true,
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      widget.onFindNext();
                    }
                  },
                ),
              ),
              
              // Match count
              ValueListenableBuilder<int>(
                valueListenable: widget.totalMatches,
                builder: (context, totalMatches, _) {
                  if (totalMatches == 0 && widget.controller.text.isNotEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'No matches',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                    );
                  } else if (totalMatches > 0) {
                    return ValueListenableBuilder<int>(
                      valueListenable: widget.activeMatch,
                      builder: (context, activeMatch, _) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '$activeMatch / $totalMatches',
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              
              // Previous button
              IconButton(
                icon: const Icon(Icons.arrow_upward, size: 20),
                onPressed: widget.controller.text.isNotEmpty
                    ? () {
                        widget.onFindPrevious();
                        // Keep focus on text field
                        widget.focusNode.requestFocus();
                      }
                    : null,
                tooltip: 'Previous',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                color: widget.controller.text.isNotEmpty 
                    ? (Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.black87)
                    : Colors.grey,
              ),
              
              // Next button
              IconButton(
                icon: const Icon(Icons.arrow_downward, size: 20),
                onPressed: widget.controller.text.isNotEmpty
                    ? () {
                        widget.onFindNext();
                        // Keep focus on text field
                        widget.focusNode.requestFocus();
                      }
                    : null,
                tooltip: 'Next',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                color: widget.controller.text.isNotEmpty 
                    ? (Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.black87)
                    : Colors.grey,
              ),
              
              // Close button
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  widget.controller.clear();
                  widget.onClose();
                },
                tooltip: 'Close',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }
}

