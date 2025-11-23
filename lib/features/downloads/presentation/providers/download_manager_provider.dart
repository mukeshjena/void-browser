import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../domain/entities/download_entity.dart';

// Download state
class DownloadManagerState {
  final List<DownloadEntity> downloads;
  final Map<String, double> progress;
  final Map<String, CancelToken> cancelTokens;

  DownloadManagerState({
    this.downloads = const [],
    this.progress = const {},
    this.cancelTokens = const {},
  });

  DownloadManagerState copyWith({
    List<DownloadEntity>? downloads,
    Map<String, double>? progress,
    Map<String, CancelToken>? cancelTokens,
  }) {
    return DownloadManagerState(
      downloads: downloads ?? this.downloads,
      progress: progress ?? this.progress,
      cancelTokens: cancelTokens ?? this.cancelTokens,
    );
  }
}

// Download manager notifier
class DownloadManagerNotifier extends StateNotifier<DownloadManagerState> {
  DownloadManagerNotifier() : super(DownloadManagerState());

  Future<void> startDownload({
    required String url,
    required String filename,
    String? sourceType, // 'image', 'file', etc.
  }) async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw Exception('Could not access storage');
      }

      // Create directory based on type
      final String folderName = sourceType == 'image' ? 'Images' : 'Downloads';
      final downloadDir = Directory('${directory.path}/VoidBrowser/$folderName');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final filepath = '${downloadDir.path}/$filename';
      final downloadId = DateTime.now().millisecondsSinceEpoch.toString();

      // Create download entity
      final download = DownloadEntity(
        id: downloadId,
        url: url,
        filename: filename,
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
      _markFailed(url, e.toString());
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

    state = state.copyWith(
      downloads: updatedDownloads,
      cancelTokens: updatedCancelTokens,
    );
  }

  void _markFailed(String url, String error) {
    final updatedDownloads = state.downloads.map((download) {
      if (download.url == url && download.status == DownloadStatus.downloading) {
        return download.copyWith(
          status: DownloadStatus.failed,
          errorMessage: error,
        );
      }
      return download;
    }).toList();

    state = state.copyWith(downloads: updatedDownloads);
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

    state = state.copyWith(
      downloads: updatedDownloads,
      cancelTokens: updatedCancelTokens,
    );
  }

  void deleteDownload(String downloadId) {
    final download = state.downloads.firstWhere((d) => d.id == downloadId);
    
    // Delete file if exists
    if (download.savedPath != null && download.savedPath!.isNotEmpty) {
      final file = File(download.savedPath!);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }

    final updatedDownloads = state.downloads.where((d) => d.id != downloadId).toList();
    state = state.copyWith(downloads: updatedDownloads);
  }

  void clearCompleted() {
    final updatedDownloads = state.downloads.where((d) => d.status != DownloadStatus.completed).toList();
    state = state.copyWith(downloads: updatedDownloads);
  }

  void clearAll() {
    // Delete all files
    for (final download in state.downloads) {
      if (download.savedPath != null && download.savedPath!.isNotEmpty) {
        final file = File(download.savedPath!);
        if (file.existsSync()) {
          file.deleteSync();
        }
      }
    }

    state = DownloadManagerState();
  }
}

// Provider
final downloadManagerProvider = StateNotifierProvider<DownloadManagerNotifier, DownloadManagerState>((ref) {
  return DownloadManagerNotifier();
});

