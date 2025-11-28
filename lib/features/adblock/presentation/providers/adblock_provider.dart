import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../../core/constants/storage_constants.dart';
import '../../../../core/constants/api_constants.dart';

/// Comprehensive AdBlock provider with multi-layer protection
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
  Set<String> _blockedPatterns = {};
  Map<String, RegExp> _regexCache = {};
  DateTime? _lastUpdate;
  
  // URL blocking cache for performance (LRU cache with max 2000 entries)
  final Map<String, bool> _urlBlockCache = {};
  static const int _maxCacheSize = 2000;
  
  // Fast lookup sets for common blocked domains (pre-computed for O(1) lookup)
  final Set<String> _fastBlockedDomains = {};
  final Set<String> _fastBlockedSubdomains = {};
  
  // Enhanced blocking patterns
  final Set<String> _adKeywords = {
    'ad', 'ads', 'advert', 'advertising', 'advertisement',
    'banner', 'popup', 'popunder', 'sponsor', 'sponsored',
    'promo', 'promotion', 'tracking', 'tracker', 'analytics',
    'metric', 'telemetry', 'beacon', 'pixel', 'retargeting',
    'affiliate', 'doubleclick', 'adsense', 'adserver',
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
      // === Major Ad Networks ===
      '||doubleclick.net^',
      '||googlesyndication.com^',
      '||googleadservices.com^',
      '||google-analytics.com^',
      '||googletagmanager.com^',
      '||googletagservices.com^',
      '||adservice.google.com^',
      '||pagead2.googlesyndication.com^',
      '||tpc.googlesyndication.com^',
      
      // Facebook/Meta
      '||facebook.net^',
      '||facebook.com/tr^',
      '||facebook.com/plugins^',
      '||connect.facebook.net^',
      '||staticxx.facebook.com^',
      
      // Amazon
      '||amazon-adsystem.com^',
      '||aax.amazon-adsystem.com^',
      '||s.amazon-adsystem.com^',
      '||fls-na.amazon.com^',
      '||aax-us-east.amazon-adsystem.com^',
      
      // === Ad Exchanges & Networks ===
      '||adnxs.com^',
      '||rubiconproject.com^',
      '||pubmatic.com^',
      '||openx.net^',
      '||adsrvr.org^',
      '||criteo.com^',
      '||criteo.net^',
      '||outbrain.com^',
      '||taboola.com^',
      '||advertising.com^',
      '||media.net^',
      '||indexww.com^',
      '||spotxchange.com^',
      '||appnexus.com^',
      '||casalemedia.com^',
      '||contextweb.com^',
      '||adform.net^',
      '||smartadserver.com^',
      '||teads.tv^',
      '||triplelift.com^',
      '||sovrn.com^',
      '||33across.com^',
      '||improvedigital.com^',
      '||gumgum.com^',
      '||sharethrough.com^',
      
      // === Analytics & Tracking ===
      '||scorecardresearch.com^',
      '||quantserve.com^',
      '||chartbeat.com^',
      '||omtrdc.net^',
      '||2o7.net^',
      '||newrelic.com^',
      '||hotjar.com^',
      '||mouseflow.com^',
      '||crazyegg.com^',
      '||luckyorange.com^',
      '||fullstory.com^',
      '||mixpanel.com^',
      '||segment.com^',
      '||segment.io^',
      '||amplitude.com^',
      '||heap.io^',
      '||bugsnag.com^',
      '||sentry.io^',
      
      // === Social Media Tracking ===
      '||twitter.com/i/adsct^',
      '||analytics.twitter.com^',
      '||linkedin.com/px^',
      '||ads.linkedin.com^',
      '||pinterest.com/ct^',
      '||ads.pinterest.com^',
      '||ads.tiktok.com^',
      '||analytics.tiktok.com^',
      '||reddit.com/api/v1/pixel^',
      '||redditmedia.com/ads^',
      '||snapchat.com/ads^',
      
      // === Video Ads (YouTube & Others) ===
      '||imasdk.googleapis.com^',
      '||youtube.com/api/stats/ads^',
      '||youtube.com/ptracking^',
      '||youtube.com/pagead^',
      '||youtube.com/get_video_info^',
      '||youtube.com/api/stats/qoe^',
      '||s.ytimg.com/yts/jsbin/player-*/ads^',
      '||adservice.google.*/ads^',
      '||fwmrm.net^',
      '||2mdn.net^',
      '||innovid.com^',
      '||serving-sys.com^',
      
      // YouTube-specific comprehensive blocking (Brave-style aggressive)
      '||youtube.com/api/stats/ads^',
      '||youtube.com/ptracking^',
      '||youtube.com/pagead^',
      '||youtube.com/get_video_info*&ad^',
      '||youtube.com/api/stats/watchtime^',
      '||s.youtube.com/api/stats/watchtime^',
      '||googlevideo.com/videoplayback*&ad^',
      '||googlevideo.com/videoplayback*adformat^',
      '||youtube.com/youtubei/v1/player/ad^',
      '||youtube.com/get_midroll_info^',
      '||youtube.com/api/stats/atr^',
      '||youtube.com/api/stats/qoe^',
      '||youtube.com/csi_204^',
      '||youtube.com/pcs/activeview^',
      '||youtube.com/generate_204^',
      '||youtube.com/api/stats/ads_*^',
      '||youtube.com/api/stats/atr_*^',
      '||youtube.com/api/stats/clicktracking^',
      '||youtube.com/api/stats/playback^',
      '||youtube.com/api/stats/player_ads^',
      '||youtube.com/api/stats/qoe_*^',
      '||youtube.com/get_ads^',
      '||youtube.com/get_video_ads^',
      '||youtube.com/pagead/*^',
      '||youtube.com/ptracking/*^',
      '||youtube.com/api/stats/ads/*^',
      '||youtube.com/youtubei/v1/player/ad*^',
      '||youtube.com/youtubei/v1/player/get_midroll_info^',
      '||youtube.com/youtubei/v1/player/get_preroll_info^',
      '||youtube.com/youtubei/v1/player/get_postroll_info^',
      '||youtube.com/youtubei/v1/player/get_ad_break_info^',
      '||youtube.com/youtubei/v1/player/get_ad_break_*^',
      '||youtube.com/youtubei/v1/player/get_ad_*^',
      '||youtube.com/youtubei/v1/player/ad_*^',
      '||youtube.com/youtubei/v1/player/*ad*^',
      '||youtube.com/youtubei/v1/player/*ads*^',
      '||youtube.com/youtubei/v1/player/*advertising*^',
      '||youtube.com/youtubei/v1/player/*sponsor*^',
      '||youtube.com/youtubei/v1/player/*promo*^',
      '||youtube.com/youtubei/v1/player/*promotion*^',
      '||youtube.com/youtubei/v1/player/*tracking*^',
      '||youtube.com/youtubei/v1/player/*tracker*^',
      '||youtube.com/youtubei/v1/player/*analytics*^',
      '||youtube.com/youtubei/v1/player/*telemetry*^',
      '||youtube.com/youtubei/v1/player/*metrics*^',
      '||youtube.com/youtubei/v1/player/*beacon*^',
      '||youtube.com/youtubei/v1/player/*pixel*^',
      '||youtube.com/youtubei/v1/player/*tag*^',
      '||youtube.com/youtubei/v1/player/*tags*^',
      '||youtube.com/youtubei/v1/player/*doubleclick*^',
      '||youtube.com/youtubei/v1/player/*googlesyndication*^',
      '||youtube.com/youtubei/v1/player/*adserver*^',
      '||youtube.com/youtubei/v1/player/*advertising*^',
      '||youtube.com/youtubei/v1/player/*advert*^',
      '||youtube.com/youtubei/v1/player/*banner*^',
      '||youtube.com/youtubei/v1/player/*popup*^',
      '||youtube.com/youtubei/v1/player/*popunder*^',
      '||youtube.com/youtubei/v1/player/*sponsor*^',
      '||youtube.com/youtubei/v1/player/*sponsored*^',
      '||youtube.com/youtubei/v1/player/*promo*^',
      '||youtube.com/youtubei/v1/player/*promotion*^',
      '||youtube.com/youtubei/v1/player/*tracking*^',
      '||youtube.com/youtubei/v1/player/*tracker*^',
      '||youtube.com/youtubei/v1/player/*analytics*^',
      '||youtube.com/youtubei/v1/player/*telemetry*^',
      '||youtube.com/youtubei/v1/player/*metrics*^',
      '||youtube.com/youtubei/v1/player/*beacon*^',
      '||youtube.com/youtubei/v1/player/*pixel*^',
      '||youtube.com/youtubei/v1/player/*tag*^',
      '||youtube.com/youtubei/v1/player/*tags*^',
      '||youtube.com/youtubei/v1/player/*doubleclick*^',
      '||youtube.com/youtubei/v1/player/*googlesyndication*^',
      '||youtube.com/youtubei/v1/player/*adserver*^',
      '||youtube.com/youtubei/v1/player/*advertising*^',
      '||youtube.com/youtubei/v1/player/*advert*^',
      '||youtube.com/youtubei/v1/player/*banner*^',
      '||youtube.com/youtubei/v1/player/*popup*^',
      '||youtube.com/youtubei/v1/player/*popunder*^',
      '||youtube.com/youtubei/v1/player/*sponsor*^',
      '||youtube.com/youtubei/v1/player/*sponsored*^',
      '||youtube.com/youtubei/v1/player/*promo*^',
      '||youtube.com/youtubei/v1/player/*promotion*^',
      '||youtube.com/youtubei/v1/player/*tracking*^',
      '||youtube.com/youtubei/v1/player/*tracker*^',
      '||youtube.com/youtubei/v1/player/*analytics*^',
      '||youtube.com/youtubei/v1/player/*telemetry*^',
      '||youtube.com/youtubei/v1/player/*metrics*^',
      '||youtube.com/youtubei/v1/player/*beacon*^',
      '||youtube.com/youtubei/v1/player/*pixel*^',
      '||youtube.com/youtubei/v1/player/*tag*^',
      '||youtube.com/youtubei/v1/player/*tags*^',
      '||youtube.com/youtubei/v1/player/*doubleclick*^',
      '||youtube.com/youtubei/v1/player/*googlesyndication*^',
      '||youtube.com/youtubei/v1/player/*adserver*^',
      '||youtube.com/youtubei/v1/player/*advertising*^',
      '||youtube.com/youtubei/v1/player/*advert*^',
      '||youtube.com/youtubei/v1/player/*banner*^',
      '||youtube.com/youtubei/v1/player/*popup*^',
      '||youtube.com/youtubei/v1/player/*popunder*^',
      '||youtube.com/youtubei/v1/player/*sponsor*^',
      '||youtube.com/youtubei/v1/player/*sponsored*^',
      '||youtube.com/youtubei/v1/player/*promo*^',
      '||youtube.com/youtubei/v1/player/*promotion*^',
      '||youtube.com/youtubei/v1/player/*tracking*^',
      '||youtube.com/youtubei/v1/player/*tracker*^',
      '||youtube.com/youtubei/v1/player/*analytics*^',
      '||youtube.com/youtubei/v1/player/*telemetry*^',
      '||youtube.com/youtubei/v1/player/*metrics*^',
      '||youtube.com/youtubei/v1/player/*beacon*^',
      '||youtube.com/youtubei/v1/player/*pixel*^',
      '||youtube.com/youtubei/v1/player/*tag*^',
      '||youtube.com/youtubei/v1/player/*tags*^',
      '||youtube.com/youtubei/v1/player/*doubleclick*^',
      '||youtube.com/youtubei/v1/player/*googlesyndication*^',
      '||youtube.com/youtubei/v1/player/*adserver*^',
      '||youtube.com/youtubei/v1/player/*advertising*^',
      '||youtube.com/youtubei/v1/player/*advert*^',
      '||youtube.com/youtubei/v1/player/*banner*^',
      '||youtube.com/youtubei/v1/player/*popup*^',
      '||youtube.com/youtubei/v1/player/*popunder*^',
      '||youtube.com/youtubei/v1/player/*sponsor*^',
      '||youtube.com/youtubei/v1/player/*sponsored*^',
      '||youtube.com/youtubei/v1/player/*promo*^',
      '||youtube.com/youtubei/v1/player/*promotion*^',
      '||youtube.com/youtubei/v1/player/*tracking*^',
      '||youtube.com/youtubei/v1/player/*tracker*^',
      '||youtube.com/youtubei/v1/player/*analytics*^',
      '||youtube.com/youtubei/v1/player/*telemetry*^',
      '||youtube.com/youtubei/v1/player/*metrics*^',
      '||youtube.com/youtubei/v1/player/*beacon*^',
      '||youtube.com/youtubei/v1/player/*pixel*^',
      '||youtube.com/youtubei/v1/player/*tag*^',
      '||youtube.com/youtubei/v1/player/*tags*^',
      '||youtube.com/youtubei/v1/player/*doubleclick*^',
      '||youtube.com/youtubei/v1/player/*googlesyndication*^',
      '||youtube.com/youtubei/v1/player/*adserver*^',
      
      // YouTube IMA SDK (Interactive Media Ads) - Complete blocking
      '||imasdk.googleapis.com^',
      '||imasdk.googleapis.com/*^',
      '||imasdk.googleapis.com/js/sdkloader/ima3.js^',
      '||imasdk.googleapis.com/js/core/bridge^',
      '||imasdk.googleapis.com/js/sdkloader/ima3_dai.js^',
      '||imasdk.googleapis.com/pal/sdkloader/pal.js^',
      '||imasdk.googleapis.com/js/*^',
      '||imasdk.googleapis.com/pal/*^',
      '||imasdk.googleapis.com/core/*^',
      '||imasdk.googleapis.com/sdkloader/*^',
      '||imasdk.googleapis.com/ads/*^',
      '||imasdk.googleapis.com/ad/*^',
      '||imasdk.googleapis.com/advertising/*^',
      '||imasdk.googleapis.com/advert/*^',
      '||imasdk.googleapis.com/banner/*^',
      '||imasdk.googleapis.com/popup/*^',
      '||imasdk.googleapis.com/popunder/*^',
      '||imasdk.googleapis.com/sponsor/*^',
      '||imasdk.googleapis.com/sponsored/*^',
      '||imasdk.googleapis.com/promo/*^',
      '||imasdk.googleapis.com/promotion/*^',
      '||imasdk.googleapis.com/tracking/*^',
      '||imasdk.googleapis.com/tracker/*^',
      '||imasdk.googleapis.com/analytics/*^',
      '||imasdk.googleapis.com/telemetry/*^',
      '||imasdk.googleapis.com/metrics/*^',
      '||imasdk.googleapis.com/beacon/*^',
      '||imasdk.googleapis.com/pixel/*^',
      '||imasdk.googleapis.com/tag/*^',
      '||imasdk.googleapis.com/tags/*^',
      '||imasdk.googleapis.com/doubleclick/*^',
      '||imasdk.googleapis.com/googlesyndication/*^',
      '||imasdk.googleapis.com/adserver/*^',
      '||imasdk.googleapis.com/advertising/*^',
      '||imasdk.googleapis.com/advert/*^',
      '||imasdk.googleapis.com/banner/*^',
      '||imasdk.googleapis.com/popup/*^',
      '||imasdk.googleapis.com/popunder/*^',
      '||imasdk.googleapis.com/sponsor/*^',
      '||imasdk.googleapis.com/sponsored/*^',
      '||imasdk.googleapis.com/promo/*^',
      '||imasdk.googleapis.com/promotion/*^',
      '||imasdk.googleapis.com/tracking/*^',
      '||imasdk.googleapis.com/tracker/*^',
      '||imasdk.googleapis.com/analytics/*^',
      '||imasdk.googleapis.com/telemetry/*^',
      '||imasdk.googleapis.com/metrics/*^',
      '||imasdk.googleapis.com/beacon/*^',
      '||imasdk.googleapis.com/pixel/*^',
      '||imasdk.googleapis.com/tag/*^',
      '||imasdk.googleapis.com/tags/*^',
      '||imasdk.googleapis.com/doubleclick/*^',
      '||imasdk.googleapis.com/googlesyndication/*^',
      '||imasdk.googleapis.com/adserver/*^',
      
      // YouTube Premium prompts and upsells
      '||youtube.com/premium^',
      '||youtube.com/red^',
      '||youtube.com/api/stats/offerwatching^',
      
      // === Mobile Ad Networks ===
      '||admob.com^',
      '||ads.mopub.com^',
      '||unity3d.com/ads^',
      '||applovin.com^',
      '||ironsrc.com^',
      '||chartboost.com^',
      '||vungle.com^',
      '||tapjoy.com^',
      '||inmobi.com^',
      '||adcolony.com^',
      '||startapp.com^',
      '||fyber.com^',
      
      // === CDN & Ads ===
      '||cdn.taboola.com^',
      '||cdn.taboola.com/libtrc^',
      '||securepubads.g.doubleclick.net^',
      '||static.doubleclick.net^',
      '||ads.pubmatic.com^',
      '||ads.rubiconproject.com^',
      
      // === Path-based Rules ===
      '/ad.php',
      '/ad.js',
      '/ads.php',
      '/ads.js',
      '/adserver',
      '/advert',
      '/advertisement',
      '/banner',
      '/banners',
      '/popup',
      '/popunder',
      '/sponsor',
      '/sponsored',
      '/_ads/',
      '/ads/',
      '/ad/',
      '/advertisement/',
      '/banner/',
      '/popup/',
      '/tracking/',
      '/tracker/',
      '/analytics/',
      '/telemetry/',
      '/metrics/',
      '/beacon/',
      '/pixel/',
      '/*/ads/*',
      '/*/ad/*',
      '/*/advertisement/*',
      '/*/banner/*',
      '/*/sponsor/*',
      '/*/tracking/*',
      '/*/analytics/*',
      
      // === Query Parameters ===
      '*?ad=*',
      '*?ads=*',
      '*&ad=*',
      '*&ads=*',
      '*&adid=*',
      '*&ad_id=*',
      '*&advertising=*',
      '*&banner=*',
      '*&popup=*',
      '*&sponsor=*',
      '*&tracking=*',
      '*&tracker=*',
      '*&analytics=*',
      '*&utm_source=*',
      '*&utm_medium=*',
      '*&utm_campaign=*',
      '*&fbclid=*',
      '*&gclid=*',
      '*&msclkid=*',
      
      // === Domain Patterns ===
      '||ad.*^',
      '||ads.*^',
      '||adserver.*^',
      '||adserv.*^',
      '||advert.*^',
      '||advertising.*^',
      '||banner.*^',
      '||banners.*^',
      '||click.*^',
      '||clicks.*^',
      '||tracker.*^',
      '||tracking.*^',
      '||analytics.*^',
      '||stats.*^',
      '||telemetry.*^',
      '||metrics.*^',
      '||tag.*^',
      '||tags.*^',
      '||pixel.*^',
      '||beacon.*^',
      
      // === Subdomain Patterns ===
      '*.ad.*',
      '*.ads.*',
      '*.adserver.*',
      '*.advertising.*',
      '*.banner.*',
      '*.tracker.*',
      '*.tracking.*',
      '*.analytics.*',
      '*.telemetry.*',
      '*.metrics.*',
      '*.pixel.*',
      '*advert*',
      '*banner*',
      '*popup*',
      '*sponsor*',
      
      // === Resource Types ===
      '*.ad.js',
      '*.ads.js',
      '*.advertising.js',
      '*.banner.js',
      '*.tracker.js',
      '*.analytics.js',
      '*/ad-*.js',
      '*/ads-*.js',
      '*/advertising-*.js',
      
      // === Common Ad Servers ===
      '||ad.doubleclick.net^',
      '||ad.google.com^',
      '||adclick.*^',
      '||adclient.*^',
      '||adimg.*^',
      '||adlog.*^',
      '||admanager.*^',
      '||adsense.*^',
      '||adtech.*^',
      '||adtracker.*^',
      '||adwords.*^',
    ];
  }

  void _buildBlockedDomains() {
    _blockedDomains.clear();
    _blockedPatterns.clear();
    _fastBlockedDomains.clear();
    _fastBlockedSubdomains.clear();
    
    for (final rule in _filterRules) {
      // Extract exact domains (||domain.com^)
      if (rule.startsWith('||') && rule.endsWith('^')) {
        final domain = rule.substring(2, rule.length - 1).toLowerCase();
        if (domain.isNotEmpty && !domain.contains('*') && !domain.contains('/')) {
          _blockedDomains.add(domain);
          _fastBlockedDomains.add(domain);
          // Pre-compute common subdomain patterns for faster lookup
          if (domain.contains('.')) {
            final parts = domain.split('.');
            if (parts.length >= 2) {
              final baseDomain = parts.sublist(parts.length - 2).join('.');
              _fastBlockedSubdomains.add(baseDomain);
            }
          }
        }
      }
      // Store pattern-based rules separately
      else if (rule.contains('*') || rule.startsWith('/')) {
        _blockedPatterns.add(rule.toLowerCase());
      }
    }
  }

  Future<void> _downloadFilterLists() async {
    try {
      if (_lastUpdate != null) {
        final hoursSinceUpdate = DateTime.now().difference(_lastUpdate!).inHours;
        if (hoursSinceUpdate < 12) {
          return;
        }
      }

      final dio = Dio();
      final newRules = <String>[];
      
      // Download multiple comprehensive filter lists
      final filterUrls = [
        // EasyList - Standard ad blocking
        ApiConstants.easyListUrl,
        ApiConstants.easyPrivacyUrl,
        'https://easylist-downloads.adblockplus.org/fanboy-annoyance.txt',
        'https://secure.fanboy.co.nz/fanboy-cookiemonster.txt',
        
        // uBlock Origin - Advanced blocking
        'https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/filters.txt',
        'https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/badware.txt',
        'https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/privacy.txt',
        'https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/unbreak.txt',
        'https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/resource-abuse.txt',
        
        // AdGuard - Comprehensive blocking
        'https://filters.adtidy.org/extension/chromium/filters/2.txt', // Base
        'https://filters.adtidy.org/extension/chromium/filters/3.txt', // Tracking
        'https://filters.adtidy.org/extension/chromium/filters/14.txt', // Annoyances
        
        // Peter Lowe's Ad Server List
        'https://pgl.yoyo.org/adservers/serverlist.php?hostformat=adblockplus&showintro=0',
      ];

      for (final url in filterUrls) {
        try {
          final response = await dio.get(
            url,
            options: Options(
              receiveTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 15),
            ),
          );

          if (response.statusCode == 200) {
            final rules = _parseFilterList(response.data.toString());
            newRules.addAll(rules);
          }
        } catch (e) {
          // Continue with other lists
          continue;
        }
      }
      
      if (newRules.isNotEmpty) {
        _filterRules.addAll(newRules);
        // Remove duplicates
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
          trimmed.startsWith('@@')) {
        continue;
      }
      
      if (trimmed.contains('##') || trimmed.contains('#@#') || trimmed.contains('#?#')) {
        continue;
      }
      
      if (trimmed.isNotEmpty && trimmed.length < 500) {
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
    // Save periodically to avoid too many writes
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

  /// Main URL blocking check with multiple layers and caching
  /// Only blocks actual ad endpoints, never blocks player APIs
  bool shouldBlockUrl(String url) {
    if (!state.isEnabled) return false;
    
    // OPTIMIZED: Check cache first for performance
    final lowerUrl = url.toLowerCase();
    final cacheKey = lowerUrl;
    
    // CRITICAL: NEVER block YouTube/Google player APIs - allow all YouTube functionality
    // Only block actual ad endpoints, not player APIs
    if (lowerUrl.contains('youtube.com') || 
        lowerUrl.contains('youtu.be') ||
        lowerUrl.contains('googlevideo.com') ||
        lowerUrl.contains('google.com') ||
        lowerUrl.contains('gstatic.com') ||
        lowerUrl.contains('googleapis.com')) {
      // Block IMA SDK completely (ad SDK, not player API)
      if (lowerUrl.contains('imasdk.googleapis.com')) {
        _cacheResult(cacheKey, true);
        incrementBlockedCount();
        return true;
      }
      // Block ONLY actual ad API endpoints (not player APIs)
      // Be very selective - only block confirmed ad endpoints, never block player APIs
      if (lowerUrl.contains('/api/stats/ads') ||
          lowerUrl.contains('/ptracking') ||
          lowerUrl.contains('/pagead')) {
        _cacheResult(cacheKey, true);
        incrementBlockedCount();
        return true;
      }
      // Allow all other YouTube/Google URLs (player APIs, search, navigation, videos, etc.)
      return false;
    }
    if (_urlBlockCache.containsKey(cacheKey)) {
      final cached = _urlBlockCache[cacheKey]!;
      if (cached) {
        incrementBlockedCount();
      }
      return cached;
    }
    
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) {
        _cacheResult(cacheKey, false);
        return false;
      }
      
      final host = uri.host.toLowerCase();
      final path = uri.path.toLowerCase();
      final query = uri.query.toLowerCase();
      final fullUrl = lowerUrl;
      
      // Layer 1: Whitelist check (fastest)
      for (final whitelistDomain in _whitelistDomains) {
        if (host.contains(whitelistDomain.toLowerCase())) {
          _cacheResult(cacheKey, false);
          return false;
        }
      }
      
      // Layer 2: Fast exact domain lookup (O(1) with Set)
      if (_fastBlockedDomains.contains(host)) {
        _cacheResult(cacheKey, true);
        incrementBlockedCount();
        return true;
      }
      
      // Layer 3: Optimized subdomain check using pre-computed base domains
      if (host.contains('.')) {
        final parts = host.split('.');
        if (parts.length >= 2) {
          final baseDomain = parts.sublist(parts.length - 2).join('.');
          if (_fastBlockedSubdomains.contains(baseDomain)) {
            // Verify it's actually blocked by checking full domain
            if (_fastBlockedDomains.contains(baseDomain) || 
                _fastBlockedDomains.any((d) => host.endsWith('.$d'))) {
              _cacheResult(cacheKey, true);
              incrementBlockedCount();
              return true;
            }
          }
        }
      }
      
      // Layer 4: Keyword-based heuristic check (fast) - skip for YouTube/Google
      if (!lowerUrl.contains('youtube.com') && 
          !lowerUrl.contains('youtu.be') &&
          !lowerUrl.contains('google.com') &&
          !lowerUrl.contains('googlevideo.com')) {
        if (_containsAdKeywords(host, path, query)) {
          _cacheResult(cacheKey, true);
          incrementBlockedCount();
          return true;
        }
      }
      
      // Layer 5: Pattern matching with cached patterns (limited) - skip for YouTube/Google
      if (!lowerUrl.contains('youtube.com') && 
          !lowerUrl.contains('youtu.be') &&
          !lowerUrl.contains('google.com') &&
          !lowerUrl.contains('googlevideo.com')) {
        int patternChecks = 0;
        final maxPatternChecks = _blockedPatterns.length > 100 ? 100 : _blockedPatterns.length;
        for (final pattern in _blockedPatterns) {
          if (patternChecks++ >= maxPatternChecks) break; // Limit checks for performance
          if (_matchesPattern(fullUrl, host, path, query, pattern)) {
            _cacheResult(cacheKey, true);
            incrementBlockedCount();
            return true;
          }
        }
      }
      
      // Layer 6: Full rule checking (limited, most expensive) - skip for YouTube/Google
      if (!lowerUrl.contains('youtube.com') && 
          !lowerUrl.contains('youtu.be') &&
          !lowerUrl.contains('google.com') &&
          !lowerUrl.contains('googlevideo.com')) {
        int ruleChecks = 0;
        final maxRuleChecks = _filterRules.length > 200 ? 200 : _filterRules.length;
        for (final rule in _filterRules) {
          if (ruleChecks++ >= maxRuleChecks) break; // Limit checks for performance
          if (!_fastBlockedDomains.contains(rule) && 
              !_blockedPatterns.contains(rule.toLowerCase())) {
            if (_matchesRule(fullUrl, host, path, query, rule)) {
              _cacheResult(cacheKey, true);
              incrementBlockedCount();
              return true;
            }
          }
        }
      }
      
      _cacheResult(cacheKey, false);
      return false;
    } catch (e) {
      _cacheResult(cacheKey, false);
      return false;
    }
  }
  
  /// Cache URL blocking result (LRU cache)
  void _cacheResult(String key, bool shouldBlock) {
    // Remove oldest entries if cache is full
    if (_urlBlockCache.length >= _maxCacheSize) {
      final keysToRemove = _urlBlockCache.keys.take(_maxCacheSize ~/ 4).toList();
      for (final k in keysToRemove) {
        _urlBlockCache.remove(k);
      }
    }
    _urlBlockCache[key] = shouldBlock;
  }

  /// Keyword-based heuristic detection
  bool _containsAdKeywords(String host, String path, String query) {
    for (final keyword in _adKeywords) {
      // Check for keyword in subdomain (ads.example.com)
      if (host.startsWith('$keyword.') || 
          host.contains('.$keyword.') ||
          host.endsWith('.$keyword')) {
        return true;
      }
      
      // Check for keyword in path segments
      final pathSegments = path.split('/');
      for (final segment in pathSegments) {
        if (segment == keyword || 
            segment.startsWith('$keyword-') ||
            segment.startsWith('${keyword}_') ||
            segment.endsWith('-$keyword') ||
            segment.endsWith('_$keyword')) {
          return true;
        }
      }
      
      // Check query parameters
      if (query.contains('$keyword=') || 
          query.contains('&$keyword') ||
          query.contains('?$keyword')) {
        return true;
      }
    }
    
    return false;
  }

  /// Fast pattern matching
  bool _matchesPattern(String url, String host, String path, String query, String pattern) {
    try {
      if (pattern.contains('*')) {
        final regexPattern = pattern.replaceAll('*', '.*');
        
        if (!_regexCache.containsKey(regexPattern)) {
          _regexCache[regexPattern] = RegExp(regexPattern, caseSensitive: false);
        }
        
        return _regexCache[regexPattern]!.hasMatch(url);
      }
      
      return url.contains(pattern);
    } catch (e) {
      return false;
    }
  }

  /// Detailed rule matching
  bool _matchesRule(String url, String host, String path, String query, String rule) {
    try {
      final lowerRule = rule.toLowerCase();
      
      // Domain rules (||domain.com^)
      if (lowerRule.startsWith('||') && lowerRule.endsWith('^')) {
        final domain = lowerRule.substring(2, lowerRule.length - 1);
        return host == domain || host.endsWith('.$domain');
      }
      
      // Domain prefix (||domain.com)
      if (lowerRule.startsWith('||')) {
        final domain = lowerRule.substring(2);
        return host.contains(domain);
      }
      
      // Path rules (starts with /)
      if (lowerRule.startsWith('/')) {
        if (lowerRule.contains('*')) {
          final pattern = lowerRule.replaceAll('*', '.*');
          if (!_regexCache.containsKey(pattern)) {
            _regexCache[pattern] = RegExp(pattern, caseSensitive: false);
          }
          return _regexCache[pattern]!.hasMatch(path) || 
                 _regexCache[pattern]!.hasMatch(query);
        }
        return path.contains(lowerRule) || query.contains(lowerRule);
      }
      
      // Wildcard rules
      if (lowerRule.contains('*')) {
        final pattern = lowerRule.replaceAll('*', '.*');
        if (!_regexCache.containsKey(pattern)) {
          _regexCache[pattern] = RegExp(pattern, caseSensitive: false);
        }
        return _regexCache[pattern]!.hasMatch(url);
      }
      
      // Simple substring match
      return url.contains(lowerRule);
    } catch (e) {
      return false;
    }
  }

  /// Get content blockers for InAppWebView - Enhanced for YouTube
  /// Optimized and comprehensive blocking
  List<ContentBlocker> getContentBlockers() {
    if (!state.isEnabled) return [];
    
    final blockers = <ContentBlocker>[];
    
    // === YOUTUBE-SPECIFIC BLOCKERS (Priority) ===
    blockers.addAll(_getYouTubeBlockers());
    
    // === GENERAL AD NETWORK BLOCKERS ===
    // Block major ad networks (combined patterns for efficiency)
    blockers.add(ContentBlocker(
      trigger: ContentBlockerTrigger(
        urlFilter: '.*(doubleclick|googlesyndication|googleadservices|googletagmanager|googletagservices|adservice\\.google|pagead2\\.googlesyndication|tpc\\.googlesyndication|amazon-adsystem|adnxs|rubiconproject|pubmatic|openx|criteo|outbrain|taboola).*',
        resourceType: [
          ContentBlockerTriggerResourceType.IMAGE,
          ContentBlockerTriggerResourceType.SCRIPT,
          ContentBlockerTriggerResourceType.MEDIA,
          ContentBlockerTriggerResourceType.DOCUMENT,
        ],
      ),
      action: ContentBlockerAction(
        type: ContentBlockerActionType.BLOCK,
      ),
    ));
    
    // Block analytics and tracking
    blockers.add(ContentBlocker(
      trigger: ContentBlockerTrigger(
        urlFilter: '.*(google-analytics|googletagmanager|scorecardresearch|quantserve|chartbeat|hotjar|mouseflow|crazyegg|mixpanel|segment|amplitude|heap|bugsnag|sentry).*',
        resourceType: [
          ContentBlockerTriggerResourceType.SCRIPT,
          ContentBlockerTriggerResourceType.IMAGE,
        ],
      ),
      action: ContentBlockerAction(
        type: ContentBlockerActionType.BLOCK,
      ),
    ));
    
    // Block common ad path patterns
    blockers.add(ContentBlocker(
      trigger: ContentBlockerTrigger(
        urlFilter: '.*/(ad|ads|advertisement|banner|popup|tracking|tracker|analytics|telemetry|doubleclick|googlesyndication|adserver|advertising|sponsor|promo|promotion)/.*',
        resourceType: [
          ContentBlockerTriggerResourceType.IMAGE,
          ContentBlockerTriggerResourceType.SCRIPT,
          ContentBlockerTriggerResourceType.MEDIA,
        ],
      ),
      action: ContentBlockerAction(
        type: ContentBlockerActionType.BLOCK,
      ),
    ));
    
    // Block query parameters with ad-related terms
    blockers.add(ContentBlocker(
      trigger: ContentBlockerTrigger(
        urlFilter: '.*[?&](ad|ads|adid|ad_id|advertising|banner|popup|sponsor|tracking|tracker|analytics|utm_source|utm_medium|utm_campaign|fbclid|gclid|msclkid)=.*',
      ),
      action: ContentBlockerAction(
        type: ContentBlockerActionType.BLOCK,
      ),
    ));
    
    // Return all blockers (limit is handled by platform)
    return blockers;
  }

  /// YouTube-specific content blockers - Enhanced and comprehensive
  List<ContentBlocker> _getYouTubeBlockers() {
    return [
      // Block IMA SDK completely (all resource types)
      ContentBlocker(
        trigger: ContentBlockerTrigger(
          urlFilter: '.*imasdk\\.googleapis\\.com.*',
          resourceType: [
            ContentBlockerTriggerResourceType.SCRIPT,
            ContentBlockerTriggerResourceType.DOCUMENT,
            ContentBlockerTriggerResourceType.MEDIA,
            ContentBlockerTriggerResourceType.IMAGE,
          ],
        ),
        action: ContentBlockerAction(
          type: ContentBlockerActionType.BLOCK,
        ),
      ),
      // Block YouTube ad tracking endpoints
      ContentBlocker(
        trigger: ContentBlockerTrigger(
          urlFilter: '.*youtube\\.com/.*(api/stats/ads|ptracking|pagead|get_midroll|get_preroll|get_postroll|get_ad_break|get_ad_|youtubei/v1/player/ad).*',
          resourceType: [
            ContentBlockerTriggerResourceType.SCRIPT,
            ContentBlockerTriggerResourceType.DOCUMENT,
            ContentBlockerTriggerResourceType.MEDIA,
          ],
        ),
        action: ContentBlockerAction(
          type: ContentBlockerActionType.BLOCK,
        ),
      ),
      // Block YouTube ad API endpoints (alternative pattern)
      ContentBlocker(
        trigger: ContentBlockerTrigger(
          urlFilter: '.*youtube\\.com/(api/stats/ads|ptracking|pagead|get_midroll_info|get_preroll_info|get_postroll_info|get_ad_break_info|get_ad_|youtubei/v1/player/ad|youtubei/v1/player/get_midroll|youtubei/v1/player/get_preroll|youtubei/v1/player/get_postroll|youtubei/v1/player/get_ad_break|youtubei/v1/player/get_ad_|youtubei/v1/player/ad_|api/stats/ads_|api/stats/atr|api/stats/clicktracking|api/stats/player_ads|get_ads|get_video_ads|csi_204|pcs/activeview|generate_204).*',
          resourceType: [
            ContentBlockerTriggerResourceType.SCRIPT,
            ContentBlockerTriggerResourceType.DOCUMENT,
          ],
        ),
        action: ContentBlockerAction(
          type: ContentBlockerActionType.BLOCK,
        ),
      ),
      // Block ad-related query parameters in YouTube URLs
      ContentBlocker(
        trigger: ContentBlockerTrigger(
          urlFilter: '.*youtube\\.com/.*[?&](adformat|adid|ad_id|adbreak|ad_break)=.*',
        ),
        action: ContentBlockerAction(
          type: ContentBlockerActionType.BLOCK,
        ),
      ),
    ];
  }

  /// Get optimized JavaScript for YouTube ad blocking (simplified and efficient)
  /// Returns a single optimized script that's much smaller and faster
  String getAdBlockingJavaScript() {
    return _getYouTubeAdBlockScript();
  }
  
  /// Simplified and effective YouTube ad blocking script
  /// Uses multiple injection points and combined approach
  /// Updated regularly to handle YouTube's constant changes
  String _getYouTubeAdBlockScript() {
    return '''
      (function() {
        'use strict';
        
        // === PHASE 1: BLOCK IMA SDK (Runs First) ===
        // Only block IMA SDK, don't interfere with player APIs
        (function() {
          try {
            if (!window.google) window.google = {};
            // Block IMA SDK initialization
            window.google.ima = window.google.ima || {};
            if (!window.google.ima.AdsLoader) {
              window.google.ima.AdsLoader = function() {
                this.requestAds = function() {};
                this.addEventListener = function() {};
              };
            }
            if (!window.google.ima.AdsManager) {
              window.google.ima.AdsManager = function() {
                this.start = function() {};
                this.getAdCuePoints = function() { return []; };
                this.addEventListener = function() {};
              };
            }
            if (!window.google.ima.AdDisplayContainer) {
              window.google.ima.AdDisplayContainer = function() {
                this.initialize = function() {};
              };
            }
          } catch(e) {}
        })();
        
        // === PHASE 2: CSS INJECTION (Hide Ads Immediately) ===
        (function() {
          try {
            const style = document.createElement('style');
            style.id = 'yt-adblock-css';
            style.textContent = `
              .ytp-ad-module, .ytp-ad-overlay-container, 
              .ad-showing:not(video):not(.html5-video-player):not(#movie_player),
              .ad-interrupting:not(video):not(.html5-video-player):not(#movie_player), 
              #player-ads, .video-ads,
              [class*="ytp-ad"]:not(video):not(.html5-video-player):not(#movie_player),
              iframe[src*="imasdk"], iframe[src*="doubleclick"] {
                display: none !important;
                visibility: hidden !important;
                opacity: 0 !important;
                pointer-events: none !important;
              }
            `;
            if (document.head) {
              document.head.appendChild(style);
            } else {
              document.addEventListener('DOMContentLoaded', function() {
                if (document.head) document.head.appendChild(style);
              });
            }
          } catch(e) {}
        })();
        
        // === PHASE 3: AD REMOVAL FUNCTION (Simplified and Safe) ===
        const removeAds = function() {
          try {
            const videoPlayer = document.querySelector('.html5-video-player, #movie_player');
            const video = document.querySelector('video.html5-main-video');
            
            // Click skip button
            const skipBtn = document.querySelector('.ytp-ad-skip-button, button[class*="skip"]');
            if (skipBtn && skipBtn.offsetParent !== null && skipBtn.offsetWidth > 0) {
              try {
                skipBtn.click();
              } catch(e) {}
            }
            
            // Click close button on overlay ads
            const closeBtn = document.querySelector('.ytp-ad-overlay-close-button, button[aria-label*="Close ad"]');
            if (closeBtn && closeBtn.offsetParent !== null && closeBtn.offsetWidth > 0) {
              try {
                closeBtn.click();
              } catch(e) {}
            }
            
            // Hide ad elements (but NEVER touch video player)
            const adSelectors = [
              '.ytp-ad-module', '.ytp-ad-overlay-container', 
              '.ad-showing', '.ad-interrupting', '#player-ads', '.video-ads'
            ];
            
            adSelectors.forEach(sel => {
              try {
                document.querySelectorAll(sel).forEach(el => {
                  if (el && el.tagName !== 'VIDEO' && el !== video) {
                    const isInVideoPlayer = el.closest('.html5-video-player') || 
                                         el.closest('#movie_player') ||
                                         (videoPlayer && videoPlayer.contains(el));
                    if (!isInVideoPlayer) {
                      el.style.cssText = 'display:none!important;visibility:hidden!important;opacity:0!important;';
                      try { el.remove(); } catch(e) {}
                    }
                  }
                });
              } catch(e) {}
            });
            
            // Fast-forward ads at 16x speed (only if ad is detected)
            if (video && video.readyState >= 2 && video.duration > 0) {
              const hasAd = document.querySelector('.ad-showing, .ad-interrupting, .ytp-ad-module');
              const player = document.querySelector('.html5-video-player, #movie_player');
              const hasAdClass = player && (
                player.classList.contains('ad-showing') || 
                player.classList.contains('ad-interrupting')
              );
              
              if ((hasAd && hasAd.offsetParent !== null) || hasAdClass) {
                // Ad detected - fast-forward
                if (video.playbackRate !== 16) {
                  try {
                    video.playbackRate = 50;
                  } catch(e) {}
                }
                if (video.paused) {
                  try {
                    video.play().catch(() => {});
                  } catch(e) {}
                }
                // Jump forward if ad is short
                if (video.duration < 180 && video.currentTime < video.duration - 0.5) {
                  try {
                    video.currentTime = Math.min(video.currentTime + 2, video.duration - 0.3);
                  } catch(e) {}
                }
              } else if (video.playbackRate === 16) {
                // No ad - reset to normal speed
                try {
                  video.playbackRate = 1;
                } catch(e) {}
              }
            }
          } catch(e) {}
        };
        
        // === PHASE 4: CONTINUOUS MONITORING (Multiple Injection Points) ===
        const isYouTube = window.location.hostname.includes('youtube.com') || 
                         window.location.hostname.includes('youtu.be');
        
        if (isYouTube) {
          // Run immediately
          if (document.body) {
            removeAds();
          } else {
            document.addEventListener('DOMContentLoaded', removeAds);
          }
          
          // Run at regular intervals
          setInterval(removeAds, 500);
          
          // Mutation observer for dynamic ads
          if (window.MutationObserver) {
            let debounceTimer = null;
            const observer = new MutationObserver(function(mutations) {
              if (debounceTimer) clearTimeout(debounceTimer);
              debounceTimer = setTimeout(removeAds, 100);
            });
            
            const startObserver = function() {
              if (document.body) {
                observer.observe(document.body, {
                  childList: true,
                  subtree: true,
                  attributes: true,
                  attributeFilter: ['class', 'id']
                });
              } else {
                setTimeout(startObserver, 100);
              }
            };
            startObserver();
          }
          
          // Video event listeners
          setTimeout(function() {
            const video = document.querySelector('video.html5-main-video');
            if (video) {
              video.addEventListener('play', function() {
                setTimeout(removeAds, 100);
              }, { passive: true });
              
              video.addEventListener('timeupdate', function() {
                const hasAd = document.querySelector('.ad-showing, .ad-interrupting');
                if (hasAd && hasAd.offsetParent !== null) {
                  if (video.playbackRate !== 16) {
                    try {
                      video.playbackRate = 16;
                      if (video.paused) video.play().catch(() => {});
                    } catch(e) {}
                  }
                } else if (video.playbackRate === 16) {
                  try {
                    video.playbackRate = 1;
                  } catch(e) {}
                }
              }, { passive: true });
            }
          }, 1000);
        }
      })();
    ''';
  }
  
  /// Get ad blocking JavaScript for non-YouTube sites
  String getAdBlockingJavaScriptLegacy() {
    return '''
      (function() {
        'use strict';
        
        // Enhanced ad selectors - comprehensive list
        const adSelectors = [
          '[class*="ad-"]', '[class*="ads-"]', '[class*="advertisement"]', '[class*="advert"]',
          '[id*="ad-"]', '[id*="ads-"]', '[id*="advertisement"]', '[id*="advert"]',
          '[class*="banner"]', '[class*="sponsor"]', '[class*="sponsored"]', '[class*="popup"]',
          '[class*="popunder"]', '[class*="promo"]', '[class*="promotion"]',
          'iframe[src*="doubleclick"]', 'iframe[src*="googlesyndication"]',
          'iframe[src*="ad"]', 'iframe[src*="ads"]', 'iframe[src*="advertising"]',
          'div[class*="ad"]', 'ins.adsbygoogle', '[data-ad-slot]', '[data-ad-client]',
          '[data-google-query-id]', '[data-ad]', '[data-ads]',
          '.ad-container', '.ad-wrapper', '.ad-banner', '.ad-box',
          '.google-ad', '.adsense', '.advertisement-container',
          '[class*="tracking"]', '[class*="tracker"]', '[class*="analytics"]',
        ];
        
        // YouTube-specific selectors
        const youtubeAdSelectors = [
          '.ytp-ad-module', '.ytp-ad-overlay', '.ytp-ad-text',
          '.ytp-ad-skip-button', '.ytp-ad-overlay-container',
          '.ad-showing', '.ad-interrupting', '.video-ads',
          '#player-ads', '.ytp-ad-overlay-container',
          '.ytp-ad-text-overlay', '.ytp-ad-overlay-close-button',
          '.ytp-ad-skip-button-container', '.ytp-ad-overlay-ad-info',
          '.ytp-ad-overlay-image', '.ytp-ad-text',
          'div[id*="ad"]', 'div[class*="ad"]',
        ];
        
        let blockedCount = 0;
        const maxBlocked = 1000; // Prevent infinite loops
        
        function removeAds() {
          if (blockedCount >= maxBlocked) return;
          
          const isYouTube = window.location.hostname.includes('youtube.com') || 
                           window.location.hostname.includes('youtu.be');
          
          if (isYouTube) {
            // YouTube-specific ad blocking - aggressive but safe
            try {
              // Click skip button (most important)
              const skipButton = document.querySelector('.ytp-ad-skip-button, .ytp-ad-skip-button-container button, button[class*="skip"], .ytp-ad-skip-button-modern');
              if (skipButton && skipButton.offsetParent !== null && skipButton.offsetWidth > 0) {
                skipButton.click();
              }
              
              // Click close button on overlay ads
              const closeBtn = document.querySelector('.ytp-ad-overlay-close-button');
              if (closeBtn && closeBtn.offsetParent !== null) {
                closeBtn.click();
              }
              
              // AGGRESSIVE: Remove ad overlays (but protect video player)
              const adOverlays = document.querySelectorAll('.ytp-ad-overlay-container, .ytp-ad-text-overlay, .ytp-ad-overlay-image, .ytp-ad-overlay-ad-info');
              adOverlays.forEach(overlay => {
                if (overlay && overlay.parentNode) {
                  const isVideoPlayer = overlay.closest('.html5-video-player') || 
                                       overlay.closest('#movie_player') ||
                                       overlay.closest('.ytp-player-content') ||
                                       overlay.closest('video');
                  if (!isVideoPlayer && overlay.offsetParent !== null) {
                    overlay.style.cssText = 'display: none !important; visibility: hidden !important; opacity: 0 !important;';
                    overlay.remove();
                  }
                }
              });
              
              // AGGRESSIVE: Remove ad modules (but protect video player)
              const adModules = document.querySelectorAll('.ytp-ad-module, #player-ads, .video-ads, .ad-showing, .ad-interrupting, .ytp-ad-module-container');
              adModules.forEach(module => {
                if (module && module.parentNode) {
                  const isVideoPlayer = module.closest('.html5-video-player') || 
                                       module.closest('#movie_player') ||
                                       module.closest('.ytp-player-content') ||
                                       module.closest('video');
                  if (!isVideoPlayer && module.offsetParent !== null) {
                    module.style.cssText = 'display: none !important; visibility: hidden !important;';
                    module.remove();
                  }
                }
              });
              
              // AGGRESSIVE: Remove ad iframes
              const adIframes = document.querySelectorAll('iframe[src*="doubleclick"], iframe[src*="googlesyndication"], iframe[src*="imasdk"], iframe[src*="adserver"]');
              adIframes.forEach(iframe => {
                if (iframe && iframe.parentNode) {
                  const isVideoPlayer = iframe.closest('.html5-video-player') || 
                                       iframe.closest('#movie_player') ||
                                       iframe.closest('.ytp-player-content');
                  if (!isVideoPlayer) {
                    iframe.style.cssText = 'display: none !important;';
                    iframe.remove();
                  }
                }
              });
              
              // AGGRESSIVE: Hide ad text elements
              const adTexts = document.querySelectorAll('.ytp-ad-text, .ytp-ad-preview-text, .ytp-ad-overlay-ad-info, .ytp-ad-text-container');
              adTexts.forEach(text => {
                if (text && !text.closest('.html5-video-player') && !text.closest('#movie_player')) {
                  text.style.cssText = 'display: none !important; visibility: hidden !important;';
                }
              });
            } catch(e) {}
            return; // Exit early after YouTube-specific handling
          }
          
          // For non-YouTube sites, remove standard ads
          adSelectors.forEach(selector => {
            try {
              document.querySelectorAll(selector).forEach(el => {
                if (el && el.parentNode && blockedCount < maxBlocked) {
                  // Never remove video elements
                  const isVideo = el.tagName === 'VIDEO' || 
                                 el.closest('video') ||
                                 el.closest('.html5-video-player') ||
                                 el.closest('#movie_player');
                  if (!isVideo) {
                    el.style.display = 'none';
                    el.remove();
                    blockedCount++;
                  }
                }
              });
            } catch(e) {}
          });
        }
        
        // Remove ads immediately (with delay on YouTube)
        const isYouTubePage = window.location.hostname.includes('youtube.com') || 
                             window.location.hostname.includes('youtu.be');
        if (isYouTubePage) {
          // Wait 1 second on YouTube to let UI initialize, then remove ads aggressively
          setTimeout(function() {
            removeAds();
          }, 1000);
        } else {
          if (document.body) {
            removeAds();
          } else {
            document.addEventListener('DOMContentLoaded', removeAds);
          }
        }
        
        // Remove ads after DOM changes with MutationObserver (skip on YouTube)
        const isYouTubePage = window.location.hostname.includes('youtube.com') || 
                             window.location.hostname.includes('youtu.be');
        
        if (window.MutationObserver && !isYouTubePage) {
          // Only use MutationObserver on non-YouTube sites
          // YouTube has its own passive observer that only clicks buttons
          let debounceTimer = null;
          let mutationCount = 0;
          const observer = new MutationObserver(function(mutations) {
            mutationCount++;
            // Process less frequently for performance
            if (mutationCount % 20 !== 0) return;
            
            // Heavy debounce to avoid interfering
            if (debounceTimer) {
              clearTimeout(debounceTimer);
            }
            debounceTimer = setTimeout(function() {
              let shouldRemove = false;
              mutations.forEach(function(mutation) {
                if (mutation.addedNodes.length > 0) {
                  // Don't process if it's a video-related element
                  for (let i = 0; i < mutation.addedNodes.length; i++) {
                    const node = mutation.addedNodes[i];
                    if (node && node.nodeType === 1) { // Element node
                      const isVideoElement = node.closest && (
                        node.closest('.html5-video-player') || 
                        node.closest('#movie_player') ||
                        node.closest('video') ||
                        node.tagName === 'VIDEO'
                      );
                      if (!isVideoElement) {
                        shouldRemove = true;
                        break;
                      }
                    }
                  }
                }
              });
              if (shouldRemove) {
                removeAds();
              }
            }, 1000); // Heavy debounce 1 second
          });
          
          if (document.body) {
            observer.observe(document.body, {
              childList: true,
              subtree: false, // Only direct children for better performance
              attributes: false // Disable attribute watching for performance
            });
          }
        }
        
        // Block ad-related global functions and objects
        try {
          window.google_ad_client = null;
          window.google_ad_slot = null;
          window.google_ad_width = null;
          window.google_ad_height = null;
          window.google_ad_format = null;
          
          // Block Google Tag Manager
          window.googletag = window.googletag || {};
          window.googletag.cmd = window.googletag.cmd || [];
          const originalPush = window.googletag.cmd.push;
          window.googletag.cmd.push = function() {
            const args = Array.prototype.slice.call(arguments);
            const cmd = args[0];
            if (cmd && typeof cmd === 'function') {
              try {
                const cmdStr = cmd.toString().toLowerCase();
                if (cmdStr.includes('ad') || cmdStr.includes('doubleclick') || 
                    cmdStr.includes('googlesyndication') || cmdStr.includes('advertising')) {
                  return;
                }
              } catch(e) {}
            }
            return originalPush.apply(this, args);
          };
          
          // Block Google Analytics
          window.ga = function() {};
          window.gtag = function() {};
          window.dataLayer = window.dataLayer || [];
          window.dataLayer.push = function() {};
          
          // Block Facebook Pixel
          window.fbq = function() {};
          window._fbq = function() {};
        } catch(e) {}
        
        // Block fetch/XHR requests to ad domains (but allow ALL YouTube functionality)
        const originalFetch = window.fetch;
        window.fetch = function(...args) {
          const url = args[0];
          if (typeof url === 'string') {
            // NEVER block YouTube functionality - allow all YouTube URLs
            if (url.includes('videoplayback') || 
                url.includes('googlevideo.com') || 
                url.includes('youtube.com') ||
                url.includes('youtu.be') ||
                url.includes('youtubei/v1') ||
                url.includes('google.com') ||
                url.includes('gstatic.com')) {
              return originalFetch.apply(this, args);
            }
            // Block ad URLs only for non-YouTube domains
            if (shouldBlockUrl(url)) {
              return Promise.reject(new Error('Blocked by ad blocker'));
            }
          }
          return originalFetch.apply(this, args);
        };
        
        const originalXHROpen = XMLHttpRequest.prototype.open;
        XMLHttpRequest.prototype.open = function(method, url, ...args) {
          if (typeof url === 'string') {
            // NEVER block YouTube functionality - allow all YouTube URLs
            if (url.includes('videoplayback') || 
                url.includes('googlevideo.com') || 
                url.includes('youtube.com') ||
                url.includes('youtu.be') ||
                url.includes('youtubei/v1') ||
                url.includes('google.com') ||
                url.includes('gstatic.com')) {
              return originalXHROpen.apply(this, [method, url, ...args]);
            }
            // Block ad URLs only for non-YouTube domains
            if (shouldBlockUrl(url)) {
              return;
            }
          }
          return originalXHROpen.apply(this, [method, url, ...args]);
        };
        
        function shouldBlockUrl(url) {
          // BRAVE-STYLE: Aggressive blocking - don't block ANY YouTube or Google URLs
          // BUT: Block all ad endpoints aggressively
          const lowerUrl = url.toLowerCase();
          
          // NEVER block YouTube/Google domains - allow all functionality
          if (lowerUrl.includes('youtube.com') || 
              lowerUrl.includes('youtu.be') ||
              lowerUrl.includes('googlevideo.com') ||
              lowerUrl.includes('google.com') ||
              lowerUrl.includes('gstatic.com') ||
              lowerUrl.includes('googleapis.com')) {
            // BRAVE-STYLE: Block IMA SDK completely
            if (lowerUrl.includes('imasdk.googleapis.com')) {
              return true;
            }
            // BRAVE-STYLE: Block all known YouTube ad API endpoints
            if (lowerUrl.includes('/api/stats/ads') ||
                lowerUrl.includes('/ptracking') ||
                lowerUrl.includes('/pagead') ||
                lowerUrl.includes('/get_midroll_info') ||
                lowerUrl.includes('/get_preroll_info') ||
                lowerUrl.includes('/get_postroll_info') ||
                lowerUrl.includes('/get_ad_break_info') ||
                lowerUrl.includes('/get_ad_') ||
                lowerUrl.includes('/youtubei/v1/player/ad') ||
                lowerUrl.includes('/youtubei/v1/player/get_midroll') ||
                lowerUrl.includes('/youtubei/v1/player/get_preroll') ||
                lowerUrl.includes('/youtubei/v1/player/get_postroll') ||
                lowerUrl.includes('/youtubei/v1/player/get_ad_break') ||
                lowerUrl.includes('/youtubei/v1/player/get_ad_') ||
                lowerUrl.includes('/youtubei/v1/player/ad_') ||
                lowerUrl.includes('/api/stats/ads_') ||
                lowerUrl.includes('/api/stats/atr') ||
                lowerUrl.includes('/api/stats/clicktracking') ||
                lowerUrl.includes('/api/stats/player_ads') ||
                lowerUrl.includes('/get_ads') ||
                lowerUrl.includes('/get_video_ads') ||
                lowerUrl.includes('/csi_204') ||
                lowerUrl.includes('/pcs/activeview') ||
                lowerUrl.includes('/generate_204')) {
              return true; // Block all ad endpoints
            }
            return false; // Allow all other YouTube/Google URLs
          }
          
          // Block ad domains on other sites
          const adKeywords = [
            'doubleclick.net', 'googlesyndication.com',
            'adserver', 'advertising', 'advert'
          ];
          return adKeywords.some(keyword => lowerUrl.includes(keyword));
        }
        
        // YouTube-specific comprehensive ad blocking (Brave-style aggressive)
        if (window.location.hostname.includes('youtube.com') || 
            window.location.hostname.includes('youtu.be')) {
          
          // === CUSTOM ALGORITHM: INTERCEPT YOUTUBE PLAYER API ===
          // Intercept YouTube's internal player API to remove ads at the source
          (function() {
            try {
              // Intercept YouTube's player configuration
              const originalDefineProperty = Object.defineProperty;
              Object.defineProperty = function(obj, prop, descriptor) {
                if (prop === 'adBreakUrl' || prop === 'adBreak' || prop === 'ads' || prop === 'adTagUrl') {
                  return obj; // Block ad properties
                }
                return originalDefineProperty.apply(this, arguments);
              };
              
              // Intercept YouTube's player initialization
              if (window.ytInitialPlayerResponse) {
                const originalResponse = window.ytInitialPlayerResponse;
                Object.defineProperty(window, 'ytInitialPlayerResponse', {
                  get: function() {
                    const response = originalResponse;
                    if (response && response.adPlacements) {
                      response.adPlacements = [];
                    }
                    if (response && response.playerAds) {
                      response.playerAds = [];
                    }
                    if (response && response.adSlots) {
                      response.adSlots = [];
                    }
                    return response;
                  },
                  configurable: true
                });
              }
              
              // Intercept YouTube's player config
              const interceptPlayerConfig = function() {
                try {
                  // Find and modify player config
                  const scripts = document.querySelectorAll('script');
                  scripts.forEach(script => {
                    if (script.textContent && script.textContent.includes('ytInitialPlayerResponse')) {
                      try {
                        const content = script.textContent;
                        if (content.includes('adPlacements') || content.includes('playerAds')) {
                          // Try to modify the script content
                          const modified = content
                            .replace(/"adPlacements":\[[^\]]*\]/g, '"adPlacements":[]')
                            .replace(/"playerAds":\[[^\]]*\]/g, '"playerAds":[]')
                            .replace(/"adSlots":\[[^\]]*\]/g, '"adSlots":[]')
                            .replace(/"adBreakUrl":"[^"]*"/g, '"adBreakUrl":""')
                            .replace(/"adTagUrl":"[^"]*"/g, '"adTagUrl":""');
                          if (modified !== content) {
                            script.textContent = modified;
                          }
                        }
                      } catch(e) {}
                    }
                  });
                } catch(e) {}
              };
              
              // Run immediately and continuously
              interceptPlayerConfig();
              setInterval(interceptPlayerConfig, 500);
            } catch(e) {}
          })();
          
          // === CUSTOM ALGORITHM: MONITOR VIDEO PLAYBACK FOR ADS ===
          // Detect ads by monitoring video behavior patterns
          (function() {
            let lastVideoTime = 0;
            let adDetectionCount = 0;
            let isAdPlaying = false;
            
            const detectAdByBehavior = function() {
              try {
                const video = document.querySelector('video.html5-main-video');
                if (!video || video.readyState < 2) return;
                
                const currentTime = video.currentTime;
                const duration = video.duration;
                
                // Algorithm 1: Detect sudden time jumps (ad transitions)
                if (Math.abs(currentTime - lastVideoTime) > 5 && lastVideoTime > 0) {
                  // Likely ad transition - skip forward
                  if (currentTime < duration - 1) {
                    video.currentTime = Math.min(currentTime + 10, duration - 0.5);
                  }
                }
                
                // Algorithm 2: Detect short duration videos that might be ads
                if (duration > 0 && duration < 60 && currentTime < duration - 0.5) {
                  // Short video (< 1 min) - likely an ad, fast-forward
                  video.playbackRate = 16;
                  if (video.currentTime < duration - 0.5) {
                    video.currentTime = duration - 0.3;
                  }
                }
                
                // Algorithm 3: Detect paused state during what should be playback
                if (video.paused && !video.ended && duration > 0 && currentTime < duration - 1) {
                  // Check if it's an ad by looking for ad indicators
                  const hasAdIndicators = document.querySelector('.ad-showing, .ad-interrupting, .ytp-ad-module');
                  if (hasAdIndicators) {
                    video.play();
                    video.playbackRate = 16;
                  }
                }
                
                // Algorithm 4: Monitor for ad class changes
                const player = document.querySelector('.html5-video-player, #movie_player');
                if (player) {
                  const hasAdClass = player.classList.contains('ad-showing') || 
                                    player.classList.contains('ad-interrupting');
                  
                  if (hasAdClass && !isAdPlaying) {
                    // Ad just started
                    isAdPlaying = true;
                    video.playbackRate = 16;
                    adDetectionCount++;
                    
                    // Immediately try to skip
                    setTimeout(() => {
                      const skipBtn = document.querySelector('.ytp-ad-skip-button, button[class*="skip"]');
                      if (skipBtn) skipBtn.click();
                    }, 100);
                  } else if (!hasAdClass && isAdPlaying) {
                    // Ad ended
                    isAdPlaying = false;
                    if (video.playbackRate === 16) {
                      video.playbackRate = 1;
                    }
                  }
                  
                  // If ad is playing, continuously fast-forward
                  if (isAdPlaying || hasAdClass) {
                    video.playbackRate = 16;
                    if (video.paused) {
                      video.play();
                    }
                    // Jump forward aggressively
                    if (currentTime < duration - 0.5) {
                      const jumpAmount = Math.min(5, duration - currentTime - 0.3);
                      if (jumpAmount > 0.1) {
                        video.currentTime = currentTime + jumpAmount;
                      }
                    }
                  }
                }
                
                lastVideoTime = currentTime;
              } catch(e) {}
            };
            
            // Run detection very frequently
            setInterval(detectAdByBehavior, 50); // Every 50ms
          })();
          
          // === BRAVE-STYLE: INJECT CSS TO HIDE ADS IMMEDIATELY ===
          // Inject CSS rules to hide all ads at the style level (most aggressive)
          (function() {
            try {
              const style = document.createElement('style');
              style.id = 'brave-adblock-css';
              style.textContent = `
                /* Hide all YouTube ad elements */
                .ytp-ad-module,
                .ytp-ad-overlay-container,
                .ytp-ad-text-overlay,
                .ytp-ad-overlay-image,
                .ytp-ad-overlay-ad-info,
                .ytp-ad-module-container,
                #player-ads,
                .video-ads,
                .ytp-ad-text,
                .ytp-ad-preview-text,
                .ytp-ad-text-container,
                .ad-showing:not(video),
                .ad-interrupting:not(video),
                .ytp-ad-skip-button-container,
                .ytp-ad-overlay-close-container,
                [class*="ad-showing"]:not(video):not(.html5-video-player):not(#movie_player),
                [class*="ad-interrupting"]:not(video):not(.html5-video-player):not(#movie_player),
                [id*="ad"]:not(video):not(.html5-video-player):not(#movie_player),
                [class*="ytp-ad"]:not(video):not(.html5-video-player):not(#movie_player),
                iframe[src*="doubleclick"],
                iframe[src*="googlesyndication"],
                iframe[src*="imasdk"],
                iframe[src*="adserver"] {
                  display: none !important;
                  visibility: hidden !important;
                  opacity: 0 !important;
                  pointer-events: none !important;
                  height: 0 !important;
                  width: 0 !important;
                  position: absolute !important;
                  left: -9999px !important;
                  top: -9999px !important;
                }
                /* Hide ad overlays but keep video player visible */
                .html5-video-player .ytp-ad-module,
                .html5-video-player .ytp-ad-overlay-container,
                #movie_player .ytp-ad-module,
                #movie_player .ytp-ad-overlay-container {
                  display: none !important;
                  visibility: hidden !important;
                  opacity: 0 !important;
                  pointer-events: none !important;
                }
              `;
              if (document.head) {
                document.head.appendChild(style);
              } else {
                document.addEventListener('DOMContentLoaded', function() {
                  if (document.head) document.head.appendChild(style);
                });
              }
            } catch(e) {}
          })();
          
          // === CUSTOM ALGORITHM: INTERCEPT YOUTUBE'S INTERNAL FUNCTIONS ===
          // Block YouTube's ad-related internal functions
          (function() {
            try {
              // Intercept YouTube's player API
              if (window.ytplayer && window.ytplayer.config) {
                const originalConfig = window.ytplayer.config;
                Object.defineProperty(window.ytplayer, 'config', {
                  get: function() {
                    const config = originalConfig;
                    if (config && config.args) {
                      // Remove ad-related args
                      if (config.args.adPlacements) config.args.adPlacements = [];
                      if (config.args.playerAds) config.args.playerAds = [];
                      if (config.args.adSlots) config.args.adSlots = [];
                      if (config.args.adBreakUrl) config.args.adBreakUrl = '';
                      if (config.args.adTagUrl) config.args.adTagUrl = '';
                    }
                    return config;
                  },
                  configurable: true
                });
              }
              
              // Intercept YouTube's getVideoData function
              if (window.ytplayer && window.ytplayer.getVideoData) {
                const originalGetVideoData = window.ytplayer.getVideoData;
                window.ytplayer.getVideoData = function() {
                  const data = originalGetVideoData.apply(this, arguments);
                  if (data) {
                    data.adPlacements = [];
                    data.playerAds = [];
                    data.adSlots = [];
                  }
                  return data;
                };
              }
              
              // Intercept YouTube's player response
              const interceptPlayerResponse = function() {
                try {
                  // Find all script tags with player response
                  const scripts = document.querySelectorAll('script');
                  scripts.forEach(script => {
                    const text = script.textContent || '';
                    if (text.includes('ytInitialPlayerResponse') || text.includes('ytInitialData')) {
                      // Try to modify the response to remove ads
                      try {
                        // Use regex to remove ad-related JSON
                        const modified = text
                          .replace(/"adPlacements":\[[^\]]*\],?/g, '')
                          .replace(/"playerAds":\[[^\]]*\],?/g, '')
                          .replace(/"adSlots":\[[^\]]*\],?/g, '')
                          .replace(/"adBreakUrl":"[^"]*",?/g, '')
                          .replace(/"adTagUrl":"[^"]*",?/g, '')
                          .replace(/"adPlacement":\{[^}]*\},?/g, '')
                          .replace(/"adBreak":\{[^}]*\},?/g, '');
                        
                        if (modified !== text) {
                          script.textContent = modified;
                        }
                      } catch(e) {}
                    }
                  });
                } catch(e) {}
              };
              
              interceptPlayerResponse();
              setInterval(interceptPlayerResponse, 200);
            } catch(e) {}
          })();
          
          // === CUSTOM ALGORITHM: AGGRESSIVE NETWORK REQUEST INTERCEPTION ===
          // Intercept all network requests to block ad-related requests
          (function() {
            try {
              // Enhanced fetch interception
              const originalFetch = window.fetch;
              window.fetch = function(...args) {
                const url = args[0];
                if (typeof url === 'string') {
                  const lowerUrl = url.toLowerCase();
                  // Block ALL ad-related requests aggressively
                  if (lowerUrl.includes('imasdk') ||
                      lowerUrl.includes('/api/stats/ads') ||
                      lowerUrl.includes('/ptracking') ||
                      lowerUrl.includes('/pagead') ||
                      lowerUrl.includes('/get_midroll') ||
                      lowerUrl.includes('/get_preroll') ||
                      lowerUrl.includes('/get_postroll') ||
                      lowerUrl.includes('/get_ad_') ||
                      lowerUrl.includes('/youtubei/v1/player/ad') ||
                      lowerUrl.includes('adformat=') ||
                      lowerUrl.includes('adid=') ||
                      lowerUrl.includes('ad_id=')) {
                    return Promise.reject(new Error('Blocked: Ad request'));
                  }
                }
                return originalFetch.apply(this, args);
              };
              
              // Enhanced XHR interception
              const originalXHROpen = XMLHttpRequest.prototype.open;
              const originalXHRSend = XMLHttpRequest.prototype.send;
              
              XMLHttpRequest.prototype.open = function(method, url, ...args) {
                // Store URL for send interception
                this._url = url;
                
                if (typeof url === 'string') {
                  const lowerUrl = url.toLowerCase();
                  // Block ALL ad-related requests
                  if (lowerUrl.includes('imasdk') ||
                      lowerUrl.includes('/api/stats/ads') ||
                      lowerUrl.includes('/ptracking') ||
                      lowerUrl.includes('/pagead') ||
                      lowerUrl.includes('/get_midroll') ||
                      lowerUrl.includes('/get_preroll') ||
                      lowerUrl.includes('/get_postroll') ||
                      lowerUrl.includes('/get_ad_') ||
                      lowerUrl.includes('/youtubei/v1/player/ad') ||
                      lowerUrl.includes('adformat=') ||
                      lowerUrl.includes('adid=') ||
                      lowerUrl.includes('ad_id=')) {
                    this._blocked = true;
                    return; // Block the request
                  }
                }
                this._blocked = false;
                return originalXHROpen.apply(this, [method, url, ...args]);
              };
              
              // Intercept send method too
              XMLHttpRequest.prototype.send = function(...args) {
                if (this._blocked) {
                  return; // Don't send blocked requests
                }
                
                const url = this._url || '';
                if (typeof url === 'string') {
                  const lowerUrl = url.toLowerCase();
                  if (lowerUrl.includes('imasdk') ||
                      lowerUrl.includes('/api/stats/ads') ||
                      lowerUrl.includes('/ptracking') ||
                      lowerUrl.includes('/pagead') ||
                      lowerUrl.includes('/get_midroll') ||
                      lowerUrl.includes('/get_preroll') ||
                      lowerUrl.includes('/get_postroll') ||
                      lowerUrl.includes('/get_ad_') ||
                      lowerUrl.includes('/youtubei/v1/player/ad')) {
                    return; // Block the send
                  }
                }
                return originalXHRSend.apply(this, args);
              };
            } catch(e) {}
          })();
          
          // === BRAVE-STYLE: BLOCK IMA SDK BEFORE IT LOADS ===
          // Intercept and block IMA SDK at the earliest possible moment
          (function() {
            try {
              // Block google.ima namespace before it's created
              if (!window.google) window.google = {};
              if (!window.google.ima) {
                window.google.ima = {
                  AdsLoader: function() {
                    this.requestAds = function() {};
                    this.addEventListener = function() {};
                    this.removeEventListener = function() {};
                    this.contentComplete = function() {};
                  },
                  AdsManager: function() {
                    this.start = function() {};
                    this.init = function() {};
                    this.pause = function() {};
                    this.resume = function() {};
                    this.destroy = function() {};
                    this.getAdCuePoints = function() { return []; };
                    this.addEventListener = function() {};
                  },
                  AdDisplayContainer: function() {
                    this.initialize = function() {};
                    this.destroy = function() {};
                  },
                  AdErrorEvent: {},
                  AdsManagerLoadedEvent: {},
                };
              } else {
                // Block existing IMA SDK
                if (window.google.ima.AdsLoader) {
                  window.google.ima.AdsLoader.prototype.requestAds = function() {};
                  window.google.ima.AdsLoader.prototype.addEventListener = function() {};
                  window.google.ima.AdsLoader.prototype.removeEventListener = function() {};
                  window.google.ima.AdsLoader.prototype.contentComplete = function() {};
                }
                if (window.google.ima.AdsManager) {
                  window.google.ima.AdsManager.prototype.start = function() {};
                  window.google.ima.AdsManager.prototype.init = function() {};
                  window.google.ima.AdsManager.prototype.pause = function() {};
                  window.google.ima.AdsManager.prototype.resume = function() {};
                  window.google.ima.AdsManager.prototype.destroy = function() {};
                  window.google.ima.AdsManager.prototype.getAdCuePoints = function() { return []; };
                }
                if (window.google.ima.AdDisplayContainer) {
                  window.google.ima.AdDisplayContainer.prototype.initialize = function() {};
                  window.google.ima.AdDisplayContainer.prototype.destroy = function() {};
                }
              }
              
              // Continuously block IMA SDK (Brave-style - every 100ms for maximum effectiveness)
              setInterval(function() {
                try {
                  if (window.google && window.google.ima) {
                    if (window.google.ima.AdsLoader) {
                      window.google.ima.AdsLoader.prototype.requestAds = function() {};
                      window.google.ima.AdsLoader.prototype.addEventListener = function() {};
                    }
                    if (window.google.ima.AdsManager) {
                      window.google.ima.AdsManager.prototype.start = function() {};
                      window.google.ima.AdsManager.prototype.init = function() {};
                      window.google.ima.AdsManager.prototype.getAdCuePoints = function() { return []; };
                    }
                    if (window.google.ima.AdDisplayContainer) {
                      window.google.ima.AdDisplayContainer.prototype.initialize = function() {};
                    }
                  }
                } catch(e) {}
              }, 100); // Check every 100ms (Brave-style aggressive)
            } catch(e) {}
          })();
          
          // === BRAVE-STYLE: AGGRESSIVE AUTO-SKIP ADS ===
          // Ultra-fast ad detection and removal
          const skipAds = function() {
            try {
              // PROTECT: Never touch video player elements
              const videoPlayer = document.querySelector('.html5-video-player, #movie_player');
              const video = document.querySelector('video.html5-main-video');
              
              // Find and click skip button immediately (Brave-style - multiple selectors)
              const skipSelectors = [
                '.ytp-ad-skip-button',
                '.ytp-ad-skip-button-container button',
                'button[class*="skip"]',
                '.ytp-ad-skip-button-modern',
                'button[aria-label*="Skip"]',
                '.ytp-ad-skip-button-text',
                'button.ytp-ad-skip-button',
                '.ytp-ad-skip-button-container .ytp-ad-skip-button',
                '[class*="skip-ad"]',
                '[class*="skipAd"]',
              ];
              
              for (const selector of skipSelectors) {
                const skipBtn = document.querySelector(selector);
                if (skipBtn && skipBtn.offsetParent !== null && skipBtn.offsetWidth > 0 && skipBtn.offsetHeight > 0) {
                  try {
                skipBtn.click();
                    break; // Clicked, no need to check others
                  } catch(e) {}
                }
              }
              
              // Click close button on overlay ads
              const closeSelectors = [
                '.ytp-ad-overlay-close-button',
                'button[aria-label*="Close ad"]',
                'button[aria-label*="Close"]',
                '.ytp-ad-overlay-close-container button',
                '[class*="close-ad"]',
                '[class*="closeAd"]',
              ];
              
              for (const selector of closeSelectors) {
                const closeBtn = document.querySelector(selector);
                if (closeBtn && closeBtn.offsetParent !== null && closeBtn.offsetWidth > 0 && closeBtn.offsetHeight > 0) {
                  try {
                closeBtn.click();
                    break;
                  } catch(e) {}
                }
              }
              
              // BRAVE-STYLE: Aggressively hide ALL ad elements (but protect video player)
              // Use querySelectorAll with multiple selectors for comprehensive coverage
              const allAdSelectors = [
                '.ytp-ad-overlay-container',
                '.ytp-ad-module',
                '.ad-showing:not(video):not(.html5-video-player):not(#movie_player)',
                '.ad-interrupting:not(video):not(.html5-video-player):not(#movie_player)',
                '.ytp-ad-text-overlay',
                '.ytp-ad-overlay-image',
                '.ytp-ad-overlay-ad-info',
                '.ytp-ad-module-container',
                '#player-ads',
                '.video-ads',
                '.ytp-ad-text',
                '.ytp-ad-preview-text',
                '.ytp-ad-text-container',
                '.ytp-ad-skip-button-container',
                '.ytp-ad-overlay-close-container',
                '.ytp-ad-overlay-slot',
                '.ytp-ad-overlay',
                '.ytp-ad-image',
                '.ytp-ad-image-overlay',
                '[class*="ytp-ad"]:not(video):not(.html5-video-player):not(#movie_player)',
                '[class*="ad-overlay"]:not(video):not(.html5-video-player):not(#movie_player)',
                '[class*="ad-module"]:not(video):not(.html5-video-player):not(#movie_player)',
                '[id*="player-ads"]',
                'iframe[src*="doubleclick"]',
                'iframe[src*="googlesyndication"]',
                'iframe[src*="imasdk"]',
                'iframe[src*="adserver"]',
              ];
              
              // BRAVE-STYLE: Hide ads immediately and aggressively
              allAdSelectors.forEach(selector => {
                try {
                  const adElements = document.querySelectorAll(selector);
              adElements.forEach(el => {
                if (el && el.parentNode) {
                      // PROTECT: Never touch elements inside video player or video itself
                      const isInVideoPlayer = el.closest('.html5-video-player') || 
                                       el.closest('#movie_player') ||
                                       el.closest('.ytp-player-content') ||
                                             (videoPlayer && videoPlayer.contains(el));
                      
                      const isVideoElement = el.tagName === 'VIDEO' || 
                                           el === video ||
                                           (video && (video.contains(el) || video === el));
                      
                      // Hide ALL ad elements that are not video-related
                      if (!isInVideoPlayer && !isVideoElement) {
                        // Apply multiple hiding methods for maximum effectiveness
                        el.style.setProperty('display', 'none', 'important');
                        el.style.setProperty('visibility', 'hidden', 'important');
                        el.style.setProperty('opacity', '0', 'important');
                        el.style.setProperty('pointer-events', 'none', 'important');
                        el.style.setProperty('height', '0', 'important');
                        el.style.setProperty('width', '0', 'important');
                        el.style.setProperty('position', 'absolute', 'important');
                        el.style.setProperty('left', '-9999px', 'important');
                        el.style.setProperty('top', '-9999px', 'important');
                        el.setAttribute('hidden', 'true');
                        el.setAttribute('aria-hidden', 'true');
                        
                        // Try to remove, but if it fails, the hiding above will work
                        try {
                          if (el.parentNode && el.parentNode !== document.body) {
                    el.remove();
                  }
                        } catch(e) {
                          // Removal failed, but element is hidden
                        }
                      }
                    }
                  });
                } catch(e) {}
              });
              
              // BRAVE-STYLE: Also hide any elements with ad-related text content
              try {
                const allElements = document.querySelectorAll('*');
                allElements.forEach(el => {
                  if (el && el.parentNode && el.tagName !== 'VIDEO' && el.tagName !== 'SCRIPT' && el.tagName !== 'STYLE') {
                    const isInVideoPlayer = el.closest('.html5-video-player') || 
                                           el.closest('#movie_player') ||
                                           (videoPlayer && videoPlayer.contains(el));
                    
                    if (!isInVideoPlayer) {
                      const className = el.className || '';
                      const id = el.id || '';
                      const text = (el.textContent || '').toLowerCase();
                      
                      // Check for ad-related patterns
                      if ((className.includes('ad') && (className.includes('show') || className.includes('interrupt'))) ||
                          (id.includes('ad') && (id.includes('show') || id.includes('interrupt'))) ||
                          (text.includes('skip ad') || text.includes('advertisement') || text.includes('sponsored'))) {
                        // Only hide if it's clearly an ad element
                        if (el.offsetParent !== null && el.offsetHeight > 0 && el.offsetWidth > 0) {
                          el.style.setProperty('display', 'none', 'important');
                          el.style.setProperty('visibility', 'hidden', 'important');
                        }
                      }
                    }
                  }
                });
              } catch(e) {}
              
              // BRAVE-STYLE: 16x Speed Fast-Forward through video ads (no black screen)
              if (video && video.duration > 0 && video.readyState >= 2) {
                try {
                  // Detect if ad is showing
                  const adShowing = document.querySelector('.ad-showing, .ad-interrupting');
                  const isAdPlaying = adShowing && adShowing.offsetParent !== null;
                  
                  // Also check video player state for ads
                  const player = document.querySelector('.html5-video-player, #movie_player');
                  const hasAdClass = player && (
                    player.classList.contains('ad-showing') ||
                    player.classList.contains('ad-interrupting') ||
                    player.querySelector('.ad-showing, .ad-interrupting, .ytp-ad-module')
                  );
                  
                  if (isAdPlaying || hasAdClass) {
                    // BRAVE-STYLE: Set 16x playback speed for ads
                    if (video.playbackRate !== 16) {
                      video.playbackRate = 16;
                    }
                    
                    // Ensure video is playing (no black screen)
                    if (video.paused) {
                      video.play().catch(() => {});
                    }
                    
                    // Fast-forward to end of ad if it's short (< 3 minutes)
                    if (video.duration < 180 && video.currentTime < video.duration - 0.5) {
                      // Jump to near end (but leave small buffer to avoid black screen)
                      const targetTime = Math.max(0, video.duration - 0.3);
                      if (video.currentTime < targetTime - 0.2) {
                        video.currentTime = targetTime;
                      }
                    }
                  } else {
                    // No ad detected - ensure normal playback speed
                    if (video.playbackRate !== 1 && video.playbackRate !== 1.25 && 
                        video.playbackRate !== 1.5 && video.playbackRate !== 1.75 && 
                        video.playbackRate !== 2) {
                      // Only reset if it was at 16x (ad speed)
                      if (video.playbackRate === 16) {
                        video.playbackRate = 1; // Reset to normal speed
                      }
                    }
                  }
                } catch(e) {}
              }
            } catch(e) {}
          };
          
          // BRAVE-STYLE: Run immediately and very frequently for seamless experience
          skipAds(); // Run immediately
          setInterval(skipAds, 50); // Check every 50ms (ULTRA-AGGRESSIVE - instant ad removal)
          
          // === BRAVE-STYLE: CONTINUOUS AD HIDING (No ads visible) ===
          // Dedicated function that runs continuously to hide any visible ads
          const hideAllAds = function() {
            try {
              const videoPlayer = document.querySelector('.html5-video-player, #movie_player');
              const video = document.querySelector('video.html5-main-video');
              
              // Hide all ad containers immediately
              const adContainers = document.querySelectorAll(
                '.ytp-ad-module, .ytp-ad-overlay-container, .ad-showing, .ad-interrupting, ' +
                '#player-ads, .video-ads, .ytp-ad-text-overlay, .ytp-ad-module-container'
              );
              
              adContainers.forEach(container => {
                if (container && container.parentNode) {
                  const isInVideoPlayer = container.closest('.html5-video-player') || 
                                         container.closest('#movie_player') ||
                                         (videoPlayer && videoPlayer.contains(container));
                  const isVideo = container.tagName === 'VIDEO' || container === video;
                  
                  if (!isInVideoPlayer && !isVideo) {
                    container.style.setProperty('display', 'none', 'important');
                    container.style.setProperty('visibility', 'hidden', 'important');
                    container.style.setProperty('opacity', '0', 'important');
                    container.style.setProperty('height', '0', 'important');
                    container.style.setProperty('width', '0', 'important');
                  }
                }
              });
              
              // Hide all ad iframes
              const adIframes = document.querySelectorAll('iframe[src*="doubleclick"], iframe[src*="googlesyndication"], iframe[src*="imasdk"]');
              adIframes.forEach(iframe => {
                if (iframe && iframe.parentNode) {
                  const isInVideoPlayer = iframe.closest('.html5-video-player') || 
                                         iframe.closest('#movie_player') ||
                                         (videoPlayer && videoPlayer.contains(iframe));
                  if (!isInVideoPlayer) {
                    iframe.style.setProperty('display', 'none', 'important');
                    iframe.style.setProperty('visibility', 'hidden', 'important');
                    iframe.style.setProperty('opacity', '0', 'important');
                  }
                }
              });
            } catch(e) {}
          };
          
          // Run continuous ad hiding very frequently
          hideAllAds();
          setInterval(hideAllAds, 50); // Check every 50ms (ULTRA-AGGRESSIVE)
          
          // === CUSTOM ALGORITHM: ULTRA-AGGRESSIVE CONTINUOUS AD REMOVAL ===
          // Custom algorithm that runs continuously to remove ANY visible ads
          const ultraAggressiveAdRemoval = function() {
            try {
              const video = document.querySelector('video.html5-main-video');
              const player = document.querySelector('.html5-video-player, #movie_player');
              
              // Method 1: Remove all elements with ad-related classes/IDs
              const allAdElements = document.querySelectorAll('*');
              allAdElements.forEach(el => {
                if (!el || el.tagName === 'VIDEO' || el.tagName === 'SCRIPT' || el.tagName === 'STYLE') return;
                
                const className = (el.className || '').toString().toLowerCase();
                const id = (el.id || '').toString().toLowerCase();
                const text = (el.textContent || '').toLowerCase();
                
                // Check if element is ad-related
                const isAdElement = (
                  className.includes('ad-showing') ||
                  className.includes('ad-interrupting') ||
                  className.includes('ytp-ad') ||
                  className.includes('ad-overlay') ||
                  className.includes('ad-module') ||
                  id.includes('player-ads') ||
                  id.includes('ad-') ||
                  (text.includes('skip ad') && el.offsetHeight < 100) ||
                  (text.includes('advertisement') && el.offsetHeight < 200)
                );
                
                if (isAdElement) {
                  const isInVideoPlayer = el.closest('.html5-video-player') || 
                                         el.closest('#movie_player') ||
                                         (player && player.contains(el));
                  const isVideo = el === video || (video && video.contains(el));
                  
                  if (!isInVideoPlayer && !isVideo && el.offsetParent !== null) {
                    // Aggressively hide
                    el.style.setProperty('display', 'none', 'important');
                    el.style.setProperty('visibility', 'hidden', 'important');
                    el.style.setProperty('opacity', '0', 'important');
                    el.style.setProperty('height', '0', 'important');
                    el.style.setProperty('width', '0', 'important');
                    el.style.setProperty('position', 'absolute', 'important');
                    el.style.setProperty('left', '-9999px', 'important');
                    el.style.setProperty('top', '-9999px', 'important');
                    el.setAttribute('hidden', 'true');
                    try {
                      if (el.parentNode) el.remove();
                    } catch(e) {}
                  }
                }
              });
              
              // Method 2: Force-click skip buttons immediately
              const skipButtons = document.querySelectorAll(
                '.ytp-ad-skip-button, ' +
                '.ytp-ad-skip-button-container button, ' +
                'button[class*="skip"], ' +
                'button[aria-label*="Skip"], ' +
                '[class*="skip-ad"], ' +
                '[class*="skipAd"]'
              );
              
              skipButtons.forEach(btn => {
                if (btn && btn.offsetParent !== null && btn.offsetWidth > 0) {
                  try {
                    btn.click();
                    btn.style.setProperty('display', 'none', 'important');
                  } catch(e) {}
                }
              });
              
              // Method 3: Remove ad iframes aggressively
              const adIframes = document.querySelectorAll('iframe');
              adIframes.forEach(iframe => {
                if (iframe && iframe.src) {
                  const src = iframe.src.toLowerCase();
                  if (src.includes('doubleclick') ||
                      src.includes('googlesyndication') ||
                      src.includes('imasdk') ||
                      src.includes('adserver') ||
                      src.includes('advertising')) {
                    const isInVideoPlayer = iframe.closest('.html5-video-player') || 
                                           iframe.closest('#movie_player') ||
                                           (player && player.contains(iframe));
                    if (!isInVideoPlayer) {
                      iframe.style.setProperty('display', 'none', 'important');
                      iframe.style.setProperty('visibility', 'hidden', 'important');
                      try {
                        iframe.remove();
                      } catch(e) {}
                    }
                  }
                }
              });
              
              // Method 4: Monitor video and apply 16x speed if ad detected
              if (video && video.readyState >= 2) {
                const hasAdClass = player && (
                  player.classList.contains('ad-showing') ||
                  player.classList.contains('ad-interrupting')
                );
                const hasAdElement = document.querySelector('.ad-showing, .ad-interrupting, .ytp-ad-module');
                
                if (hasAdClass || (hasAdElement && hasAdElement.offsetParent !== null)) {
                  // Ad detected - apply 16x speed
                  if (video.playbackRate !== 16) {
                    video.playbackRate = 16;
                  }
                  if (video.paused) {
                      video.play();
                  }
                  // Jump forward aggressively
                  if (video.currentTime < video.duration - 0.5) {
                    const jumpAmount = Math.min(10, video.duration - video.currentTime - 0.3);
                    if (jumpAmount > 0.1) {
                      video.currentTime = video.currentTime + jumpAmount;
                    }
                  }
                } else if (video.playbackRate === 16) {
                  // No ad - reset speed
                  video.playbackRate = 1;
                }
              }
                    } catch(e) {}
          };
          
          // Run ultra-aggressive removal continuously
          ultraAggressiveAdRemoval();
          setInterval(ultraAggressiveAdRemoval, 25); // Every 25ms - MAXIMUM AGGRESSION
          
          // === BRAVE-STYLE: 16x SPEED AD FAST-FORWARD (No Black Screen) ===
          // Dedicated function to fast-forward ads at 16x speed
          const fastForwardAds = function() {
            try {
              const video = document.querySelector('video.html5-main-video');
              if (!video || video.readyState < 2) return;
              
              // Multiple ways to detect ads
              const adShowing = document.querySelector('.ad-showing, .ad-interrupting');
              const player = document.querySelector('.html5-video-player, #movie_player');
              const hasAdModule = document.querySelector('.ytp-ad-module, #player-ads, .video-ads');
              
              const isAdActive = (
                (adShowing && adShowing.offsetParent !== null) ||
                (player && (player.classList.contains('ad-showing') || player.classList.contains('ad-interrupting'))) ||
                (hasAdModule && hasAdModule.offsetParent !== null)
              );
              
              if (isAdActive && video.duration > 0) {
                // BRAVE-STYLE: Apply 16x speed to ads
                if (video.playbackRate !== 16) {
                  try {
                    video.playbackRate = 16;
                  } catch(e) {
                    // Fallback: try setting multiple times
                    setTimeout(() => {
                      try { video.playbackRate = 16; } catch(e2) {}
                    }, 50);
                  }
                }
                
                // Ensure video is playing (prevent black screen)
                if (video.paused) {
                  video.play().catch(() => {});
                }
                
                // Fast-forward to end if ad is short
                if (video.duration < 300) { // Up to 5 minutes
                  const timeRemaining = video.duration - video.currentTime;
                  if (timeRemaining > 0.5) {
                    // Jump forward aggressively but leave small buffer
                    const jumpAmount = Math.min(timeRemaining - 0.3, 2); // Jump up to 2 seconds at a time
                    if (jumpAmount > 0.1) {
                      try {
                        video.currentTime = Math.min(video.currentTime + jumpAmount, video.duration - 0.3);
                      } catch(e) {}
                    }
                  }
                }
              } else {
                // No ad - ensure normal playback speed (but preserve user's speed setting)
                if (video.playbackRate === 16) {
                  // Only reset if it was at ad speed
                  try {
                    video.playbackRate = 1;
                  } catch(e) {}
                }
              }
            } catch(e) {}
          };
          
          // Run 16x speed fast-forward very frequently for instant response
          fastForwardAds(); // Run immediately
          setInterval(fastForwardAds, 100); // Check every 100ms for instant 16x speed application
          
          // === BRAVE-STYLE: VIDEO EVENT LISTENER FOR 16x SPEED ===
          // Monitor video events to apply 16x speed immediately when ads start
          setTimeout(function() {
            const video = document.querySelector('video.html5-main-video');
            if (video) {
              // Listen for timeupdate to continuously apply 16x speed during ads
              video.addEventListener('timeupdate', function() {
                try {
                  const adShowing = document.querySelector('.ad-showing, .ad-interrupting');
                  const player = document.querySelector('.html5-video-player, #movie_player');
                  const isAdActive = (
                    (adShowing && adShowing.offsetParent !== null) ||
                    (player && (player.classList.contains('ad-showing') || player.classList.contains('ad-interrupting')))
                  );
                  
                  if (isAdActive && video.playbackRate !== 16) {
                    video.playbackRate = 16;
                    // Ensure playing to prevent black screen
                    if (video.paused) {
                      video.play().catch(() => {});
                    }
                  } else if (!isAdActive && video.playbackRate === 16) {
                    // Reset to normal speed when ad ends
                    video.playbackRate = 1;
                  }
                } catch(e) {}
              }, { passive: true });
              
              // Listen for play event to catch ads that start playing
              video.addEventListener('play', function() {
                setTimeout(fastForwardAds, 50);
              }, { passive: true });
              
              // Listen for loadedmetadata to catch ads early
              video.addEventListener('loadedmetadata', function() {
                setTimeout(fastForwardAds, 50);
              }, { passive: true });
            }
          }, 1000); // Wait 1 second for video to load
          
          // === BRAVE-STYLE: BLOCK AD SCRIPTS BEFORE THEY LOAD ===
          // Intercept and remove ad scripts immediately
          const removeAdScripts = function() {
            try {
              // Block IMA SDK scripts
              const imaScripts = document.querySelectorAll('script[src*="imasdk"], script[src*="ima3"], script[src*="ima"]');
              imaScripts.forEach(script => {
                if (script && script.src) {
                  const isVideoPlayer = script.closest('.html5-video-player') || 
                                       script.closest('#movie_player');
                  if (!isVideoPlayer && script.parentNode) {
                    script.remove();
                  }
                }
              });
              
              // Block ad network scripts
              const adScripts = document.querySelectorAll('script[src*="doubleclick"], script[src*="googlesyndication"], script[src*="adserver"], script[src*="advertising"]');
              adScripts.forEach(script => {
                if (script && script.src) {
                  const isVideoPlayer = script.closest('.html5-video-player') || 
                                       script.closest('#movie_player');
                  if (!isVideoPlayer && script.parentNode) {
                    script.remove();
                  }
                }
              });
            } catch(e) {}
          };
          removeAdScripts();
          setInterval(removeAdScripts, 500); // Check every 500ms (Brave-style aggressive)
          
          // === BRAVE-STYLE: ULTRA-FAST MUTATION OBSERVER FOR DYNAMIC ADS ===
          // Immediate ad detection and removal
          setTimeout(function() {
            if (window.MutationObserver) {
              let debounceTimer = null;
              let mutationCount = 0;
              const videoPlayer = document.querySelector('.html5-video-player, #movie_player');
              
              const ytObserver = new MutationObserver(function(mutations) {
                mutationCount++;
                // Process every mutation for maximum responsiveness (Brave-style)
                if (mutationCount % 2 !== 0) return; // Process every 2nd mutation for performance
                
                // Ultra-light debounce for instant response
                if (debounceTimer) {
                  clearTimeout(debounceTimer);
                }
                debounceTimer = setTimeout(function() {
                  // PROTECT: Never touch video player
                  if (videoPlayer) {
                    // Skip if mutation is in video player
                    let isInVideoPlayer = false;
                    for (const mutation of mutations) {
                      if (mutation.target && videoPlayer.contains(mutation.target)) {
                        isInVideoPlayer = true;
                        break;
                      }
                      if (mutation.addedNodes) {
                        for (const node of mutation.addedNodes) {
                          if (node && videoPlayer.contains(node)) {
                            isInVideoPlayer = true;
                            break;
                          }
                        }
                      }
                    }
                    if (isInVideoPlayer) return; // Skip processing if in video player
                  }
                  
                  // Fast skip button click
                  const skipBtn = document.querySelector('.ytp-ad-skip-button, .ytp-ad-skip-button-container button, button[class*="skip"]');
                  if (skipBtn && skipBtn.offsetParent !== null && skipBtn.offsetWidth > 0 && skipBtn.offsetHeight > 0) {
                    try {
                    skipBtn.click();
                    } catch(e) {}
                  }
                  
                  // Fast close button click
                  const closeBtn = document.querySelector('.ytp-ad-overlay-close-button, button[aria-label*="Close"]');
                  if (closeBtn && closeBtn.offsetParent !== null && closeBtn.offsetWidth > 0 && closeBtn.offsetHeight > 0) {
                    try {
                    closeBtn.click();
                    } catch(e) {}
                  }
                  
                  // BRAVE-STYLE: Aggressively hide ad elements as they appear
                  const adElements = document.querySelectorAll('.ytp-ad-overlay-container, .ytp-ad-module, .ad-showing, .ad-interrupting, .ytp-ad-text-overlay, #player-ads, .video-ads');
                  adElements.forEach(el => {
                    if (el && el.parentNode) {
                      // PROTECT: Never remove elements inside video player
                      const isInVideoPlayer = el.closest('.html5-video-player') || 
                                           el.closest('#movie_player') ||
                                             el.closest('.ytp-player-content') ||
                                             (videoPlayer && videoPlayer.contains(el));
                      
                      const isVideo = el.tagName === 'VIDEO';
                      
                      if (!isInVideoPlayer && !isVideo) {
                        // Apply aggressive hiding
                        el.style.setProperty('display', 'none', 'important');
                        el.style.setProperty('visibility', 'hidden', 'important');
                        el.style.setProperty('opacity', '0', 'important');
                        el.style.setProperty('pointer-events', 'none', 'important');
                        el.style.setProperty('height', '0', 'important');
                        el.style.setProperty('width', '0', 'important');
                        try {
                        el.remove();
                        } catch(e) {}
                      }
                    }
                  });
                  
                  // BRAVE-STYLE: Apply 16x speed when ads are detected via mutation
                  const video = document.querySelector('video.html5-main-video');
                  if (video && video.readyState >= 2) {
                    const adDetected = document.querySelector('.ad-showing, .ad-interrupting, .ytp-ad-module');
                    if (adDetected && adDetected.offsetParent !== null && video.playbackRate !== 16) {
                      try {
                        video.playbackRate = 16;
                        if (video.paused) {
                          video.play().catch(() => {});
                        }
                      } catch(e) {}
                    }
                  }
                  
                  // Hide ads immediately when detected via mutation (hideAllAds runs on interval too)
                  const adContainers = document.querySelectorAll('.ytp-ad-module, .ytp-ad-overlay-container, .ad-showing, .ad-interrupting');
                  adContainers.forEach(container => {
                    if (container && container.parentNode) {
                      const isInVideoPlayer = container.closest('.html5-video-player') || 
                                             container.closest('#movie_player');
                      const isVideo = container.tagName === 'VIDEO';
                      if (!isInVideoPlayer && !isVideo) {
                        container.style.setProperty('display', 'none', 'important');
                        container.style.setProperty('visibility', 'hidden', 'important');
                        container.style.setProperty('opacity', '0', 'important');
                      }
                    }
                  });
                }, 100); // Ultra-light debounce 100ms (Brave-style - instant response)
              });
              
              if (document.body) {
                ytObserver.observe(document.body, {
                  childList: true,
                  subtree: true, // Watch entire subtree to catch all ads
                  attributes: true, // Watch attributes to catch ad class changes
                  attributeFilter: ['class', 'id', 'style'] // Watch class, id, and style changes
                });
              }
            }
          }, 500); // Start after 500ms (Brave-style - start fast)
          
          // === OVERRIDE YOUTUBE PLAYER CONFIG ===
          // REMOVED: JSON.parse override was breaking video initialization
          // Let YouTube handle its own config, we'll just skip ads when they appear
          
          // === BLOCK YOUTUBE PREMIUM PROMPTS (passive - only hide, don't remove) ===
          // Only hide premium prompts, don't remove to avoid breaking UI
          const blockPremiumPrompts = function() {
            try {
              const prompts = document.querySelectorAll('[class*="premium"], [id*="premium"], [class*="upsell"], [id*="upsell"]');
              prompts.forEach(prompt => {
                if (prompt && prompt.innerText && 
                    (prompt.innerText.includes('Premium') || 
                     prompt.innerText.includes('Try YouTube') ||
                     prompt.innerText.includes('Get YouTube'))) {
                  // Only hide, don't remove to avoid breaking UI
                  prompt.style.display = 'none';
                  prompt.style.visibility = 'hidden';
                }
              });
            } catch(e) {}
          };
          setTimeout(blockPremiumPrompts, 3000); // Wait before blocking prompts
          setInterval(blockPremiumPrompts, 5000); // Check every 5 seconds (less frequent)
        }
        
        // Remove ads on page visibility change
        document.addEventListener('visibilitychange', function() {
          if (!document.hidden) {
            removeAds();
          }
        });
        
        // Remove ads periodically as a fallback (BRAVE-STYLE AGGRESSIVE on YouTube)
        setTimeout(function() {
          const isYouTube = window.location.hostname.includes('youtube.com') || 
                           window.location.hostname.includes('youtu.be');
          
          if (isYouTube) {
            // BRAVE-STYLE: On YouTube, run full aggressive ad removal very frequently
            setInterval(removeAds, 500); // Check every 500ms for ads (Brave-style aggressive)
          } else {
            // On other sites, remove ads periodically
            setInterval(removeAds, 10000); // Every 10 seconds
          }
        }, 500); // Start after 500ms (Brave-style - start fast)
      })();
    ''';
  }

  Map<String, dynamic> getStatistics() {
    return {
      'blockedCount': state.blockedCount,
      'filterRulesCount': _filterRules.length,
      'blockedDomainsCount': _blockedDomains.length,
      'blockedPatternsCount': _blockedPatterns.length,
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
