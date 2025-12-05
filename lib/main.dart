import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/storage/storage_manager.dart';
import 'core/storage/state_coordinator.dart';
import 'core/storage/storage_migration.dart';
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

  // Initialize storage system
  try {
    // Initialize storage manager (handles Hive and SharedPreferences)
    await StorageManager.instance.initialize();
    
    // Run migrations if needed
    await StorageMigration.migrate();
    
    // Initialize state coordinator
    await StateCoordinator.instance.initialize();
  } catch (e) {
    debugPrint('Error initializing storage: $e');
    // Continue anyway - storage will be initialized on first use
  }

  // Initialize notification service
  await NotificationService().initialize();

  // Get SharedPreferences instance from storage manager
  final prefs = StorageManager.instance.prefs;

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
