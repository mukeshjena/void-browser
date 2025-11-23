import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/images_provider.dart';
import '../../../browser/presentation/utils/tab_utils.dart';

class ImageGridWidget extends ConsumerStatefulWidget {
  const ImageGridWidget({super.key});

  @override
  ConsumerState<ImageGridWidget> createState() => _ImageGridWidgetState();
}

class _ImageGridWidgetState extends ConsumerState<ImageGridWidget> {
  @override
  void initState() {
    super.initState();
    // Load random images when widget initializes
    Future.microtask(() => ref.read(imagesProvider.notifier).loadRandomImages());
  }

  @override
  Widget build(BuildContext context) {
    final imagesState = ref.watch(imagesProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Beautiful Images',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (imagesState.isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        if (imagesState.error != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              imagesState.error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        if (imagesState.images.isEmpty && !imagesState.isLoading)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No images available'),
          ),
        if (imagesState.images.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: imagesState.images.length > 10 ? 10 : imagesState.images.length,
            itemBuilder: (context, index) {
              final image = imagesState.images[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    // Open image on Unsplash website in new tab
                    if (image.regularUrl.isNotEmpty && image.regularUrl != 'discover') {
                      TabUtils.openInNewTab(ref, image.regularUrl);
                    }
                    // OLD: Show full image in dialog
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              children: [
                                CachedNetworkImage(
                                  imageUrl: image.regularUrl,
                                  fit: BoxFit.contain,
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    onPressed: () => Navigator.pop(context),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Photo by ${image.photographerName}',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'on Unsplash',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  if (image.altDescription != null) ...[
                                    const SizedBox(height: 8),
                                    Text(image.altDescription!),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: image.smallUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: theme.colorScheme.surfaceVariant,
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: theme.colorScheme.surfaceVariant,
                          child: const Icon(Icons.image, size: 48),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            'Photo by ${image.photographerName}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

