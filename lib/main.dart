import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/storage/hive_config.dart';
import 'core/storage/cache_manager.dart';
import 'core/services/notification_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Error loading .env file: $e');
  }

  // Initialize Hive
  await HiveConfig.init();
  await HiveConfig.openAllBoxes();
  
  // Initialize cache manager (cleans old cache on startup)
  await CacheManager.init();

  // Initialize notification service
  await NotificationService().initialize();

  // Get SharedPreferences instance
  final prefs = await SharedPreferences.getInstance();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const VoidBrowserApp(),
    ),
  );
}

// Provider for SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});
