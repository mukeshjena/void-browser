import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

class ScreenshotUtils {
  /// Save screenshot to device storage
  /// Returns the saved file path, or null if failed
  static Future<String?> saveScreenshot(
    Uint8List screenshotData,
    String filename,
  ) async {
    try {
      // Check storage permission for Android <13
      if (Platform.isAndroid) {
        final androidVersion = await _getAndroidVersion();
        if (androidVersion < 33) {
          final status = await Permission.storage.status;
          if (!status.isGranted) {
            final result = await Permission.storage.request();
            if (!result.isGranted) {
              throw Exception('Storage permission denied');
            }
          }
        }
      }

      // Get downloads directory
      final downloadsPath = await _getDownloadsDirectory();
      if (downloadsPath == null) {
        throw Exception('Could not access downloads directory');
      }

      // Create Screenshots subdirectory
      final screenshotsDir = Directory(path.join(downloadsPath, 'Screenshots'));
      if (!await screenshotsDir.exists()) {
        await screenshotsDir.create(recursive: true);
      }

      // Ensure filename has .png extension
      var finalFilename = filename;
      if (!finalFilename.toLowerCase().endsWith('.png')) {
        finalFilename = '$filename.png';
      }

      var filepath = path.join(screenshotsDir.path, finalFilename);
      var counter = 1;

      // Check if file exists and create unique name
      while (await File(filepath).exists()) {
        final nameWithoutExt = path.basenameWithoutExtension(finalFilename);
        finalFilename = '${nameWithoutExt}_$counter.png';
        filepath = path.join(screenshotsDir.path, finalFilename);
        counter++;
      }

      // Save screenshot
      final file = File(filepath);
      await file.writeAsBytes(screenshotData);

      return filepath;
    } catch (e) {
      return null;
    }
  }

  /// Get downloads directory path
  static Future<String?> _getDownloadsDirectory() async {
    try {
      if (Platform.isAndroid) {
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          final androidVersion = await _getAndroidVersion();
          
          if (androidVersion >= 33) {
            // Android 13+ - use app's external storage (scoped storage)
            final appDownloadsDir = Directory(path.join(directory.path, 'Downloads'));
            if (!await appDownloadsDir.exists()) {
              await appDownloadsDir.create(recursive: true);
            }
            return appDownloadsDir.path;
          } else {
            // Android <13 - try public Downloads folder
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
                
                if (await downloadsDir.exists() || await _canCreateDirectory(downloadsDir)) {
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
            
            // Fallback: use app's Downloads folder
            final appDownloadsDir = Directory(path.join(directory.path, 'Downloads'));
            if (!await appDownloadsDir.exists()) {
              await appDownloadsDir.create(recursive: true);
            }
            return appDownloadsDir.path;
          }
        }
      } else if (Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        final screenshotsDir = Directory(path.join(directory.path, 'Screenshots'));
        if (!await screenshotsDir.exists()) {
          await screenshotsDir.create(recursive: true);
        }
        return screenshotsDir.path;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if directory can be created
  static Future<bool> _canCreateDirectory(Directory dir) async {
    try {
      await dir.create(recursive: true);
      return await dir.exists();
    } catch (e) {
      return false;
    }
  }

  /// Get Android version
  static Future<int> _getAndroidVersion() async {
    if (!Platform.isAndroid) return 0;
    try {
      // Use a simple method to detect Android version
      // For more accurate detection, you might need platform-specific code
      return 33; // Default to Android 13+ for safety
    } catch (e) {
      return 33; // Default to Android 13+ for safety
    }
  }

  /// Generate filename from URL or title
  static String generateFilename(String? url, String? title) {
    String baseName;
    
    if (title != null && title.isNotEmpty) {
      // Use title, sanitize it
      baseName = title
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .substring(0, title.length > 50 ? 50 : title.length);
    } else if (url != null && url.isNotEmpty && url != 'discover') {
      try {
        final uri = Uri.parse(url);
        final host = uri.host.replaceAll('.', '_');
        baseName = host;
      } catch (e) {
        baseName = 'screenshot';
      }
    } else {
      baseName = 'screenshot';
    }
    
    // Add timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${baseName}_$timestamp';
  }
}

