import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/app_settings_entity.dart';
import '../../../../core/constants/storage_constants.dart';

class SettingsNotifier extends StateNotifier<AppSettingsEntity> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs) : super(AppSettingsEntity.defaultSettings()) {
    _loadSettings();
  }

  void _loadSettings() {
    final themeModeStr = _prefs.getString(StorageConstants.keyThemeMode);
    ThemeMode themeMode = ThemeMode.system;
    if (themeModeStr != null) {
      themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.toString() == themeModeStr,
        orElse: () => ThemeMode.system,
      );
    }

    state = AppSettingsEntity(
      themeMode: themeMode,
      searchEngine: _prefs.getString(StorageConstants.keySearchEngine) ??
          StorageConstants.defaultSearchEngine,
      userAgent: _prefs.getString(StorageConstants.keyUserAgent) ??
          StorageConstants.defaultUserAgent,
      javascriptEnabled: _prefs.getBool(StorageConstants.keyJavascriptEnabled) ??
          StorageConstants.defaultJavascriptEnabled,
      adBlockEnabled: _prefs.getBool(StorageConstants.keyAdBlockEnabled) ??
          StorageConstants.defaultAdBlockEnabled,
      doNotTrack: _prefs.getBool(StorageConstants.keyDoNotTrack) ??
          StorageConstants.defaultDoNotTrack,
      httpsOnly: _prefs.getBool(StorageConstants.keyHttpsOnly) ??
          StorageConstants.defaultHttpsOnly,
      fontSize: _prefs.getDouble(StorageConstants.keyFontSize) ??
          StorageConstants.defaultFontSize,
      showImages: _prefs.getBool(StorageConstants.keyShowImages) ??
          StorageConstants.defaultShowImages,
      downloadPath: _prefs.getString(StorageConstants.keyDownloadPath) ?? '',
      cacheSize: _prefs.getInt(StorageConstants.keyCacheSize) ??
          StorageConstants.defaultCacheSize,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(StorageConstants.keyThemeMode, mode.toString());
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setSearchEngine(String engine) async {
    await _prefs.setString(StorageConstants.keySearchEngine, engine);
    state = state.copyWith(searchEngine: engine);
  }

  Future<void> setUserAgent(String agent) async {
    await _prefs.setString(StorageConstants.keyUserAgent, agent);
    state = state.copyWith(userAgent: agent);
  }

  Future<void> setJavascriptEnabled(bool enabled) async {
    await _prefs.setBool(StorageConstants.keyJavascriptEnabled, enabled);
    state = state.copyWith(javascriptEnabled: enabled);
  }

  Future<void> setAdBlockEnabled(bool enabled) async {
    await _prefs.setBool(StorageConstants.keyAdBlockEnabled, enabled);
    state = state.copyWith(adBlockEnabled: enabled);
  }

  Future<void> setDoNotTrack(bool enabled) async {
    await _prefs.setBool(StorageConstants.keyDoNotTrack, enabled);
    state = state.copyWith(doNotTrack: enabled);
  }

  Future<void> setHttpsOnly(bool enabled) async {
    await _prefs.setBool(StorageConstants.keyHttpsOnly, enabled);
    state = state.copyWith(httpsOnly: enabled);
  }

  Future<void> setFontSize(double size) async {
    await _prefs.setDouble(StorageConstants.keyFontSize, size);
    state = state.copyWith(fontSize: size);
  }

  Future<void> setShowImages(bool show) async {
    await _prefs.setBool(StorageConstants.keyShowImages, show);
    state = state.copyWith(showImages: show);
  }

  Future<void> setCacheSize(int size) async {
    await _prefs.setInt(StorageConstants.keyCacheSize, size);
    state = state.copyWith(cacheSize: size);
  }

  Future<void> resetSettings() async {
    await _prefs.clear();
    state = AppSettingsEntity.defaultSettings();
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettingsEntity>((ref) {
  throw UnimplementedError('settingsProvider must be overridden');
});

