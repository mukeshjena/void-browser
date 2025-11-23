import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'features/settings/presentation/providers/settings_provider.dart';
import 'main.dart';
import 'features/browser/presentation/screens/main_screen.dart';

class VoidBrowserApp extends ConsumerWidget {
  const VoidBrowserApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize settings provider
    final prefs = ref.watch(sharedPreferencesProvider);
    final settingsNotifier = SettingsNotifier(prefs);
    
    return ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => settingsNotifier),
      ],
      child: Consumer(
        builder: (context, ref, child) {
          final settings = ref.watch(settingsProvider);
          
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.themeMode,
            home: const MainScreen(),
          );
        },
      ),
    );
  }
}

