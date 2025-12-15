class AppConstants {
  static const String appName = 'Vex Fast Privacy Browser';
  static const String appVersion = '2.0.1';
  static const String appDescription =
      'Ultra-lightweight privacy browser for Android';

  // App settings
  static const int maxTabsCount = 50;
  static const int maxDownloads = 100;
  static const int maxBookmarks = 1000;
  
  // Responsive breakpoints (in dp)
  static const double breakpointSmall = 600;
  static const double breakpointMedium = 840;
  
  // Network timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);
  
  // Rate limiting
  static const int maxRetryAttempts = 3;
  static const Duration initialRetryDelay = Duration(seconds: 5);
  
  // User agent strings
  static const String mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36';
  static const String desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
}

