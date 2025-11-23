import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdBlockNotifier extends StateNotifier<AdBlockState> {
  AdBlockNotifier() : super(AdBlockState(isEnabled: true, blockedCount: 0));

  void toggleAdBlock() {
    state = state.copyWith(isEnabled: !state.isEnabled);
  }

  void incrementBlockedCount() {
    state = state.copyWith(blockedCount: state.blockedCount + 1);
  }

  void resetBlockedCount() {
    state = state.copyWith(blockedCount: 0);
  }

  bool shouldBlockUrl(String url) {
    if (!state.isEnabled) return false;

    // Simple ad-blocking logic - blocks common ad domains
    final adDomains = [
      'doubleclick.net',
      'googlesyndication.com',
      'googleadservices.com',
      'google-analytics.com',
      'facebook.net',
      'ads.',
      'adserver',
      'analytics',
      'tracking',
    ];

    return adDomains.any((domain) => url.contains(domain));
  }
}

class AdBlockState {
  final bool isEnabled;
  final int blockedCount;

  AdBlockState({
    required this.isEnabled,
    required this.blockedCount,
  });

  AdBlockState copyWith({
    bool? isEnabled,
    int? blockedCount,
  }) {
    return AdBlockState(
      isEnabled: isEnabled ?? this.isEnabled,
      blockedCount: blockedCount ?? this.blockedCount,
    );
  }
}

final adBlockProvider = StateNotifierProvider<AdBlockNotifier, AdBlockState>((ref) {
  return AdBlockNotifier();
});

