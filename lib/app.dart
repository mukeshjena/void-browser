import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/widgets/app_lifecycle_wrapper.dart';
import 'features/settings/presentation/providers/settings_provider.dart';
import 'main.dart';
import 'features/browser/presentation/screens/main_screen.dart';

// Global navigator key for navigation from anywhere (e.g., notifications)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
          // Use select to only watch themeMode, not entire settings
          final themeMode = ref.watch(settingsProvider.select((state) => state.themeMode));
          
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            // Performance optimizations
            builder: (context, child) {
              return MediaQuery(
                // Use device pixel ratio for better performance
                data: MediaQuery.of(context).copyWith(
                  textScaler: MediaQuery.of(context).textScaler.clamp(
                    minScaleFactor: 0.8,
                    maxScaleFactor: 1.2,
                  ),
                ),
                child: RepaintBoundary(
                  child: child!,
                ),
              );
            },
            // Optimize page transitions for faster animations
            themeAnimationDuration: const Duration(milliseconds: 150),
            themeAnimationCurve: Curves.easeOut,
            home: const AppLifecycleWrapper(
              child: MainScreen(),
            ),
          );
        },
      ),
    );
  }
}

