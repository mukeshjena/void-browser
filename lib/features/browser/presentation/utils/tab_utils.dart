import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tabs_provider.dart';
import '../providers/browser_navigation_provider.dart';

/// Utility functions for tab management
class TabUtils {
  /// Open a URL in the current active tab (replaces new tab creation)
  /// Also switches to browser tab (index 0) to ensure navigation is visible
  static void openInNewTab(WidgetRef ref, String url) {
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
    
    // First, switch to browser tab (index 0) to ensure user sees the navigation
    ref.read(browserNavigationProvider.notifier).switchTab(0);
    
    // Update the tab URL after switching to browser tab
    // Use a small delay to ensure the tab switch is processed
    Future.delayed(const Duration(milliseconds: 100), () {
      final tabsState = ref.read(tabsProvider);
      final activeTab = tabsState.activeTab;
      
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
    });
  }
}

