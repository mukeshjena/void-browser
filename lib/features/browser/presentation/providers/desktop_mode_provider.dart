import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/storage_constants.dart';
import '../../../../main.dart';

/// Provider for desktop mode state management with persistence
class DesktopModeNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;

  DesktopModeNotifier(this._prefs) : super(false) {
    _loadDesktopMode();
  }

  void _loadDesktopMode() {
    state = _prefs.getBool(StorageConstants.keyDesktopMode) ?? false;
  }

  Future<void> setDesktopMode(bool enabled) async {
    await _prefs.setBool(StorageConstants.keyDesktopMode, enabled);
    state = enabled;
  }

  Future<void> toggleDesktopMode() async {
    await setDesktopMode(!state);
  }
}

final desktopModeProvider = StateNotifierProvider<DesktopModeNotifier, bool>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  return DesktopModeNotifier(prefs);
});

