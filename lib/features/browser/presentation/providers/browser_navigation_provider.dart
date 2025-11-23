import 'package:flutter_riverpod/flutter_riverpod.dart';

// State for browser navigation
class BrowserNavigationState {
  final String? urlToLoad;
  final int tabIndex;

  BrowserNavigationState({
    this.urlToLoad,
    this.tabIndex = 0,
  });

  BrowserNavigationState copyWith({
    String? urlToLoad,
    int? tabIndex,
  }) {
    return BrowserNavigationState(
      urlToLoad: urlToLoad ?? this.urlToLoad,
      tabIndex: tabIndex ?? this.tabIndex,
    );
  }
}

// Notifier for browser navigation
class BrowserNavigationNotifier extends StateNotifier<BrowserNavigationState> {
  BrowserNavigationNotifier() : super(BrowserNavigationState());

  void navigateToUrl(String url) {
    state = state.copyWith(urlToLoad: url, tabIndex: 0);
  }

  void clearUrl() {
    state = state.copyWith(urlToLoad: null);
  }

  void switchTab(int index) {
    state = state.copyWith(tabIndex: index);
  }
}

// Provider for browser navigation
final browserNavigationProvider = StateNotifierProvider<BrowserNavigationNotifier, BrowserNavigationState>((ref) {
  return BrowserNavigationNotifier();
});

