import 'package:flutter/material.dart';

class AppSettingsEntity {
  final ThemeMode themeMode;
  final String searchEngine;
  final String userAgent;
  final bool javascriptEnabled;
  final bool adBlockEnabled;
  final bool doNotTrack;
  final bool httpsOnly;
  final double fontSize;
  final bool showImages;
  final String downloadPath;
  final int cacheSize;
  final bool fingerprintLockEnabled;

  AppSettingsEntity({
    required this.themeMode,
    required this.searchEngine,
    required this.userAgent,
    required this.javascriptEnabled,
    required this.adBlockEnabled,
    required this.doNotTrack,
    required this.httpsOnly,
    required this.fontSize,
    required this.showImages,
    required this.downloadPath,
    required this.cacheSize,
    required this.fingerprintLockEnabled,
  });

  factory AppSettingsEntity.defaultSettings() {
    return AppSettingsEntity(
      themeMode: ThemeMode.system,
      searchEngine: 'google',
      userAgent: 'mobile',
      javascriptEnabled: true,
      adBlockEnabled: true,
      doNotTrack: true,
      httpsOnly: false,
      fontSize: 16.0,
      showImages: true,
      downloadPath: '',
      cacheSize: 100,
      fingerprintLockEnabled: false,
    );
  }

  AppSettingsEntity copyWith({
    ThemeMode? themeMode,
    String? searchEngine,
    String? userAgent,
    bool? javascriptEnabled,
    bool? adBlockEnabled,
    bool? doNotTrack,
    bool? httpsOnly,
    double? fontSize,
    bool? showImages,
    String? downloadPath,
    int? cacheSize,
    bool? fingerprintLockEnabled,
  }) {
    return AppSettingsEntity(
      themeMode: themeMode ?? this.themeMode,
      searchEngine: searchEngine ?? this.searchEngine,
      userAgent: userAgent ?? this.userAgent,
      javascriptEnabled: javascriptEnabled ?? this.javascriptEnabled,
      adBlockEnabled: adBlockEnabled ?? this.adBlockEnabled,
      doNotTrack: doNotTrack ?? this.doNotTrack,
      httpsOnly: httpsOnly ?? this.httpsOnly,
      fontSize: fontSize ?? this.fontSize,
      showImages: showImages ?? this.showImages,
      downloadPath: downloadPath ?? this.downloadPath,
      cacheSize: cacheSize ?? this.cacheSize,
      fingerprintLockEnabled: fingerprintLockEnabled ?? this.fingerprintLockEnabled,
    );
  }
}

