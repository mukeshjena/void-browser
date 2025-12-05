import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../providers/download_manager_provider.dart';
import '../../domain/entities/download_entity.dart';

class DownloadsScreenNew extends ConsumerWidget {
  const DownloadsScreenNew({super.key});

  /// Open file with permission handling and app chooser
  Future<void> _openFileWithPermission(BuildContext context, String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File not found'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Check and request storage permission before opening file
      if (Platform.isAndroid) {
        final androidVersion = await _getAndroidVersion();
        
        if (androidVersion < 33) {
          // Android < 13 - need READ_EXTERNAL_STORAGE permission
          final status = await Permission.storage.status;
          if (!status.isGranted) {
            // Request permission
            final result = await Permission.storage.request();
            if (!result.isGranted) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Storage permission is required to open files. Please grant permission when prompted.'),
                    duration: Duration(seconds: 4),
                  ),
                );
              }
              return;
            }
          }
        } else {
          // Android 13+ - check for permissions based on file type and location
          // Files in app directory don't need permission, but files in public storage do
          final fileExtension = filePath.toLowerCase().split('.').last;
          bool needsPermission = false;
          Permission? requiredPermission;
          
          // Check if file is in app's directory
          try {
            final externalDir = await getExternalStorageDirectory();
            final appDir = externalDir?.path ?? '';
            final isInAppDirectory = filePath.startsWith(appDir);
            
            if (!isInAppDirectory) {
              // File is in public storage, check for appropriate permission based on file type
              if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(fileExtension)) {
                // Image files
                needsPermission = true;
                requiredPermission = Permission.photos;
              } else if (['mp4', 'avi', 'mov', 'mkv', 'wmv', 'flv', 'webm'].contains(fileExtension)) {
                // Video files
                needsPermission = true;
                requiredPermission = Permission.videos;
              } else if (['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'].contains(fileExtension)) {
                // Audio files
                needsPermission = true;
                requiredPermission = Permission.audio;
              } else {
                // For other files (PDF, DOCX, XLSX, etc.) in public storage on Android 13+
                // We need to check if we can access them
                // Try to read the file - if it fails, we might need to use SAF or request permission
                try {
                  await file.readAsBytes();
                  // File is accessible, no permission needed
                  needsPermission = false;
                } catch (e) {
                  // File might not be accessible
                  // For Android 13+, non-media files in public storage might need special handling
                  // We'll try to open it anyway and let open_filex handle it
                  debugPrint('File might not be directly accessible: $e');
                  needsPermission = false; // Let open_filex try to handle it
                }
              }
            }
            
            if (needsPermission && requiredPermission != null) {
              final status = await requiredPermission.status;
              if (!status.isGranted) {
                final result = await requiredPermission.request();
                if (!result.isGranted) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Permission is required to open this ${fileExtension.toUpperCase()} file. Please grant permission when prompted.'),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                  return;
                }
              }
            }
          } catch (e) {
            debugPrint('Error checking file location: $e');
            // Continue anyway, open_filex will handle it
          }
        }
      }

      // Verify file is readable
      if (!await file.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File not found'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Check if file is readable
      try {
        await file.readAsBytes();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File is not accessible. Please check file permissions.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Use open_filex to open file directly in appropriate app (shows app chooser if multiple apps available)
      // Normalize the file path to ensure it's in the correct format
      final normalizedPath = filePath.replaceAll('\\', '/');
      
      debugPrint('Attempting to open file: $normalizedPath');
      final result = await OpenFilex.open(normalizedPath);
      debugPrint('Open file result: ${result.type}, message: ${result.message}');
      
      if (context.mounted) {
        if (result.type == ResultType.done) {
          // Success - file opened in app
          return;
        } else if (result.type == ResultType.permissionDenied) {
          // Permission denied - request again or show message
          if (Platform.isAndroid) {
            final androidVersion = await _getAndroidVersion();
            if (androidVersion < 33) {
              final permissionResult = await Permission.storage.request();
              if (permissionResult.isGranted) {
                // Retry opening file
                final retryResult = await OpenFilex.open(normalizedPath);
                if (retryResult.type != ResultType.done && context.mounted) {
                  String errorMsg = 'Could not open file';
                  if (retryResult.message.isNotEmpty) {
                    errorMsg = 'Error: ${retryResult.message}';
                  } else if (retryResult.type == ResultType.noAppToOpen) {
                    errorMsg = 'No app found to open this file type';
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMsg),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Permission denied. Please grant storage permission in app settings.'),
                    duration: Duration(seconds: 4),
                  ),
                );
              }
            } else {
              // Android 13+ - try alternative method or show detailed error
              String errorMsg = 'Could not open file';
              if (result.message.isNotEmpty) {
                errorMsg = 'Error: ${result.message}';
              } else {
                errorMsg = 'Could not open file. The file may be in a restricted location.';
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(errorMsg),
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        } else if (result.type == ResultType.noAppToOpen) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No app found to open this file type. Please install an app that can open this file.'),
              duration: Duration(seconds: 4),
            ),
          );
        } else if (result.type == ResultType.fileNotFound) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File not found. The file may have been moved or deleted.'),
              duration: Duration(seconds: 3),
            ),
          );
        } else if (result.type == ResultType.error) {
          String message = 'Could not open file';
          if (result.message.isNotEmpty) {
            message = 'Error: ${result.message}';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          // Unknown error type
          String message = 'Could not open file';
          if (result.message.isNotEmpty) {
            message = 'Error: ${result.message}';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Log the error for debugging
      debugPrint('Error opening file: $e');
      debugPrint('File path: $filePath');
      
      if (context.mounted) {
        String errorMessage = 'Could not open file';
        final errorStr = e.toString().toLowerCase();
        
        if (errorStr.contains('permission')) {
          errorMessage = 'Permission denied. Please grant storage permission in app settings.';
        } else if (errorStr.contains('not found') || errorStr.contains('no such file')) {
          errorMessage = 'File not found. The file may have been moved or deleted.';
        } else if (errorStr.isNotEmpty) {
          errorMessage = 'Error: ${e.toString()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Get Android version
  Future<int> _getAndroidVersion() async {
    if (!Platform.isAndroid) return 0;
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM d, y').format(date);
  }

  Color _getStatusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return Colors.blue;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.failed:
        return Colors.red;
      case DownloadStatus.paused:
        return Colors.orange;
      case DownloadStatus.cancelled:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return Icons.downloading;
      case DownloadStatus.completed:
        return Icons.check_circle;
      case DownloadStatus.failed:
        return Icons.error;
      case DownloadStatus.paused:
        return Icons.pause_circle;
      case DownloadStatus.cancelled:
        return Icons.cancel;
      default:
        return Icons.file_download;
    }
  }

  void _showDownloadOptions(BuildContext context, WidgetRef ref, DownloadEntity download) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Filename
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  download.filename,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),

              // Options
              if (download.status == DownloadStatus.downloading)
                ListTile(
                  leading: const Icon(Icons.cancel, color: Colors.orange),
                  title: const Text('Cancel Download'),
                  onTap: () {
                    ref.read(downloadManagerProvider.notifier).cancelDownload(download.id);
                    Navigator.pop(context);
                  },
                ),
              
              if (download.status == DownloadStatus.completed) ...[
                ListTile(
                  leading: const Icon(Icons.folder_open, color: Colors.blue),
                  title: const Text('Open File'),
                  onTap: () async {
                    Navigator.pop(context);
                    if (download.savedPath != null && download.savedPath!.isNotEmpty) {
                      final file = File(download.savedPath!);
                      if (await file.exists()) {
                        await _openFileWithPermission(context, download.savedPath!);
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('File not found'),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share, color: Colors.green),
                  title: const Text('Share'),
                  onTap: () async {
                    Navigator.pop(context);
                    if (download.savedPath != null && download.savedPath!.isNotEmpty) {
                      final file = File(download.savedPath!);
                      if (await file.exists()) {
                        await Share.shareXFiles(
                          [XFile(download.savedPath!)],
                          text: 'Shared from Void Browser',
                        );
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('File not found')),
                          );
                        }
                      }
                    }
                  },
                ),
              ],

              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete'),
                onTap: () {
                  ref.read(downloadManagerProvider.notifier).deleteDownload(download.id);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Download deleted')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use select to watch only specific fields to reduce rebuilds
    final downloads = ref.watch(downloadManagerProvider.select((state) => state.downloads)).reversed.toList();
    final progress = ref.watch(downloadManagerProvider.select((state) => state.progress));
    final hasStoragePermission = ref.watch(downloadManagerProvider.select((state) => state.hasStoragePermission));
    final permissionError = ref.watch(downloadManagerProvider.select((state) => state.permissionError));
    //final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          if (downloads.isNotEmpty)
            PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'clear_completed',
                  child: Text('Clear completed'),
                ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Text('Clear all'),
                ),
              ],
              onSelected: (value) {
                if (value == 'clear_completed') {
                  ref.read(downloadManagerProvider.notifier).clearCompleted();
                } else if (value == 'clear_all') {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Clear all downloads?'),
                      content: const Text('This will delete all downloaded files.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            ref.read(downloadManagerProvider.notifier).clearAll();
                            Navigator.pop(context);
                          },
                          child: const Text('Delete All', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
        ],
      ),
      body: !hasStoragePermission && downloads.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_off,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Storage Permission Required',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      permissionError ?? 
                      'Void needs storage permission to save downloads to your device. Please grant permission to continue.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final granted = await ref.read(downloadManagerProvider.notifier).requestStoragePermission();
                        if (!granted && context.mounted) {
                          // Show dialog to open settings
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Permission Required'),
                              content: const Text(
                                'Storage permission is required to download files. Please grant permission in app settings.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    openAppSettings();
                                  },
                                  child: const Text('Open Settings'),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.lock_open),
                      label: const Text('Grant Permission'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : downloads.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.download_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No downloads yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Downloaded files will appear here',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
          : RepaintBoundary(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: downloads.length,
                itemBuilder: (context, index) {
                  final download = downloads[index];
                  final downloadProgress = progress[download.id] ?? 0.0;
                  
                  return Card(
                    key: ValueKey('download_${download.id}_$index'),
                    margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    onTap: () => _showDownloadOptions(context, ref, download),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Icon
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(download.status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _getStatusIcon(download.status),
                                  color: _getStatusColor(download.status),
                                  size: 28,
                                ),
                              ),
                              
                              const SizedBox(width: 16),
                              
                              // File info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      download.filename,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          download.totalBytes > 0
                                              ? _formatFileSize(download.totalBytes)
                                              : 'Unknown size',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          ' • ${_formatDate(download.createdAt)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Status badge
                              if (download.status == DownloadStatus.downloading)
                                Text(
                                  '${(downloadProgress * 100).toInt()}%',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _getStatusColor(download.status),
                                  ),
                                ),
                            ],
                          ),
                          
                          // Progress bar for downloading
                          if (download.status == DownloadStatus.downloading) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: downloadProgress,
                                minHeight: 6,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getStatusColor(download.status),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_formatFileSize(download.downloadedBytes)} / ${_formatFileSize(download.totalBytes)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    ref.read(downloadManagerProvider.notifier).cancelDownload(download.id);
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                          
                          // Error message
                          if (download.status == DownloadStatus.failed && download.errorMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              download.errorMessage!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
    );
  }
}

