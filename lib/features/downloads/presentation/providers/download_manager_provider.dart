import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import '../../domain/entities/download_entity.dart';
import '../../data/models/download_model.dart';
import '../../../../core/constants/storage_constants.dart';
import '../../../../core/storage/hive_config.dart';
import '../../../../core/services/notification_service.dart';

// Download state
class DownloadManagerState {
  final List<DownloadEntity> downloads;
  final Map<String, double> progress;
  final Map<String, CancelToken> cancelTokens;
  final bool hasStoragePermission;
  final String? permissionError;

  DownloadManagerState({
    this.downloads = const [],
    this.progress = const {},
    this.cancelTokens = const {},
    this.hasStoragePermission = false,
    this.permissionError,
  });

  DownloadManagerState copyWith({
    List<DownloadEntity>? downloads,
    Map<String, double>? progress,
    Map<String, CancelToken>? cancelTokens,
    bool? hasStoragePermission,
    String? permissionError,
  }) {
    return DownloadManagerState(
      downloads: downloads ?? this.downloads,
      progress: progress ?? this.progress,
      cancelTokens: cancelTokens ?? this.cancelTokens,
      hasStoragePermission: hasStoragePermission ?? this.hasStoragePermission,
      permissionError: permissionError ?? this.permissionError,
    );
  }
}

// Download manager notifier
class DownloadManagerNotifier extends StateNotifier<DownloadManagerState> {
  late Box _downloadsBox;

  DownloadManagerNotifier() : super(DownloadManagerState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    // Initialize downloads box first
    try {
      _downloadsBox = await HiveConfig.openBox(StorageConstants.downloadsBox);
    } catch (e) {
      // If box initialization fails, create a temporary box
      _downloadsBox = await Hive.openBox(StorageConstants.downloadsBox);
    }
    _checkStoragePermission();
    await _loadDownloads();
  }

  Future<void> _loadDownloads() async {
    try {
      final List<dynamic> downloadsData = _downloadsBox.get('downloads', defaultValue: <Map>[]) as List;
      
      final List<DownloadEntity> downloads = downloadsData
          .map((data) {
            try {
              if (data is Map) {
                final model = DownloadModel.fromMap(Map<String, dynamic>.from(data));
                return model.toEntity();
              } else if (data is DownloadModel) {
                return data.toEntity();
              }
              return null;
            } catch (e) {
              return null;
            }
          })
          .whereType<DownloadEntity>()
          .toList();

      // Filter out downloads where files don't exist anymore
      final List<DownloadEntity> validDownloads = [];
      for (final download in downloads) {
        if (download.savedPath != null && download.savedPath!.isNotEmpty) {
          final file = File(download.savedPath!);
          if (await file.exists() || download.status == DownloadStatus.downloading) {
            validDownloads.add(download);
          }
        } else if (download.status == DownloadStatus.downloading || download.status == DownloadStatus.failed) {
          // Keep downloads that are in progress or failed (might not have file yet)
          validDownloads.add(download);
        } else if (download.status == DownloadStatus.completed) {
          // Remove completed downloads without files
          continue;
        } else {
          validDownloads.add(download);
        }
      }

      // Save cleaned list
      if (validDownloads.length != downloads.length) {
        await _saveDownloads(validDownloads);
      }

      state = state.copyWith(downloads: validDownloads);
    } catch (e) {
      // If loading fails, start with empty list
      state = state.copyWith(downloads: []);
    }
  }

  Future<void> _saveDownloads(List<DownloadEntity> downloads) async {
    try {
      // Ensure box is initialized
      if (!_downloadsBox.isOpen) {
        _downloadsBox = await HiveConfig.openBox(StorageConstants.downloadsBox);
      }
      final List<Map<String, dynamic>> downloadsData = downloads
          .map((entity) => DownloadModel.fromEntity(entity).toMap())
          .toList();
      await _downloadsBox.put('downloads', downloadsData);
    } catch (e) {
      // Silently fail - downloads will still work in memory
    }
  }

  Future<void> _checkStoragePermission() async {
    if (Platform.isAndroid) {
      try {
        final androidVersion = await _getAndroidVersion();
        bool hasPermission = false;
        
        if (androidVersion >= 33) {
          // Android 13+ (including Android 15) - scoped storage
          // App's external storage directory is always accessible without permission
          // We don't need to request storage permission, just check if we can access app directory
          try {
            final dir = await getExternalStorageDirectory();
            hasPermission = dir != null; // Always true on Android 13+
          } catch (e) {
            hasPermission = false;
          }
        } else {
          // Android <13 - check storage permission
          // Note: We use Permission.storage which is the old storage permission
          // This does NOT request media permissions (photos/videos)
          try {
            final storage = await Permission.storage.status;
            hasPermission = storage.isGranted;
          } catch (e) {
            // If permission check fails, assume we can access app directory
            try {
              final dir = await getExternalStorageDirectory();
              hasPermission = dir != null;
            } catch (e2) {
              hasPermission = false;
            }
          }
        }
        
        state = state.copyWith(hasStoragePermission: hasPermission);
      } catch (e) {
        // Fallback: check if we can access app directory (works on Android 10+)
        try {
          final dir = await getExternalStorageDirectory();
          state = state.copyWith(hasStoragePermission: dir != null);
        } catch (e2) {
          state = state.copyWith(hasStoragePermission: false);
        }
      }
    } else {
      // iOS - photos permission for images
      state = state.copyWith(hasStoragePermission: true);
    }
  }

  Future<int> _getAndroidVersion() async {
    try {
      // Try to get Android version from Platform.version
      // Format is usually like "Android 15 (API 35)" or "Linux 5.x.x-xxx-generic #xxx SMP ..."
      final versionString = Platform.version;
      
      // Try to match API level first (more reliable)
      final apiMatch = RegExp(r'API (\d+)', caseSensitive: false).firstMatch(versionString);
      if (apiMatch != null) {
        return int.parse(apiMatch.group(1)!);
      }
      
      // Fallback: try to match Android version number
      final versionMatch = RegExp(r'Android (\d+)', caseSensitive: false).firstMatch(versionString);
      if (versionMatch != null) {
        final version = int.parse(versionMatch.group(1)!);
        // Convert Android version to API level
        // Android 15 = API 35, Android 14 = API 34, Android 13 = API 33, etc.
        if (version >= 15) return 35;
        if (version >= 14) return 34;
        if (version >= 13) return 33;
        if (version >= 12) return 31;
        if (version >= 11) return 30;
        if (version >= 10) return 29;
        if (version >= 9) return 28;
        return 28; // Default to API 28
      }
    } catch (e) {
      // If parsing fails, assume newer version (Android 13+)
    }
    // Default to Android 13 (API 33) to be safe with scoped storage
    return 33;
  }

  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      try {
        final androidVersion = await _getAndroidVersion();
        bool granted = false;
        
        if (androidVersion >= 33) {
          // Android 13+ (including Android 15) - scoped storage
          // We don't need to request storage permission on Android 13+
          // App's external storage directory is always accessible
          // Just verify we can access it
          try {
            final dir = await getExternalStorageDirectory();
            granted = dir != null; // Always true on Android 13+
          } catch (e) {
            granted = false;
          }
        } else {
          // Android <13 - request storage permission
          // Note: Permission.storage is the old storage permission (not media permissions)
          // This does NOT request READ_MEDIA_IMAGES, READ_MEDIA_VIDEO, or READ_MEDIA_AUDIO
          try {
            final storageStatus = await Permission.storage.request();
            granted = storageStatus.isGranted;
          } catch (e) {
            // If permission request fails, try to access app directory directly
            try {
              final dir = await getExternalStorageDirectory();
              granted = dir != null;
            } catch (e2) {
              granted = false;
            }
          }
        }
        
        state = state.copyWith(
          hasStoragePermission: granted,
          permissionError: granted ? null : 'Storage access unavailable.',
        );
        
        // Re-check permission status after request
        await _checkStoragePermission();
        
        return granted;
      } catch (e) {
        // Fallback: check if we can access app directory (works on Android 10+)
        try {
          final dir = await getExternalStorageDirectory();
          final canAccess = dir != null;
          state = state.copyWith(
            hasStoragePermission: canAccess,
            permissionError: canAccess ? null : 'Failed to access storage: $e',
          );
          return canAccess;
        } catch (e2) {
          state = state.copyWith(
            hasStoragePermission: false,
            permissionError: 'Failed to access storage: $e',
          );
          return false;
        }
      }
    } else {
      // iOS
      state = state.copyWith(hasStoragePermission: true);
      return true;
    }
  }

  Future<String?> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      try {
        final androidVersion = await _getAndroidVersion();
        final directory = await getExternalStorageDirectory();
        
        if (directory != null) {
          // For Android 13+, we can only use app's external storage (scoped storage)
          // For older versions, try public Downloads folder if we have permission
          if (androidVersion >= 33) {
            // Android 13+ - try to use public Downloads folder first
            // If that fails, use app's Downloads folder
            try {
              // Try to access public Downloads folder
              final externalPath = directory.path;
              final parts = externalPath.split('/');
              int androidDataIndex = -1;
              for (int i = 0; i < parts.length; i++) {
                if (parts[i] == 'Android' && i + 1 < parts.length && parts[i + 1] == 'data') {
                  androidDataIndex = i;
                  break;
                }
              }
              
              if (androidDataIndex > 0) {
                final basePath = parts.sublist(0, androidDataIndex).join('/');
                final downloadsPath = path.join(basePath, 'Download');
                final downloadsDir = Directory(downloadsPath);
                
                // Try to use public Downloads folder
                if (await downloadsDir.exists() || await _canCreateDirectory(downloadsDir)) {
                  // Verify write access
                  try {
                    final testFile = File(path.join(downloadsPath, '.void_test_${DateTime.now().millisecondsSinceEpoch}'));
                    await testFile.writeAsString('test');
                    await testFile.delete();
                    return downloadsPath;
                  } catch (e) {
                    // Can't write to public Downloads, fall through to app directory
                  }
                }
              }
            } catch (e) {
              // Fall through to app directory
            }
            
            // Fallback: use app's Downloads folder (always accessible, no permission needed)
            final appDownloadsDir = Directory(path.join(directory.path, 'Downloads'));
            if (!await appDownloadsDir.exists()) {
              await appDownloadsDir.create(recursive: true);
            }
            return appDownloadsDir.path;
          } else {
            // Android <13 - try public Downloads folder first if we have permission
            if (state.hasStoragePermission) {
              try {
                final externalPath = directory.path;
                final parts = externalPath.split('/');
                int androidDataIndex = -1;
                for (int i = 0; i < parts.length; i++) {
                  if (parts[i] == 'Android' && i + 1 < parts.length && parts[i + 1] == 'data') {
                    androidDataIndex = i;
                    break;
                  }
                }
                
                if (androidDataIndex > 0) {
                  final basePath = parts.sublist(0, androidDataIndex).join('/');
                  final downloadsPath = path.join(basePath, 'Download');
                  final downloadsDir = Directory(downloadsPath);
                  
                  // Try to use public Downloads folder
                  if (await downloadsDir.exists() || await _canCreateDirectory(downloadsDir)) {
                    // Verify write access
                    try {
                      final testFile = File(path.join(downloadsPath, '.void_test_${DateTime.now().millisecondsSinceEpoch}'));
                      await testFile.writeAsString('test');
                      await testFile.delete();
                      return downloadsPath;
                    } catch (e) {
                      // Can't write, fall through to app directory
                    }
                  }
                }
              } catch (e) {
                // Fall through to app directory
              }
            }
            
            // Fallback: use app's Downloads folder
            final appDownloadsDir = Directory(path.join(directory.path, 'Downloads'));
            if (!await appDownloadsDir.exists()) {
              await appDownloadsDir.create(recursive: true);
            }
            return appDownloadsDir.path;
          }
        }
      } catch (e) {
        // Fallback to app documents directory
      }
      
      // Final fallback: use app documents directory
      try {
        final directory = await getApplicationDocumentsDirectory();
        final downloadsDir = Directory(path.join(directory.path, 'Downloads'));
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        return downloadsDir.path;
      } catch (e) {
        return null;
      }
    } else {
      // iOS
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(path.join(directory.path, 'Downloads'));
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      return downloadsDir.path;
    }
  }

  Future<bool> _canCreateDirectory(Directory dir) async {
    try {
      await dir.create(recursive: true);
      return await dir.exists();
    } catch (e) {
      return false;
    }
  }


  /// Get file extension from Content-Type header
  Future<String> _getExtensionFromContentType(String url) async {
    try {
      final dio = Dio();
      // Use HEAD request with timeout to get Content-Type
      final response = await dio.head(
        url,
        options: Options(
          followRedirects: true,
          validateStatus: (status) => status! < 500, // Accept redirects and client errors
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      ).timeout(const Duration(seconds: 5));
      
      // Try multiple ways to get Content-Type header
      String? contentType;
      
      // Method 1: Using value() method
      try {
        contentType = response.headers.value('content-type');
      } catch (e) {
        // Try alternative
      }
      
      // Method 2: Direct map access (case insensitive)
      if (contentType == null || contentType.isEmpty) {
        final headers = response.headers.map;
        for (final key in headers.keys) {
          if (key.toLowerCase() == 'content-type') {
            final values = headers[key];
            if (values != null && values.isNotEmpty) {
              contentType = values.first;
              break;
            }
          }
        }
      }
      
      // Method 3: Try Content-Type with capital C
      if (contentType == null || contentType.isEmpty) {
        try {
          contentType = response.headers.map['Content-Type']?.first;
        } catch (e) {
          // Ignore
        }
      }
      
      if (contentType != null && contentType.isNotEmpty) {
        // Remove charset and other parameters
        final cleanType = contentType.split(';').first.trim().toLowerCase();
        final ext = _mapContentTypeToExtension(cleanType);
        if (ext.isNotEmpty && ext != '.bin') {
          return ext;
        }
      }
    } catch (e) {
      // If HEAD request fails, silently continue - will try URL extraction
      // This is expected for some servers that don't support HEAD requests
    }
    return '';
  }

  /// Map Content-Type to file extension
  String _mapContentTypeToExtension(String contentType) {
    final type = contentType.toLowerCase().split(';').first.trim();
    
    // Audio
    if (type.contains('audio/mpeg') || type.contains('audio/mp3')) return '.mp3';
    if (type.contains('audio/wav')) return '.wav';
    if (type.contains('audio/ogg')) return '.ogg';
    if (type.contains('audio/aac')) return '.aac';
    if (type.contains('audio/flac')) return '.flac';
    if (type.contains('audio/webm')) return '.webm';
    if (type.contains('audio/')) return '.mp3'; // Default audio
    
    // Video
    if (type.contains('video/mp4')) return '.mp4';
    if (type.contains('video/webm')) return '.webm';
    if (type.contains('video/ogg')) return '.ogv';
    if (type.contains('video/quicktime')) return '.mov';
    if (type.contains('video/x-msvideo')) return '.avi';
    if (type.contains('video/')) return '.mp4'; // Default video
    
    // Images
    if (type.contains('image/jpeg') || type.contains('image/jpg')) return '.jpg';
    if (type.contains('image/png')) return '.png';
    if (type.contains('image/gif')) return '.gif';
    if (type.contains('image/webp')) return '.webp';
    if (type.contains('image/svg')) return '.svg';
    if (type.contains('image/')) return '.jpg'; // Default image
    
    // Documents
    if (type.contains('application/pdf')) return '.pdf';
    if (type.contains('application/msword')) return '.doc';
    if (type.contains('application/vnd.openxmlformats-officedocument.wordprocessingml')) return '.docx';
    if (type.contains('application/vnd.ms-excel')) return '.xls';
    if (type.contains('application/vnd.openxmlformats-officedocument.spreadsheetml')) return '.xlsx';
    if (type.contains('application/vnd.ms-powerpoint')) return '.ppt';
    if (type.contains('application/vnd.openxmlformats-officedocument.presentationml')) return '.pptx';
    
    // Archives
    if (type.contains('application/zip')) return '.zip';
    if (type.contains('application/x-rar-compressed')) return '.rar';
    if (type.contains('application/x-tar')) return '.tar';
    if (type.contains('application/gzip')) return '.gz';
    
    // Text
    if (type.contains('text/plain')) return '.txt';
    if (type.contains('text/html')) return '.html';
    if (type.contains('text/css')) return '.css';
    if (type.contains('text/javascript')) return '.js';
    if (type.contains('application/json')) return '.json';
    if (type.contains('application/xml')) return '.xml';
    
    return '';
  }

  /// Get file extension from URL
  String _getExtensionFromUrl(String url) {
    try {
      // Remove query parameters and fragments first
      final cleanUrl = url.split('?').first.split('#').first;
      
      // Common file extensions to look for in URL
      final commonExts = [
        '.mp3', '.mp4', '.wav', '.ogg', '.aac', '.flac', '.webm',
        '.avi', '.mov', '.mkv', '.wmv', '.flv',
        '.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg', '.bmp',
        '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
        '.zip', '.rar', '.tar', '.gz', '.7z',
        '.txt', '.html', '.css', '.js', '.json', '.xml', '.csv'
      ];
      
      // Check for common extensions in URL (case insensitive)
      final lowerUrl = cleanUrl.toLowerCase();
      for (final ext in commonExts) {
        if (lowerUrl.contains(ext)) {
          // Make sure it's at the end of a path segment or before query/fragment
          final extIndex = lowerUrl.lastIndexOf(ext);
          if (extIndex > 0) {
            // Check if it's followed by end of string, /, ?, or #
            final afterExt = extIndex + ext.length;
            if (afterExt >= cleanUrl.length || 
                cleanUrl[afterExt] == '/' || 
                cleanUrl[afterExt] == '?' || 
                cleanUrl[afterExt] == '#') {
              return ext; // Return with original case from commonExts
            }
          }
        }
      }
      
      // Fallback: Try URI parsing
      final uri = Uri.parse(cleanUrl);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final lastSegment = pathSegments.last;
        if (lastSegment.contains('.')) {
          final ext = path.extension(lastSegment);
          if (ext.isNotEmpty && ext.length <= 6 && ext != '.bin') {
            if (RegExp(r'^\.\w+$').hasMatch(ext)) {
              return ext;
            }
          }
        }
      }
      
      // Try full path
      final urlPath = uri.path;
      if (urlPath.contains('.')) {
        final parts = urlPath.split('.');
        if (parts.length > 1) {
          final ext = '.${parts.last.split('/').first}';
          if (ext.length <= 7 && ext.length > 1 && ext != '.bin') {
            if (RegExp(r'^\.\w+$').hasMatch(ext)) {
              return ext;
            }
          }
        }
      }
    } catch (e) {
      // If parsing fails, try simple string extraction
      try {
        final cleanUrl = url.split('?').first.split('#').first.toLowerCase();
        final commonExts = ['.mp3', '.mp4', '.pdf', '.zip', '.jpg', '.png', '.gif', 
                           '.wav', '.ogg', '.avi', '.mov', '.doc', '.docx'];
        for (final ext in commonExts) {
          if (cleanUrl.contains(ext)) {
            final extIndex = cleanUrl.lastIndexOf(ext);
            if (extIndex > 0 && (extIndex + ext.length >= cleanUrl.length || 
                cleanUrl[extIndex + ext.length] == '/' || 
                cleanUrl[extIndex + ext.length] == '?')) {
              return ext;
            }
          }
        }
      } catch (e2) {
        // Ignore
      }
    }
    return '';
  }

  /// Determine proper file extension
  Future<String> _determineFileExtension(String url, String filename) async {
    // First, try to get extension from filename (but skip if it's .bin)
    final filenameExt = path.extension(filename);
    if (filenameExt.isNotEmpty && filenameExt.length <= 6 && filenameExt != '.bin') {
      return filenameExt;
    }
    
    // Second, try to get extension from URL (most reliable for downloads)
    final urlExt = _getExtensionFromUrl(url);
    if (urlExt.isNotEmpty && urlExt != '.bin') {
      return urlExt;
    }
    
    // Third, try to get extension from Content-Type header (most accurate)
    final contentTypeExt = await _getExtensionFromContentType(url);
    if (contentTypeExt.isNotEmpty && contentTypeExt != '.bin') {
      return contentTypeExt;
    }
    
    // If we got .bin from URL or Content-Type, try URL again more aggressively
    if (urlExt == '.bin' || contentTypeExt == '.bin') {
      // Try a more aggressive URL parsing
      try {
        final cleanUrl = url.split('?').first.split('#').first.toLowerCase();
        // Common file extensions to look for
        final commonExts = ['.mp3', '.mp4', '.pdf', '.zip', '.jpg', '.png', '.gif', 
                           '.wav', '.ogg', '.avi', '.mov', '.doc', '.docx', '.xls', 
                           '.xlsx', '.ppt', '.pptx', '.txt', '.html', '.css', '.js'];
        for (final ext in commonExts) {
          if (cleanUrl.contains(ext)) {
            return ext;
          }
        }
      } catch (e) {
        // Ignore
      }
    }
    
    // Fallback to .bin only if absolutely nothing found
    return '.bin';
  }

  Future<void> startDownload({
    required String url,
    required String filename,
    String? sourceType, // 'image', 'file', etc.
  }) async {
    String downloadId = '';
    try {
      // Always check permission status first
      await _checkStoragePermission();
      
      // For Android 13+ (including Android 15), we don't need to request permission
      // App's external storage directory is always accessible (scoped storage)
      // For Android <13, request permission if needed
      final androidVersion = await _getAndroidVersion();
      if (androidVersion < 33 && !state.hasStoragePermission) {
        // Android <13 - request storage permission (system dialog will appear)
        final granted = await requestStoragePermission();
        if (!granted) {
          _markFailed(url, 'Storage permission denied. Please grant storage permission when prompted.');
          return;
        }
      } else if (!state.hasStoragePermission) {
        // Android 13+ - just verify we can access app directory
        await _checkStoragePermission();
        if (!state.hasStoragePermission) {
          _markFailed(url, 'Storage access unavailable.');
          return;
        }
      }

      // Get downloads directory
      final downloadsPath = await _getDownloadsDirectory();
      if (downloadsPath == null) {
        throw Exception('Could not access downloads directory');
      }

      // Create subdirectory based on type
      final String folderName = sourceType == 'image' ? 'void' : 'Downloads';
      final downloadDir = Directory(path.join(downloadsPath, folderName));
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      // Determine proper file extension FIRST (before processing filename)
      final detectedExtension = await _determineFileExtension(url, filename);
      final existingExtension = path.extension(filename);
      var baseFilename = path.basenameWithoutExtension(filename);
      
      // If baseFilename is empty, generate one
      if (baseFilename.isEmpty) {
        baseFilename = 'download_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      // Determine final filename with proper extension
      var finalFilename = filename;
      
      // Always replace .bin extension or add extension if missing
      if (existingExtension == '.bin' || existingExtension.isEmpty) {
        // Use detected extension if it's valid (not .bin)
        if (detectedExtension.isNotEmpty && detectedExtension != '.bin') {
          finalFilename = '$baseFilename$detectedExtension';
        } else if (existingExtension.isEmpty) {
          // No extension and detection failed, still use detected (might be .bin as last resort)
          finalFilename = '$baseFilename$detectedExtension';
        } else {
          // Has .bin extension but detection failed - try to keep base name without .bin
          // and let it be added by detection (which might return .bin)
          finalFilename = '$baseFilename$detectedExtension';
        }
      } else {
        // Filename has a valid extension (not .bin), keep it
        finalFilename = filename;
      }
      
      var filepath = path.join(downloadDir.path, finalFilename);
      var counter = 1;
      
      // Check if file exists and create unique name
      while (await File(filepath).exists()) {
        final nameWithoutExt = path.basenameWithoutExtension(finalFilename);
        final ext = path.extension(finalFilename);
        finalFilename = '${nameWithoutExt}_$counter$ext';
        filepath = path.join(downloadDir.path, finalFilename);
        counter++;
      }

      downloadId = DateTime.now().millisecondsSinceEpoch.toString();

      // Create download entity
      final download = DownloadEntity(
        id: downloadId,
        url: url,
        filename: finalFilename,
        savedPath: filepath,
        totalBytes: 0,
        downloadedBytes: 0,
        status: DownloadStatus.downloading,
        createdAt: DateTime.now(),
      );

      // Add to downloads list
      final updatedDownloads = [...state.downloads, download];
      final cancelToken = CancelToken();
      final updatedCancelTokens = {...state.cancelTokens, downloadId: cancelToken};
      final updatedProgress = {...state.progress, downloadId: 0.0};

      state = state.copyWith(
        downloads: updatedDownloads,
        cancelTokens: updatedCancelTokens,
        progress: updatedProgress,
      );

      // Save to Hive
      _saveDownloads(updatedDownloads);

      // Show download started notification
      try {
        final notificationId = int.tryParse(downloadId) ?? DateTime.now().millisecondsSinceEpoch % 2147483647;
        await NotificationService().showDownloadStartedNotification(
          filename: finalFilename,
          notificationId: notificationId,
        );
      } catch (e) {
        // If notification fails, continue with download
      }

      // Start download
      final dio = Dio();
      
      // Try to get Content-Type from response if we still have .bin extension
      String? contentTypeFromResponse;
      if (path.extension(finalFilename) == '.bin') {
        try {
          // Make a HEAD request to get Content-Type before downloading
          final headResponse = await dio.head(
            url,
            options: Options(
              followRedirects: true,
              validateStatus: (status) => status! < 500,
            ),
          ).timeout(const Duration(seconds: 3));
          
          contentTypeFromResponse = headResponse.headers.value('content-type') ?? 
                                   headResponse.headers.map['Content-Type']?.first;
          
          if (contentTypeFromResponse != null) {
            final ext = _mapContentTypeToExtension(contentTypeFromResponse);
            if (ext.isNotEmpty && ext != '.bin') {
              // Update filename with correct extension
              final nameWithoutExt = path.basenameWithoutExtension(finalFilename);
              finalFilename = '$nameWithoutExt$ext';
              filepath = path.join(downloadDir.path, finalFilename);
              
              // Update download entity with new filename
              final updatedDownloads = state.downloads.map((d) {
                if (d.id == downloadId) {
                  return d.copyWith(filename: finalFilename, savedPath: filepath);
                }
                return d;
              }).toList();
              state = state.copyWith(downloads: updatedDownloads);
              _saveDownloads(updatedDownloads);
            }
          }
        } catch (e) {
          // If HEAD fails, proceed with download - extension might be detected from URL
        }
      }
      
      await dio.download(
        url,
        filepath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            _updateProgress(downloadId, progress, received, total);
          }
        },
      );

      // Mark as completed
      _markCompleted(downloadId, filepath);
    } catch (e) {
      // Mark as failed
      final errorMessage = e.toString();
      if (errorMessage.contains('permission') || errorMessage.contains('Permission')) {
        _markFailed(downloadId.isNotEmpty ? downloadId : url, 'Storage permission required. Please grant permission in app settings.');
      } else if (downloadId.isNotEmpty) {
        _markFailed(downloadId, errorMessage);
      } else {
        _markFailed(url, errorMessage);
      }
    }
  }

  void _updateProgress(String downloadId, double progress, int received, int total) {
    final updatedProgress = {...state.progress, downloadId: progress};
    final updatedDownloads = state.downloads.map((download) {
      if (download.id == downloadId) {
        return download.copyWith(
          downloadedBytes: received,
          totalBytes: total,
        );
      }
      return download;
    }).toList();

    state = state.copyWith(
      progress: updatedProgress,
      downloads: updatedDownloads,
    );
  }

  void _markCompleted(String downloadId, String filepath) {
    final updatedDownloads = state.downloads.map((download) {
      if (download.id == downloadId) {
        return download.copyWith(
          status: DownloadStatus.completed,
          completedAt: DateTime.now(),
          savedPath: filepath,
        );
      }
      return download;
    }).toList();

    final updatedCancelTokens = {...state.cancelTokens};
    updatedCancelTokens.remove(downloadId);
    final updatedProgress = {...state.progress};
    updatedProgress.remove(downloadId);

    state = state.copyWith(
      downloads: updatedDownloads,
      cancelTokens: updatedCancelTokens,
      progress: updatedProgress,
    );

    // Save to Hive (only save completed downloads, not progress updates)
    _saveDownloads(updatedDownloads);
  }

  void _markFailed(String identifier, String error) {
    // Identifier can be downloadId or url
    final updatedDownloads = state.downloads.map((download) {
      if ((download.id == identifier || download.url == identifier) && 
          download.status == DownloadStatus.downloading) {
        return download.copyWith(
          status: DownloadStatus.failed,
          errorMessage: error,
        );
      }
      return download;
    }).toList();

    state = state.copyWith(downloads: updatedDownloads);
    
    // Save to Hive
    _saveDownloads(updatedDownloads);
    
    // If permission error, update permission state
    if (error.contains('permission') || error.contains('Permission')) {
      state = state.copyWith(hasStoragePermission: false, permissionError: error);
    }
  }

  void cancelDownload(String downloadId) {
    final cancelToken = state.cancelTokens[downloadId];
    if (cancelToken != null) {
      cancelToken.cancel('Download cancelled by user');
    }

    final updatedDownloads = state.downloads.map((download) {
      if (download.id == downloadId) {
        return download.copyWith(status: DownloadStatus.cancelled);
      }
      return download;
    }).toList();

    final updatedCancelTokens = {...state.cancelTokens};
    updatedCancelTokens.remove(downloadId);
    final updatedProgress = {...state.progress};
    updatedProgress.remove(downloadId);

    state = state.copyWith(
      downloads: updatedDownloads,
      cancelTokens: updatedCancelTokens,
      progress: updatedProgress,
    );

    // Save to Hive
    _saveDownloads(updatedDownloads);
  }

  void deleteDownload(String downloadId) {
    final download = state.downloads.firstWhere((d) => d.id == downloadId);
    
    // Delete file if exists
    if (download.savedPath != null && download.savedPath!.isNotEmpty) {
      try {
        final file = File(download.savedPath!);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (e) {
        // Ignore file deletion errors
      }
    }

    final updatedDownloads = state.downloads.where((d) => d.id != downloadId).toList();
    final updatedProgress = {...state.progress};
    updatedProgress.remove(downloadId);
    
    state = state.copyWith(
      downloads: updatedDownloads,
      progress: updatedProgress,
    );

    // Save to Hive
    _saveDownloads(updatedDownloads);
  }

  void clearCompleted() {
    // Delete files for completed downloads
    for (final download in state.downloads) {
      if (download.status == DownloadStatus.completed && 
          download.savedPath != null && 
          download.savedPath!.isNotEmpty) {
        try {
          final file = File(download.savedPath!);
          if (file.existsSync()) {
            file.deleteSync();
          }
        } catch (e) {
          // Ignore deletion errors
        }
      }
    }
    
    final updatedDownloads = state.downloads.where((d) => d.status != DownloadStatus.completed).toList();
    state = state.copyWith(downloads: updatedDownloads);
    
    // Save to Hive
    _saveDownloads(updatedDownloads);
  }

  void clearAll() {
    // Delete all files
    for (final download in state.downloads) {
      if (download.savedPath != null && download.savedPath!.isNotEmpty) {
        try {
          final file = File(download.savedPath!);
          if (file.existsSync()) {
            file.deleteSync();
          }
        } catch (e) {
          // Ignore deletion errors
        }
      }
    }

    state = DownloadManagerState();
    _checkStoragePermission(); // Re-check permission state
    
    // Clear Hive storage
    _saveDownloads([]);
  }
}

// Provider
final downloadManagerProvider = StateNotifierProvider<DownloadManagerNotifier, DownloadManagerState>((ref) {
  return DownloadManagerNotifier();
});
