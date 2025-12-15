import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/media_downloader_provider.dart';
import '../../domain/entities/media_download_entity.dart';
import '../widgets/circular_download_button.dart';
import '../../../../core/utils/platform_detector.dart';
import '../../../../core/theme/app_colors.dart';

class MediaDownloaderScreen extends ConsumerStatefulWidget {
  const MediaDownloaderScreen({super.key});

  @override
  ConsumerState<MediaDownloaderScreen> createState() =>
      _MediaDownloaderScreenState();
}

class _MediaDownloaderScreenState
    extends ConsumerState<MediaDownloaderScreen> {
  final TextEditingController _urlController = TextEditingController();
  DownloadQuality _selectedQuality = DownloadQuality.high;
  bool _isProcessing = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handleDownload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid URL'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await ref
          .read(mediaDownloaderProvider.notifier)
          .downloadMedia(url, _selectedQuality);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download started successfully'),
            duration: Duration(seconds: 2),
          ),
        );
        _urlController.clear();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Download failed';
        final errorStr = e.toString().toLowerCase();
        
        if (errorStr.contains('no media found')) {
          errorMessage = 'No media found on this page. Make sure the URL is correct.';
        } else if (errorStr.contains('network') || errorStr.contains('connection')) {
          errorMessage = 'Network error. Please check your internet connection.';
        } else if (errorStr.contains('permission')) {
          errorMessage = 'Storage permission denied. Please grant storage permission.';
        } else if (errorStr.contains('unsupported')) {
          errorMessage = 'This platform is not supported yet.';
        } else {
          errorMessage = 'Download failed: ${e.toString().split(':').last.trim()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showQualitySelector() {
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
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Select Quality',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ...DownloadQuality.values.map((quality) {
                final isSelected = _selectedQuality == quality;
                return ListTile(
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? Theme.of(context).primaryColor : null,
                  ),
                  title: Text(_getQualityLabel(quality)),
                  onTap: () {
                    setState(() {
                      _selectedQuality = quality;
                    });
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  String _getQualityLabel(DownloadQuality quality) {
    switch (quality) {
      case DownloadQuality.lowest:
        return 'Lowest (Smallest size)';
      case DownloadQuality.low:
        return 'Low (240p-360p)';
      case DownloadQuality.medium:
        return 'Medium (480p-720p)';
      case DownloadQuality.high:
        return 'High (1080p)';
      case DownloadQuality.highest:
        return 'Highest (Best quality)';
    }
  }

  Widget _buildPlatformChip(String label, IconData icon) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 11),
      ),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  String _getPlatformIconFromUrl(String url) {
    if (PlatformDetector.isYouTube(url)) return '📺';
    if (PlatformDetector.isInstagram(url)) return '📷';
    if (PlatformDetector.isFacebook(url)) return '👥';
    if (PlatformDetector.isTwitter(url)) return '🐦';
    if (PlatformDetector.isTikTok(url)) return '🎵';
    return '🌐';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mediaDownloaderProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasUrl = _urlController.text.trim().isNotEmpty;
    final platformName = hasUrl
        ? PlatformDetector.getPlatformName(_urlController.text.trim())
        : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Downloader'),
        actions: [
          if (state.downloads.isNotEmpty)
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
                  ref.read(mediaDownloaderProvider.notifier).clearCompleted();
                } else if (value == 'clear_all') {
                  ref.read(mediaDownloaderProvider.notifier).clearAll();
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // URL Input Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // URL Input Field
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    hintText: 'Paste YouTube, Instagram, Facebook URL...',
                    prefixIcon: hasUrl
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              _getPlatformIconFromUrl(_urlController.text.trim()),
                              style: const TextStyle(fontSize: 20),
                            ),
                          )
                        : const Icon(Icons.link),
                    suffixIcon: hasUrl
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _urlController.clear();
                              setState(() {});
                            },
                          )
                        : IconButton(
                            icon: const Icon(Icons.paste),
                            onPressed: () async {
                              final clipboardData =
                                  await Clipboard.getData(Clipboard.kTextPlain);
                              if (clipboardData?.text != null) {
                                _urlController.text = clipboardData!.text!;
                                setState(() {});
                              }
                            },
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.grey[900]
                        : Colors.grey[100],
                  ),
                  onChanged: (value) => setState(() {}),
                  maxLines: 1,
                ),
                const SizedBox(height: 12),

                // Platform Info & Quality Selector
                if (hasUrl) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          platformName,
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _showQualitySelector,
                        icon: const Icon(Icons.high_quality, size: 18),
                        label: Text(_getQualityLabel(_selectedQuality)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Download Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (hasUrl && !_isProcessing && !state.isDownloading)
                        ? _handleDownload
                        : null,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Start Download'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Downloads List
          Expanded(
            child: state.downloads.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.download_outlined,
                          size: 64,
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
                          'Paste a URL and tap download',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Supported platforms info
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[900] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Supported Platforms:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  _buildPlatformChip('YouTube', Icons.play_circle),
                                  _buildPlatformChip('Instagram', Icons.camera_alt),
                                  _buildPlatformChip('Facebook', Icons.people),
                                  _buildPlatformChip('Twitter/X', Icons.chat),
                                  _buildPlatformChip('TikTok', Icons.music_note),
                                  _buildPlatformChip('Any Website', Icons.link),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.downloads.length,
                    itemBuilder: (context, index) {
                      final download = state.downloads[index];
                      return _buildDownloadCard(download, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadCard(MediaDownloadEntity download, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Thumbnail or Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[300],
              ),
              child: download.thumbnailUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        download.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.video_library, color: Colors.grey[600]),
                      ),
                    )
                  : Icon(
                      _getPlatformIconData(download.platform),
                      size: 30,
                      color: Colors.grey[600],
                    ),
            ),
            const SizedBox(width: 12),

            // Download Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    download.title ?? 'Downloading...',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getPlatformName(download.platform),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (!download.isCompleted && download.progress < 1.0) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: download.progress,
                      backgroundColor: Colors.grey[200],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(download.progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ] else if (download.isCompleted) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'Completed',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ] else if (download.error != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.error_outline, size: 14, color: Colors.red),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            download.error!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Circular Download Button
            CircularDownloadButton(
              size: 48,
              progress: download.progress,
              isDownloading: !download.isCompleted && download.progress < 1.0,
              isCompleted: download.isCompleted,
              onPressed: (!download.isCompleted && download.progress < 1.0)
                  ? () {
                      ref
                          .read(mediaDownloaderProvider.notifier)
                          .cancelDownload(download.id);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  String _getPlatformName(MediaPlatform platform) {
    switch (platform) {
      case MediaPlatform.youtube:
        return 'YouTube';
      case MediaPlatform.instagram:
        return 'Instagram';
      case MediaPlatform.facebook:
        return 'Facebook';
      case MediaPlatform.twitter:
        return 'Twitter';
      case MediaPlatform.tiktok:
        return 'TikTok';
      default:
        return 'Other';
    }
  }

  IconData _getPlatformIconData(MediaPlatform platform) {
    switch (platform) {
      case MediaPlatform.youtube:
        return Icons.play_circle_filled;
      case MediaPlatform.instagram:
        return Icons.camera_alt;
      case MediaPlatform.facebook:
        return Icons.people;
      case MediaPlatform.twitter:
        return Icons.chat;
      case MediaPlatform.tiktok:
        return Icons.music_note;
      default:
        return Icons.link;
    }
  }
}

