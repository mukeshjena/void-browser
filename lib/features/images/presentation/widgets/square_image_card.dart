import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SquareImageCard extends StatelessWidget {
  final dynamic image;
  final VoidCallback onTap;
  final String? heroPrefix;

  const SquareImageCard({
    super.key,
    required this.image,
    required this.onTap,
    this.heroPrefix,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: '${heroPrefix ?? ""}image_${image.id}',
      child: Card(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AspectRatio(
            aspectRatio: 1,
            child: CachedNetworkImage(
              imageUrl: image.smallUrl,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 200),
              fadeOutDuration: const Duration(milliseconds: 100),
              memCacheWidth: 300, // Limit memory cache size for better performance
              memCacheHeight: 300,
              placeholder: (context, url) => Container(
                color: Colors.grey[300],
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[300],
                child: const Icon(Icons.error, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

