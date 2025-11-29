import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../../../../core/utils/screenshot_utils.dart';

class ScreenshotDialog extends StatefulWidget {
  final Uint8List screenshotData;
  final String? url;
  final String? title;

  const ScreenshotDialog({
    super.key,
    required this.screenshotData,
    this.url,
    this.title,
  });

  @override
  State<ScreenshotDialog> createState() => _ScreenshotDialogState();
}

class _ScreenshotDialogState extends State<ScreenshotDialog> {
  bool _isSaving = false;
  bool _isSharing = false;

  Future<void> _saveToDevice() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Generate filename
      final filename = ScreenshotUtils.generateFilename(widget.url, widget.title);

      // Save screenshot
      final savedPath = await ScreenshotUtils.saveScreenshot(
        widget.screenshotData,
        filename,
      );

      if (savedPath != null && mounted) {
        setState(() {
          _isSaving = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Screenshot saved successfully'),
            duration: Duration(seconds: 2),
          ),
        );
        
        // Close dialog after saving
        Navigator.of(context).pop(true);
      } else {
        throw Exception('Failed to save screenshot');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _shareScreenshot() async {
    if (_isSharing) return;

    setState(() {
      _isSharing = true;
    });

    try {
      // Create temporary file for sharing
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFile = File(path.join(tempDir.path, 'screenshot_$timestamp.png'));
      
      // Write screenshot data to temp file
      await tempFile.writeAsBytes(widget.screenshotData);

      // Share the file
      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: widget.title ?? 'Screenshot',
        subject: widget.url ?? 'Web Page Screenshot',
      );

      // Clean up temp file after a delay
      Future.delayed(const Duration(seconds: 5), () async {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (e) {
          // Ignore cleanup errors
        }
      });

      if (mounted) {
        setState(() {
          _isSharing = false;
        });
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Row(
                children: [
                  Icon(
                    Icons.camera_alt,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Screenshot Captured',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Screenshot Preview
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    widget.screenshotData,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSharing || _isSaving ? null : _shareScreenshot,
                      icon: _isSharing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.share, size: 18),
                      label: Text(_isSharing ? 'Sharing...' : 'Share'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving || _isSharing ? null : _saveToDevice,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save, size: 18),
                      label: Text(_isSaving ? 'Saving...' : 'Save'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

