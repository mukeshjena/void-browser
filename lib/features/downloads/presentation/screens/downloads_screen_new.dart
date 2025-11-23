import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import '../providers/download_manager_provider.dart';
import '../../domain/entities/download_entity.dart';

class DownloadsScreenNew extends ConsumerWidget {
  const DownloadsScreenNew({super.key});

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
                        try {
                          // Use open_filex for proper file opening on Android/iOS
                          final result = await OpenFilex.open(download.savedPath!);
                          
                          if (context.mounted) {
                            if (result.type != ResultType.done) {
                              String message = 'Could not open file';
                              if (result.type == ResultType.noAppToOpen) {
                                message = 'No app found to open this file type';
                              } else if (result.type == ResultType.fileNotFound) {
                                message = 'File not found';
                              } else if (result.type == ResultType.permissionDenied) {
                                message = 'Permission denied to open file';
                              } else if (result.type == ResultType.error) {
                                message = result.message.isNotEmpty 
                                    ? 'Error opening file: ${result.message}'
                                    : 'Error opening file: Unknown error';
                              }
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(message),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Could not open file: ${e.toString()}'),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        }
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
                  elevation: 2,
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

