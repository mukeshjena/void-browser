import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_manager.dart';
import 'cache_manager.dart';

/// Storage statistics model
class StorageStatistics {
  final Map<String, dynamic> hive;
  final Map<String, dynamic> cache;
  final Map<String, dynamic> sharedPreferences;
  final Map<String, dynamic> total;
  final DateTime lastUpdated;

  StorageStatistics({
    required this.hive,
    required this.cache,
    required this.sharedPreferences,
    required this.total,
    required this.lastUpdated,
  });

  StorageStatistics copyWith({
    Map<String, dynamic>? hive,
    Map<String, dynamic>? cache,
    Map<String, dynamic>? sharedPreferences,
    Map<String, dynamic>? total,
    DateTime? lastUpdated,
  }) {
    return StorageStatistics(
      hive: hive ?? this.hive,
      cache: cache ?? this.cache,
      sharedPreferences: sharedPreferences ?? this.sharedPreferences,
      total: total ?? this.total,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Storage monitor for tracking storage usage and health
class StorageMonitor extends StateNotifier<StorageStatistics> {
  Timer? _updateTimer;
  bool _isMonitoring = false;

  StorageMonitor() : super(StorageStatistics(
    hive: {},
    cache: {},
    sharedPreferences: {},
    total: {},
    lastUpdated: DateTime.now(),
  )) {
    _loadStatistics();
  }

  /// Start monitoring storage (updates every 30 seconds)
  void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadStatistics();
    });
  }

  /// Stop monitoring storage
  void stopMonitoring() {
    _updateTimer?.cancel();
    _updateTimer = null;
    _isMonitoring = false;
  }

  /// Load current statistics
  Future<void> _loadStatistics() async {
    try {
      final stats = await StorageManager.instance.getStorageStats();
      state = StorageStatistics(
        hive: stats['hive'] as Map<String, dynamic>,
        cache: stats['cache'] as Map<String, dynamic>,
        sharedPreferences: stats['sharedPreferences'] as Map<String, dynamic>,
        total: stats['total'] as Map<String, dynamic>,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      // Keep previous state on error
    }
  }

  /// Force refresh statistics
  Future<void> refresh() async {
    await _loadStatistics();
  }

  /// Get cache health status
  Map<String, dynamic> getCacheHealth() {
    final cacheSizeMB = double.tryParse(state.cache['sizeMB'] as String? ?? '0') ?? 0;
    final entryCount = state.cache['entryCount'] as int? ?? 0;

    String status = 'healthy';
    String message = 'Cache is healthy';

    if (cacheSizeMB > 100) {
      status = 'warning';
      message = 'Cache size is large (${cacheSizeMB.toStringAsFixed(2)} MB). Consider clearing.';
    } else if (cacheSizeMB > 200) {
      status = 'critical';
      message = 'Cache size is very large (${cacheSizeMB.toStringAsFixed(2)} MB). Should be cleared.';
    }

    if (entryCount > 10000) {
      status = 'warning';
      message = 'Cache has many entries ($entryCount). Consider cleanup.';
    }

    return {
      'status': status,
      'message': message,
      'sizeMB': cacheSizeMB,
      'entryCount': entryCount,
    };
  }

  /// Get storage health status
  Map<String, dynamic> getStorageHealth() {
    final totalSizeMB = double.tryParse(state.total['sizeMB'] as String? ?? '0') ?? 0;
    final totalEntries = state.total['entries'] as int? ?? 0;

    String status = 'healthy';
    String message = 'Storage is healthy';

    if (totalSizeMB > 500) {
      status = 'warning';
      message = 'Storage size is large (${totalSizeMB.toStringAsFixed(2)} MB).';
    } else if (totalSizeMB > 1000) {
      status = 'critical';
      message = 'Storage size is very large (${totalSizeMB.toStringAsFixed(2)} MB). Consider cleanup.';
    }

    return {
      'status': status,
      'message': message,
      'totalSizeMB': totalSizeMB,
      'totalEntries': totalEntries,
    };
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}

/// Provider for storage monitor
final storageMonitorProvider = StateNotifierProvider<StorageMonitor, StorageStatistics>((ref) {
  final monitor = StorageMonitor();
  monitor.startMonitoring();
  ref.onDispose(() {
    monitor.stopMonitoring();
  });
  return monitor;
});
