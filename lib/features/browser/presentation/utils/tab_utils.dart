import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tabs_provider.dart';
import '../providers/browser_navigation_provider.dart';
import '../../../search/presentation/providers/search_history_provider.dart';

/// Utility functions for tab management
class TabUtils {
  /// Open a URL in the current active tab's webview
  /// Switches to browser tab if needed and navigates immediately
  static void openInCurrentTab(WidgetRef ref, String url) {
    // Validate and format URL
    if (url.isEmpty || url.trim().isEmpty) {
      return; // Invalid URL, don't proceed
    }
    
    // Ensure URL is properly formatted
    String formattedUrl = url.trim();
    
    // Reject "discover" as it's not a valid URL
    if (formattedUrl == 'discover' || formattedUrl == 'http://discover' || formattedUrl == 'https://discover' || formattedUrl == 'http://discover/' || formattedUrl == 'https://discover/') {
      return; // Don't allow "discover" as a URL
    }
    
    // Validate URL format
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      // If it looks like a domain, add https://
      if (formattedUrl.contains('.') && !formattedUrl.contains(' ')) {
        formattedUrl = 'https://$formattedUrl';
      } else {
        // Invalid URL format, don't proceed
        return;
      }
    }
    
    // Additional validation: ensure URL is not just a protocol
    if (formattedUrl == 'http://' || formattedUrl == 'https://' || formattedUrl == 'http:///' || formattedUrl == 'https:///') {
      return; // Invalid URL
    }
    
    // Get current tabs state
    final tabsState = ref.read(tabsProvider);
    final activeTab = tabsState.activeTab;
    
    // Update the current active tab with the new URL immediately (before switching)
    if (activeTab != null) {
      // Update the current active tab with the new URL
      ref.read(tabsProvider.notifier).updateTab(
        tabId: activeTab.id,
        url: formattedUrl,
      );
    } else {
          // If no active tab, create a new one
          ref.read(tabsProvider.notifier).createNewTab(url: formattedUrl);
        }
        
        // Add to search history asynchronously (don't block navigation)
        ref.read(searchHistoryProvider.notifier).addUrlNavigation(formattedUrl).catchError((_) {});
        
        // Switch to browser tab (index 0) to ensure navigation is visible
        // Do this after updating the URL so the webview can load it
        ref.read(browserNavigationProvider.notifier).switchTab(0);
      }

  /// Open a URL in the current active tab (replaces new tab creation)
  /// Also switches to browser tab (index 0) to ensure navigation is visible
  /// @deprecated Use openInCurrentTab instead
  static void openInNewTab(WidgetRef ref, String url) {
    openInCurrentTab(ref, url);
  }
}

