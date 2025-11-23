import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../providers/settings_provider.dart';
import '../../domain/entities/app_settings_entity.dart';
import '../../../adblock/presentation/providers/adblock_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _buildSection(context, 'Appearance'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Switch between light and dark theme'),
            value: settings.themeMode == ThemeMode.dark,
            onChanged: (value) {
              settingsNotifier.setThemeMode(
                value ? ThemeMode.dark : ThemeMode.light,
              );
            },
          ),
          ListTile(
            title: const Text('Theme'),
            subtitle: Text(_getThemeModeText(settings.themeMode)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _showThemeDialog(context, ref);
            },
          ),
          Divider(
                          height: 1,
                          thickness: 1,
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
          _buildSection(context, 'Privacy & Security'),
          SwitchListTile(
            title: const Text('JavaScript'),
            subtitle: const Text('Enable JavaScript on web pages'),
            value: settings.javascriptEnabled,
            onChanged: (value) {
              settingsNotifier.setJavascriptEnabled(value);
            },
          ),
          SwitchListTile(
            title: const Text('Do Not Track'),
            subtitle: const Text('Send DNT header with requests'),
            value: settings.doNotTrack,
            onChanged: (value) {
              settingsNotifier.setDoNotTrack(value);
            },
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
          _buildSection(context, 'Search'),
          ListTile(
            title: const Text('Search Engine'),
            subtitle: Text(_getSearchEngineName(settings.searchEngine)),
            leading: _getSearchEngineIcon(settings.searchEngine),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _showSearchEngineDialog(context, ref, settings);
            },
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
          _buildSection(context, 'Ad Blocking'),
          _buildAdBlockSection(context, ref, settings, settingsNotifier),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
          _buildSection(context, 'About'),
          ListTile(
            title: const Text('App Version'),
            subtitle: Text(AppConstants.appVersion),
          ),
          ListTile(
            title: const Text('App Name'),
            subtitle: Text(AppConstants.appName),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              value: ThemeMode.light,
              groupValue: ref.read(settingsProvider).themeMode,
              onChanged: (value) {
                if (value != null) {
                  ref.read(settingsProvider.notifier).setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              value: ThemeMode.dark,
              groupValue: ref.read(settingsProvider).themeMode,
              onChanged: (value) {
                if (value != null) {
                  ref.read(settingsProvider.notifier).setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('System Default'),
              value: ThemeMode.system,
              groupValue: ref.read(settingsProvider).themeMode,
              onChanged: (value) {
                if (value != null) {
                  ref.read(settingsProvider.notifier).setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdBlockSection(
    BuildContext context,
    WidgetRef ref,
    AppSettingsEntity settings,
    SettingsNotifier settingsNotifier,
  ) {
    final adBlockState = ref.watch(adBlockProvider);
    final adBlockNotifier = ref.read(adBlockProvider.notifier);

    return Column(
      children: [
        SwitchListTile(
          title: const Text('Enable Ad Blocker'),
          subtitle: const Text('Block ads, trackers, and malicious domains'),
          value: settings.adBlockEnabled,
          onChanged: (value) {
            settingsNotifier.setAdBlockEnabled(value);
            // Sync with adblock provider
            if (value != adBlockState.isEnabled) {
              adBlockNotifier.toggleAdBlock();
            }
          },
        ),
        ListTile(
          title: const Text('Ads Blocked'),
          subtitle: Text(
            '${adBlockState.blockedCount} ads and trackers blocked',
            style: TextStyle(
              color: adBlockState.blockedCount > 0
                  ? Colors.green
                  : Colors.grey[600],
              fontWeight: adBlockState.blockedCount > 0
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
          trailing: adBlockState.blockedCount > 0
              ? TextButton(
                  onPressed: () {
                    adBlockNotifier.resetBlockedCount();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Blocked count reset'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text('Reset'),
                )
              : null,
        ),
        ListTile(
          title: const Text('Filter Lists'),
          subtitle: const Text('EasyList filters (auto-updated)'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Filter list management coming soon!'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
        if (settings.adBlockEnabled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.green.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.shield,
                    color: Colors.green[700],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ad blocking is active and protecting your privacy',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _getSearchEngineName(String engine) {
    switch (engine.toLowerCase()) {
      case 'google':
        return 'Google';
      case 'bing':
        return 'Bing';
      case 'duckduckgo':
        return 'DuckDuckGo';
      default:
        return 'Google';
    }
  }

  Widget _getSearchEngineIcon(String engine) {
    switch (engine.toLowerCase()) {
      case 'google':
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [Color(0xFF4285F4), Color(0xFF34A853), Color(0xFFFBBC05), Color(0xFFEA4335)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.search, color: Colors.white, size: 20),
        );
      case 'bing':
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFF008373),
          ),
          child: const Icon(Icons.search, color: Colors.white, size: 20),
        );
      case 'duckduckgo':
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFFDE5833),
          ),
          child: const Icon(Icons.search, color: Colors.white, size: 20),
        );
      default:
        return const Icon(Icons.search);
    }
  }

  void _showSearchEngineDialog(BuildContext context, WidgetRef ref, AppSettingsEntity settings) {
    final searchEngines = [
      {'name': 'Google', 'value': 'google', 'icon': Icons.search, 'color': const Color(0xFF4285F4)},
      {'name': 'Bing', 'value': 'bing', 'icon': Icons.search, 'color': const Color(0xFF008373)},
      {'name': 'DuckDuckGo', 'value': 'duckduckgo', 'icon': Icons.search, 'color': const Color(0xFFDE5833)},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Search Engine'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: searchEngines.map((engine) {
            return RadioListTile<String>(
              title: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: engine['color'] as Color,
                    ),
                    child: Icon(
                      engine['icon'] as IconData,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(engine['name'] as String),
                ],
              ),
              value: engine['value'] as String,
              groupValue: settings.searchEngine.toLowerCase(),
              onChanged: (value) {
                if (value != null) {
                  ref.read(settingsProvider.notifier).setSearchEngine(value);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Search engine changed to ${engine['name']}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

