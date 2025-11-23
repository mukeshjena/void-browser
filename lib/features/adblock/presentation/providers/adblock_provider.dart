import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/storage_constants.dart';
import '../../../../core/constants/api_constants.dart';

/// Advanced AdBlock provider with pattern matching, filter lists, and caching
class AdBlockNotifier extends StateNotifier<AdBlockState> {
  AdBlockNotifier() : super(AdBlockState(
    isEnabled: true,
    blockedCount: 0,
    filterRules: [],
    whitelistDomains: [],
    lastUpdate: null,
  )) {
    _initialize();
  }

  List<String> _filterRules = [];
  List<String> _whitelistDomains = [];
  Set<String> _blockedDomains = {};
  Map<String, RegExp> _regexCache = {};
  DateTime? _lastUpdate;

  Future<void> _initialize() async {
    await _loadState();
    await _loadFilterRules();
  }

  /// Load saved state from SharedPreferences
  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool(StorageConstants.keyAdBlockEnabled) ?? true;
      final blockedCount = prefs.getInt('adblock_blocked_count') ?? 0;
      final whitelistJson = prefs.getString('adblock_whitelist');
      final lastUpdateStr = prefs.getString('adblock_last_update');
      
      final whitelist = whitelistJson != null 
          ? List<String>.from(jsonDecode(whitelistJson))
          : <String>[];
      
      final lastUpdate = lastUpdateStr != null 
          ? DateTime.parse(lastUpdateStr)
          : null;

      state = state.copyWith(
        isEnabled: isEnabled,
        blockedCount: blockedCount,
        whitelistDomains: whitelist,
        lastUpdate: lastUpdate,
      );
      
      _whitelistDomains = whitelist;
      _lastUpdate = lastUpdate;
    } catch (e) {
      // Use defaults if loading fails
    }
  }

  /// Load filter rules from cache or download
  Future<void> _loadFilterRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedRules = prefs.getString(StorageConstants.keyFilterRules);
      
      if (cachedRules != null && cachedRules.isNotEmpty) {
        _filterRules = List<String>.from(jsonDecode(cachedRules));
        _buildBlockedDomains();
        state = state.copyWith(filterRules: _filterRules);
        return;
      }
      
      // If no cached rules, use built-in rules and try to download
      _loadBuiltInRules();
      _buildBlockedDomains();
      state = state.copyWith(filterRules: _filterRules);
      
      // Try to download filter lists in background
      _downloadFilterLists();
    } catch (e) {
      _loadBuiltInRules();
      _buildBlockedDomains();
      state = state.copyWith(filterRules: _filterRules);
    }
  }

  /// Load built-in comprehensive ad blocking rules
  void _loadBuiltInRules() {
    _filterRules = [
      // Common ad domains
      '||doubleclick.net^',
      '||googlesyndication.com^',
      '||googleadservices.com^',
      '||google-analytics.com^',
      '||facebook.net^',
      '||facebook.com/tr^',
      '||amazon-adsystem.com^',
      '||adservice.google^',
      '||adservice.google.*^',
      '||ads.*.google.com^',
      '||ad.*.google.com^',
      '||googletagmanager.com^',
      '||googletagservices.com^',
      '||scorecardresearch.com^',
      '||quantserve.com^',
      '||outbrain.com^',
      '||taboola.com^',
      '||criteo.com^',
      '||advertising.com^',
      '||adnxs.com^',
      '||rubiconproject.com^',
      '||pubmatic.com^',
      '||openx.net^',
      '||adsrvr.org^',
      '||adsystem.amazon.com^',
      '||amazon-adsystem.com^',
      
      // Pattern-based rules
      '/ads/*',
      '/ad/*',
      '/advertisement/*',
      '/banner/*',
      '/popup/*',
      '/*/ads/*',
      '/*/ad/*',
      '/*/advertisement/*',
      '/*/banner/*',
      '/*/popup/*',
      '/*/tracking/*',
      '/*/tracker/*',
      '/*/analytics/*',
      
      // Analytics and tracking
      '||analytics.*^',
      '||tracking.*^',
      '||tracker.*^',
      '||metrics.*^',
      '||stats.*^',
      '||statistics.*^',
      
      // Social media tracking
      '||facebook.com/tr^',
      '||facebook.com/connect^',
      '||twitter.com/i/adsct^',
      '||linkedin.com/px^',
      '||pinterest.com/ct^',
      
      // Common ad patterns
      '*&ad=*',
      '*&ads=*',
      '*&adid=*',
      '*&ad_id=*',
      '*&adid=*',
      '*&advertising=*',
      '*&banner=*',
      '*&popup=*',
      '*&tracking=*',
      '*&tracker=*',
      '*&analytics=*',
      '*&utm_source=*',
      '*&utm_medium=*',
      '*&utm_campaign=*',
      '*&utm_term=*',
      '*&utm_content=*',
      
      // File extensions
      '*.ads.*',
      '*.ad.*',
      '*.banner.*',
      '*.popup.*',
      
      // Domain patterns
      '*ads.*',
      '*ad.*',
      '*adserver.*',
      '*adserver*',
      '*advertising.*',
      '*advertising*',
      '*banner.*',
      '*banner*',
      '*popup.*',
      '*popup*',
      '*tracking.*',
      '*tracking*',
      '*tracker.*',
      '*tracker*',
      '*analytics.*',
      '*analytics*',
    ];
  }

  /// Build a set of blocked domains from filter rules for fast lookup
  void _buildBlockedDomains() {
    _blockedDomains.clear();
    for (final rule in _filterRules) {
      // Extract domain from rules like ||domain.com^
      if (rule.startsWith('||') && rule.endsWith('^')) {
        final domain = rule.substring(2, rule.length - 1);
        if (domain.isNotEmpty && !domain.contains('*') && !domain.contains('/')) {
          _blockedDomains.add(domain);
        }
      } else if (rule.startsWith('||') && !rule.contains('*') && !rule.contains('/')) {
        final domain = rule.substring(2);
        if (domain.isNotEmpty) {
          _blockedDomains.add(domain);
        }
      }
    }
  }

  /// Download filter lists from EasyList
  Future<void> _downloadFilterLists() async {
    try {
      // Check if we should update (once per day)
      if (_lastUpdate != null) {
        final daysSinceUpdate = DateTime.now().difference(_lastUpdate!).inDays;
        if (daysSinceUpdate < 1) {
          return; // Don't update if updated today
        }
      }

      final dio = Dio();
      
      // Download EasyList
      final easyListResponse = await dio.get(
        ApiConstants.easyListUrl,
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (easyListResponse.statusCode == 200) {
        final rules = _parseFilterList(easyListResponse.data.toString());
        _filterRules.addAll(rules);
        
        // Download EasyPrivacy
        try {
          final easyPrivacyResponse = await dio.get(
            ApiConstants.easyPrivacyUrl,
            options: Options(
              receiveTimeout: const Duration(seconds: 10),
              sendTimeout: const Duration(seconds: 10),
            ),
          );
          
          if (easyPrivacyResponse.statusCode == 200) {
            final privacyRules = _parseFilterList(easyPrivacyResponse.data.toString());
            _filterRules.addAll(privacyRules);
          }
        } catch (e) {
          // Ignore EasyPrivacy errors
        }
        
        // Save to cache
        await _saveFilterRules();
        _buildBlockedDomains();
        
        state = state.copyWith(
          filterRules: _filterRules,
          lastUpdate: DateTime.now(),
        );
        _lastUpdate = DateTime.now();
        await _saveState();
      }
    } catch (e) {
      // Silently fail - use built-in rules
    }
  }

  /// Parse filter list text into rules
  List<String> _parseFilterList(String content) {
    final rules = <String>[];
    final lines = content.split('\n');
    
    for (final line in lines) {
      final trimmed = line.trim();
      
      // Skip comments and empty lines
      if (trimmed.isEmpty || 
          trimmed.startsWith('!') || 
          trimmed.startsWith('[Adblock') ||
          trimmed.startsWith('@@') && trimmed.contains('\$')) {
        continue;
      }
      
      // Skip element hiding rules for now (we'll add support later)
      if (trimmed.contains('##') || trimmed.contains('#@#')) {
        continue;
      }
      
      // Add valid rules
      if (trimmed.isNotEmpty && 
          !trimmed.startsWith('!') && 
          trimmed.length < 500) { // Skip very long rules
        rules.add(trimmed);
      }
    }
    
    return rules;
  }

  /// Save filter rules to cache
  Future<void> _saveFilterRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        StorageConstants.keyFilterRules,
        jsonEncode(_filterRules),
      );
    } catch (e) {
      // Ignore save errors
    }
  }

  /// Save state to SharedPreferences
  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(StorageConstants.keyAdBlockEnabled, state.isEnabled);
      await prefs.setInt('adblock_blocked_count', state.blockedCount);
      await prefs.setString('adblock_whitelist', jsonEncode(_whitelistDomains));
      if (_lastUpdate != null) {
        await prefs.setString('adblock_last_update', _lastUpdate!.toIso8601String());
      }
    } catch (e) {
      // Ignore save errors
    }
  }

  /// Toggle ad blocking on/off
  void toggleAdBlock() {
    state = state.copyWith(isEnabled: !state.isEnabled);
    _saveState();
  }

  /// Increment blocked count
  void incrementBlockedCount() {
    state = state.copyWith(blockedCount: state.blockedCount + 1);
    _saveState();
  }

  /// Reset blocked count
  void resetBlockedCount() {
    state = state.copyWith(blockedCount: 0);
    _saveState();
  }

  /// Add domain to whitelist
  void addToWhitelist(String domain) {
    if (!_whitelistDomains.contains(domain)) {
      _whitelistDomains.add(domain);
      state = state.copyWith(whitelistDomains: List.from(_whitelistDomains));
      _saveState();
    }
  }

  /// Remove domain from whitelist
  void removeFromWhitelist(String domain) {
    _whitelistDomains.remove(domain);
    state = state.copyWith(whitelistDomains: List.from(_whitelistDomains));
    _saveState();
  }

  /// Manually update filter lists
  Future<void> updateFilterLists() async {
    await _downloadFilterLists();
  }

  /// Check if URL should be blocked
  bool shouldBlockUrl(String url) {
    if (!state.isEnabled) return false;
    
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return false;
      
      final host = uri.host.toLowerCase();
      final path = uri.path.toLowerCase();
      final query = uri.query.toLowerCase();
      
      // Check whitelist first
      for (final whitelistDomain in _whitelistDomains) {
        if (host.contains(whitelistDomain.toLowerCase())) {
          return false;
        }
      }
      
      // Fast domain lookup
      for (final blockedDomain in _blockedDomains) {
        if (host == blockedDomain || host.endsWith('.$blockedDomain')) {
          incrementBlockedCount();
          return true;
        }
      }
      
      // Check filter rules
      for (final rule in _filterRules) {
        if (_matchesRule(url, host, path, query, rule)) {
          incrementBlockedCount();
          return true;
        }
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if URL matches a filter rule
  bool _matchesRule(String url, String host, String path, String query, String rule) {
    try {
      // Exact domain match (||domain.com^)
      if (rule.startsWith('||') && rule.endsWith('^')) {
        final domain = rule.substring(2, rule.length - 1).toLowerCase();
        return host == domain || host.endsWith('.$domain');
      }
      
      // Domain match (||domain.com)
      if (rule.startsWith('||')) {
        final domain = rule.substring(2).toLowerCase();
        if (host.contains(domain)) {
          return true;
        }
      }
      
      // Path pattern (/ads/*)
      if (rule.startsWith('/') && rule.contains('*')) {
        final pattern = rule.replaceAll('*', '.*');
        if (_regexCache.containsKey(pattern)) {
          return _regexCache[pattern]!.hasMatch(path) || 
                 _regexCache[pattern]!.hasMatch(query);
        } else {
          try {
            final regex = RegExp(pattern, caseSensitive: false);
            _regexCache[pattern] = regex;
            return regex.hasMatch(path) || regex.hasMatch(query);
          } catch (e) {
            return false;
          }
        }
      }
      
      // Query parameter pattern (*&ad=*)
      if (rule.contains('*') && (rule.contains('&') || rule.contains('?'))) {
        final pattern = rule.replaceAll('*', '.*');
        if (_regexCache.containsKey(pattern)) {
          return _regexCache[pattern]!.hasMatch(url);
        } else {
          try {
            final regex = RegExp(pattern, caseSensitive: false);
            _regexCache[pattern] = regex;
            return regex.hasMatch(url);
          } catch (e) {
            return false;
          }
        }
      }
      
      // Simple contains check
      if (rule.contains('*')) {
        final pattern = rule.replaceAll('*', '.*');
        if (_regexCache.containsKey(pattern)) {
          return _regexCache[pattern]!.hasMatch(url);
        } else {
          try {
            final regex = RegExp(pattern, caseSensitive: false);
            _regexCache[pattern] = regex;
            return regex.hasMatch(url);
          } catch (e) {
            return false;
          }
        }
      }
      
      // Simple substring match
      return url.toLowerCase().contains(rule.toLowerCase()) ||
             host.contains(rule.toLowerCase()) ||
             path.contains(rule.toLowerCase()) ||
             query.contains(rule.toLowerCase());
    } catch (e) {
      return false;
    }
  }

  /// Get statistics
  Map<String, dynamic> getStatistics() {
    return {
      'blockedCount': state.blockedCount,
      'filterRulesCount': _filterRules.length,
      'whitelistCount': _whitelistDomains.length,
      'lastUpdate': _lastUpdate?.toIso8601String(),
      'isEnabled': state.isEnabled,
    };
  }
}

class AdBlockState {
  final bool isEnabled;
  final int blockedCount;
  final List<String> filterRules;
  final List<String> whitelistDomains;
  final DateTime? lastUpdate;

  AdBlockState({
    required this.isEnabled,
    required this.blockedCount,
    required this.filterRules,
    required this.whitelistDomains,
    required this.lastUpdate,
  });

  AdBlockState copyWith({
    bool? isEnabled,
    int? blockedCount,
    List<String>? filterRules,
    List<String>? whitelistDomains,
    DateTime? lastUpdate,
  }) {
    return AdBlockState(
      isEnabled: isEnabled ?? this.isEnabled,
      blockedCount: blockedCount ?? this.blockedCount,
      filterRules: filterRules ?? this.filterRules,
      whitelistDomains: whitelistDomains ?? this.whitelistDomains,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }
}

final adBlockProvider = StateNotifierProvider<AdBlockNotifier, AdBlockState>((ref) {
  return AdBlockNotifier();
});
