class Validators {
  static bool isValidUrl(String url) {
    if (url.isEmpty) return false;
    
    // Reject "discover" as it's not a valid URL
    final trimmed = url.trim();
    if (trimmed == 'discover' || 
        trimmed == 'http://discover' || 
        trimmed == 'https://discover' ||
        trimmed == 'http://discover/' ||
        trimmed == 'https://discover/') {
      return false; // "discover" is not a valid URL
    }
    
    // Add protocol if missing
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    
    final urlPattern = RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    );
    
    return urlPattern.hasMatch(url);
  }

  static bool isSearchQuery(String query) {
    return !isValidUrl(query);
  }

  static String getValidUrl(String input) {
    if (input.isEmpty) return '';
    
    if (isValidUrl(input)) {
      if (!input.startsWith('http://') && !input.startsWith('https://')) {
        return 'https://$input';
      }
      return input;
    }
    
    // If it's a search query, return empty and let the search engine handle it
    return '';
  }

  static bool isEmail(String email) {
    final emailPattern = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailPattern.hasMatch(email);
  }
}

