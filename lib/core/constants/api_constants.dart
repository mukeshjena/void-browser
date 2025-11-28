class ApiConstants {
  // Filter list URLs
  static const String easyListUrl = 
      'https://easylist-downloads.adblockplus.org/easylist.txt';
  
  static const String easyPrivacyUrl = 
      'https://easylist-downloads.adblockplus.org/easyprivacy.txt';
  
  static const String fanboyAnnoyanceUrl = 
      'https://easylist-downloads.adblockplus.org/fanboy-annoyance.txt';
  
  static const String fanboyCookieUrl = 
      'https://secure.fanboy.co.nz/fanboy-cookiemonster.txt';
  
  static const String fanboyNotificationUrl = 
      'https://easylist-downloads.adblockplus.org/fanboy-notifications.txt';
  
  // Regional lists (optional - add as needed)
  static const String easyListGermanyUrl = 
      'https://easylist-downloads.adblockplus.org/easylistgermany.txt';
  
  static const String easyListChinaUrl = 
      'https://easylist-downloads.adblockplus.org/easylistchina.txt';
  
  static const String easyListDutchUrl = 
      'https://easylist-downloads.adblockplus.org/easylistdutch.txt';
  // Base URLs
  static const String newsApiBase = 'https://gnews.io/api/v4';
  static const String mealDbBase = 'https://www.themealdb.com/api/json/v1/1';
  static const String weatherApiBase = 'https://api.open-meteo.com/v1';
  static const String unsplashApiBase = 'https://api.unsplash.com';
  // static const String easyListUrl = 'https://easylist.to/easylist/easylist.txt';
  // static const String easyPrivacyUrl =
  //     'https://easylist.to/easylist/easyprivacy.txt';

  // Endpoints
  static const String newsTopHeadlines = '/top-headlines';
  static const String newsSearch = '/search';
  static const String mealSearch = '/search.php';
  static const String mealRandom = '/random.php';
  static const String mealLookup = '/lookup.php';
  static const String mealCategories = '/categories.php';
  static const String weatherForecast = '/forecast';
  static const String unsplashPhotos = '/photos';
  static const String unsplashSearch = '/search/photos';
  static const String unsplashRandom = '/photos/random';

  // Default search engine
  static const String googleSearchUrl = 'https://www.google.com/search?q=';
  static const String bingSearchUrl = 'https://www.bing.com/search?q=';
  static const String duckDuckGoSearchUrl = 'https://duckduckgo.com/?q=';

  /// Get search URL based on engine name
  static String getSearchUrl(String engine, String query) {
    final encodedQuery = Uri.encodeComponent(query);
    switch (engine.toLowerCase()) {
      case 'google':
        return '$googleSearchUrl$encodedQuery';
      case 'bing':
        return '$bingSearchUrl$encodedQuery';
      case 'duckduckgo':
        return '$duckDuckGoSearchUrl$encodedQuery';
      default:
        return '$googleSearchUrl$encodedQuery';
    }
  }

  // Cache TTL in minutes
  static const int newsCacheTtl = 30;
  static const int recipesCacheTtl = 1440; // 24 hours
  static const int weatherCacheTtl = 60;
  static const int imagesCacheTtl = 1440;
  static const int filtersCacheTtl = 1440;
}

