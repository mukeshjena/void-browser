class StorageConstants {
  // Hive box names
  static const String bookmarksBox = 'bookmarks';
  static const String tabsBox = 'tabs';
  static const String downloadsBox = 'downloads';
  static const String settingsBox = 'settings';
  static const String cacheBox = 'cache';
  static const String historyBox = 'history';
  static const String filtersBox = 'filters';

  // Settings keys
  static const String keyThemeMode = 'theme_mode';
  static const String keySearchEngine = 'search_engine';
  static const String keyUserAgent = 'user_agent';
  static const String keyJavascriptEnabled = 'javascript_enabled';
  static const String keyAdBlockEnabled = 'adblock_enabled';
  static const String keyDoNotTrack = 'do_not_track';
  static const String keyHttpsOnly = 'https_only';
  static const String keyFontSize = 'font_size';
  static const String keyShowImages = 'show_images';
  static const String keyDownloadPath = 'download_path';
  static const String keyCacheSize = 'cache_size';
  static const String keyLocationPermission = 'location_permission';
  static const String keyLastLatitude = 'last_latitude';
  static const String keyLastLongitude = 'last_longitude';
  
  // Cache keys
  static const String keyNewsCache = 'news_cache';
  static const String keyRecipesCache = 'recipes_cache';
  static const String keyWeatherCache = 'weather_cache';
  static const String keyImagesCache = 'images_cache';
  static const String keyFilterRules = 'filter_rules';
  static const String keyLastFilterUpdate = 'last_filter_update';
  
  // Default values
  static const String defaultSearchEngine = 'google';
  static const String defaultUserAgent = 'mobile';
  static const bool defaultJavascriptEnabled = true;
  static const bool defaultAdBlockEnabled = true;
  static const bool defaultDoNotTrack = true;
  static const bool defaultHttpsOnly = false;
  static const double defaultFontSize = 16.0;
  static const bool defaultShowImages = true;
  static const int defaultCacheSize = 100; // MB
}

