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

      // Ensure unique filename
      final baseFilename = path.basenameWithoutExtension(filename);
      final extension = path.extension(filename).isEmpty ? '.bin' : path.extension(filename);
      var finalFilename = filename;
      var filepath = path.join(downloadDir.path, finalFilename);
      var counter = 1;
      
      // Check if file exists and create unique name
      while (await File(filepath).exists()) {
        finalFilename = '${baseFilename}_$counter$extension';
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

      // Start download
      final dio = Dio();
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
