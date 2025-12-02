import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../../core/constants/storage_constants.dart';
import '../../../../core/constants/api_constants.dart';

/// Optimized AdBlock provider with efficient multi-layer protection
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
  final Map<String, bool> _urlBlockCache = {};
  static const int _maxCacheSize = 1000;
  DateTime? _lastUpdate;
  
  // Essential ad keywords for heuristic detection
  final Set<String> _adKeywords = {
    'ad', 'ads', 'advert', 'advertising', 'doubleclick', 
    'googlesyndication', 'banner', 'popup', 'tracker', 'analytics'
  };

  Future<void> _initialize() async {
    await _loadState();
    await _loadFilterRules();
  }

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
      
      _loadBuiltInRules();
      _buildBlockedDomains();
      state = state.copyWith(filterRules: _filterRules);
      
      // Download filter lists in background
      unawaited(_downloadFilterLists());
    } catch (e) {
      _loadBuiltInRules();
      _buildBlockedDomains();
      state = state.copyWith(filterRules: _filterRules);
    }
  }

  void _loadBuiltInRules() {
    _filterRules = [
      // === Core Ad Networks ===
      '||doubleclick.net^',
      '||googlesyndication.com^',
      '||googleadservices.com^',
      '||google-analytics.com^',
      '||googletagmanager.com^',
      '||adservice.google.com^',
      
      // Facebook/Meta
      '||facebook.net^',
      '||connect.facebook.net^',
      
      // Amazon
      '||amazon-adsystem.com^',
      
      // === Ad Exchanges ===
      '||adnxs.com^',
      '||rubiconproject.com^',
      '||pubmatic.com^',
      '||openx.net^',
      '||criteo.com^',
      '||outbrain.com^',
      '||taboola.com^',
      
      // === Analytics ===
      '||scorecardresearch.com^',
      '||quantserve.com^',
      '||mixpanel.com^',
      '||segment.com^',
      
      // === Video Ads ===
      '||imasdk.googleapis.com^',
      '||2mdn.net^',
      '||fwmrm.net^',
      
      // === YouTube Ad Endpoints (Minimal, Targeted) ===
      '||youtube.com/api/stats/ads^',
      '||youtube.com/ptracking^',
      '||youtube.com/pagead^',
      '||youtube.com/get_midroll_info^',
      
      // === Mobile Ad Networks ===
      '||admob.com^',
      '||unity3d.com/ads^',
      '||applovin.com^',
      
      // === Pattern-based Rules ===
      '/ad.js',
      '/ads.js',
      '/_ads/',
      '*?ad=*',
      '*&ad=*',
    ];
  }

  void _buildBlockedDomains() {
    _blockedDomains.clear();
    
    for (final rule in _filterRules) {
      if (rule.startsWith('||') && rule.endsWith('^')) {
        final domain = rule.substring(2, rule.length - 1).toLowerCase();
        if (domain.isNotEmpty && !domain.contains('*') && !domain.contains('/')) {
          _blockedDomains.add(domain);
        }
      }
    }
  }

  Future<void> _downloadFilterLists() async {
    try {
      if (_lastUpdate != null) {
        final hoursSinceUpdate = DateTime.now().difference(_lastUpdate!).inHours;
        if (hoursSinceUpdate < 24) return;
      }

      final dio = Dio();
      final newRules = <String>[];
      
      final filterUrls = [
        ApiConstants.easyListUrl,
        ApiConstants.easyPrivacyUrl,
      ];

      for (final url in filterUrls) {
        try {
          final response = await dio.get(
            url,
            options: Options(
              receiveTimeout: const Duration(seconds: 10),
              sendTimeout: const Duration(seconds: 10),
            ),
          );

          if (response.statusCode == 200) {
            final rules = _parseFilterList(response.data.toString());
            newRules.addAll(rules);
          }
        } catch (e) {
          continue;
        }
      }
      
      if (newRules.isNotEmpty) {
        _filterRules.addAll(newRules);
        _filterRules = _filterRules.toSet().toList();
        
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
      // Silently fail
    }
  }

  List<String> _parseFilterList(String content) {
    final rules = <String>[];
    final lines = content.split('\n');
    
    for (final line in lines) {
      final trimmed = line.trim();
      
      if (trimmed.isEmpty || 
          trimmed.startsWith('!') || 
          trimmed.startsWith('[Adblock') ||
          trimmed.startsWith('@@') ||
          trimmed.contains('##')) {
        continue;
      }
      
      if (trimmed.length < 200) {
        rules.add(trimmed);
      }
    }
    
    return rules;
  }

  Future<void> _saveFilterRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        StorageConstants.keyFilterRules,
        jsonEncode(_filterRules),
      );
    } catch (e) {
      // Ignore
    }
  }

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
      // Ignore
    }
  }

  void toggleAdBlock() {
    state = state.copyWith(isEnabled: !state.isEnabled);
    _saveState();
  }

  void incrementBlockedCount() {
    state = state.copyWith(blockedCount: state.blockedCount + 1);
    if (state.blockedCount % 10 == 0) {
      _saveState();
    }
  }

  void resetBlockedCount() {
    state = state.copyWith(blockedCount: 0);
    _saveState();
  }

  void addToWhitelist(String domain) {
    if (!_whitelistDomains.contains(domain)) {
      _whitelistDomains.add(domain);
      state = state.copyWith(whitelistDomains: List.from(_whitelistDomains));
      _saveState();
    }
  }

  void removeFromWhitelist(String domain) {
    _whitelistDomains.remove(domain);
    state = state.copyWith(whitelistDomains: List.from(_whitelistDomains));
    _saveState();
  }

  Future<void> updateFilterLists() async {
    await _downloadFilterLists();
  }

  /// Optimized URL blocking check
  bool shouldBlockUrl(String url) {
    if (!state.isEnabled) return false;
    
    final lowerUrl = url.toLowerCase();
    
    // Check cache first
    if (_urlBlockCache.containsKey(lowerUrl)) {
      final cached = _urlBlockCache[lowerUrl]!;
      if (cached) incrementBlockedCount();
      return cached;
    }
    
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) {
        _cacheResult(lowerUrl, false);
        return false;
      }
      
      final host = uri.host.toLowerCase();
      
      // Whitelist check
      for (final domain in _whitelistDomains) {
        if (host.contains(domain.toLowerCase())) {
          _cacheResult(lowerUrl, false);
          return false;
        }
      }
      
      // Allow YouTube core functionality
      if (host.contains('youtube.com') || host.contains('googlevideo.com')) {
        // Block only IMA SDK and specific ad endpoints
        if (lowerUrl.contains('imasdk.googleapis.com') ||
            lowerUrl.contains('/api/stats/ads') ||
            lowerUrl.contains('/ptracking') ||
            lowerUrl.contains('/pagead')) {
          _cacheResult(lowerUrl, true);
          incrementBlockedCount();
          return true;
        }
        return false;
      }
      
      // Fast domain lookup
      if (_blockedDomains.contains(host)) {
        _cacheResult(lowerUrl, true);
        incrementBlockedCount();
        return true;
      }
      
      // Subdomain check
      if (host.contains('.')) {
        for (final blocked in _blockedDomains) {
          if (host.endsWith('.$blocked')) {
            _cacheResult(lowerUrl, true);
            incrementBlockedCount();
            return true;
          }
        }
      }
      
      // Keyword heuristic
      for (final keyword in _adKeywords) {
        if (host.contains(keyword)) {
          _cacheResult(lowerUrl, true);
          incrementBlockedCount();
          return true;
        }
      }
      
      _cacheResult(lowerUrl, false);
      return false;
    } catch (e) {
      _cacheResult(lowerUrl, false);
      return false;
    }
  }
  
  void _cacheResult(String key, bool shouldBlock) {
    if (_urlBlockCache.length >= _maxCacheSize) {
      final keysToRemove = _urlBlockCache.keys.take(_maxCacheSize ~/ 4).toList();
      for (final k in keysToRemove) {
        _urlBlockCache.remove(k);
      }
    }
    _urlBlockCache[key] = shouldBlock;
  }

  /// Optimized content blockers
  List<ContentBlocker> getContentBlockers() {
    if (!state.isEnabled) return [];
    
    return [
      // Block IMA SDK
      ContentBlocker(
        trigger: ContentBlockerTrigger(
          urlFilter: '.*imasdk\\.googleapis\\.com.*',
          resourceType: [ContentBlockerTriggerResourceType.SCRIPT],
        ),
        action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
      ),
      
      // Block major ad networks
      ContentBlocker(
        trigger: ContentBlockerTrigger(
          urlFilter: '.*(doubleclick|googlesyndication|googleadservices).*',
          resourceType: [
            ContentBlockerTriggerResourceType.SCRIPT,
            ContentBlockerTriggerResourceType.IMAGE,
          ],
        ),
        action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
      ),
      
      // Block YouTube ad endpoints
      ContentBlocker(
        trigger: ContentBlockerTrigger(
          urlFilter: '.*youtube\\.com/(api/stats/ads|ptracking|pagead).*',
          resourceType: [ContentBlockerTriggerResourceType.SCRIPT],
        ),
        action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
      ),
    ];
  }

  /// Highly optimized, single JavaScript for ad blocking
  String getAdBlockingJavaScript() {
  return '''
  (function(){'use strict';if(!window.google)window.google={};window.google.ima={AdsLoader:function(){this.requestAds=function(){};this.contentComplete=function(){};},AdsManager:function(){this.start=function(){};this.getAdCuePoints=function(){return[];};this.destroy=function(){};this.setVolume=function(){};this.pause=function(){};this.resume=function(){};},AdDisplayContainer:function(){this.initialize=function(){};this.destroy=function(){};},AdsRequest:function(){},AdErrorEvent:function(){},AdEvent:function(){}};const style=document.createElement('style');style.textContent='.ytp-ad-module,.ytp-ad-overlay-container,.ad-showing:not(.html5-video-player):not(video),.ad-interrupting:not(.html5-video-player):not(video),#player-ads,iframe[src*="imasdk"]{display:none!important;visibility:hidden!important}.ytp-chrome-bottom{display:flex!important;opacity:1!important}';(document.head||document.documentElement).appendChild(style);let originalVolume=1,originalMuted=false,isInAdState=false,adDetectionAttempts=0;const processAds=function(){try{const video=document.querySelector('video.html5-main-video');const player=document.querySelector('.html5-video-player,#movie_player');const skipBtn=document.querySelector('.ytp-ad-skip-button,.ytp-ad-skip-button-modern');if(skipBtn?.offsetParent){skipBtn.click();return;}const isAd=player?.classList.contains('ad-showing')||player?.classList.contains('ad-interrupting')||document.querySelector('.ytp-ad-module')?.offsetParent||document.querySelector('.ytp-ad-preview-container')?.offsetParent||document.querySelector('.ytp-ad-player-overlay')?.offsetParent;if(isAd&&!isInAdState){isInAdState=true;if(video){originalVolume=video.volume;originalMuted=video.muted;}}else if(!isAd&&isInAdState){isInAdState=false;if(video){video.playbackRate=1;video.muted=originalMuted;video.volume=originalVolume;const controls=document.querySelector('.ytp-chrome-bottom');if(controls){controls.style.opacity='1';controls.style.display='flex';}}return;}if(isAd&&video&&video.readyState>=2){video.muted=true;video.playbackRate=16;if(video.paused)video.play().catch(()=>{});if(video.duration<180&&video.currentTime<video.duration-0.5){video.currentTime=video.duration-0.3;}adDetectionAttempts++;if(adDetectionAttempts>5){const event=new CustomEvent('onAdComplete');document.dispatchEvent(event);document.querySelectorAll('button').forEach(btn=>{if(btn.textContent?.toLowerCase().includes('skip')||btn.getAttribute('aria-label')?.toLowerCase().includes('skip')){btn.click();}});adDetectionAttempts=0;}}document.querySelectorAll('.ytp-ad-overlay-container,.ytp-ad-module,.ytp-ad-preview-container').forEach(el=>{if(el&&!el.closest('video')&&el.offsetParent){el.style.cssText='display:none!important;';}});}catch(e){}};if(document.body)processAds();else document.addEventListener('DOMContentLoaded',processAds);setInterval(processAds,300);setTimeout(()=>{const video=document.querySelector('video.html5-main-video');if(video){video.addEventListener('play',()=>setTimeout(processAds,100),{passive:true});video.addEventListener('timeupdate',processAds,{passive:true});video.addEventListener('ended',()=>{if(isInAdState){isInAdState=false;}},{passive:true});}},1000);const originalFetch=window.fetch;window.fetch=function(...args){const url=args[0];if(typeof url==='string'){const lower=url.toLowerCase();if((lower.includes('youtube.com')||lower.includes('google'))&&(lower.includes('imasdk')||lower.includes('/api/stats/ads')||lower.includes('/ptracking')||lower.includes('/pagead'))){return Promise.reject(new Error('Blocked'));}}return originalFetch.apply(this,args);};setTimeout(()=>{const playerElements=document.querySelectorAll('.html5-video-player');playerElements.forEach(playerEl=>{if(playerEl&&playerEl.setPlaybackQuality){const originalPlayVideo=playerEl.playVideo;playerEl.playVideo=function(){if(this.getAdState&&this.getAdState()!==0){if(this.skipAd)this.skipAd();return;}return originalPlayVideo.call(this);};}});},2000);})();
  ''';
  }

  Map<String, dynamic> getStatistics() {
    return {
      'blockedCount': state.blockedCount,
      'filterRulesCount': _filterRules.length,
      'blockedDomainsCount': _blockedDomains.length,
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