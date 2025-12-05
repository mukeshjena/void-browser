import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/images_provider.dart';
import '../widgets/masonry_image_card.dart';
import '../widgets/wide_image_card.dart';
import '../widgets/square_image_card.dart';
import '../widgets/portrait_image_card.dart';
import 'image_detail_screen.dart';
import '../../../../shared/widgets/shimmer_loading.dart';

class ImagesScreen extends ConsumerStatefulWidget {
  const ImagesScreen({super.key});

  @override
  ConsumerState<ImagesScreen> createState() => _ImagesScreenState();
}

class _ImagesScreenState extends ConsumerState<ImagesScreen> {
  final ScrollController _scrollController = ScrollController();
  
  final List<Map<String, dynamic>> _categories = [
    {'name': 'All', 'icon': Icons.grid_view_rounded, 'query': ''},
    {'name': 'Nature', 'icon': Icons.landscape, 'query': 'nature'},
    {'name': 'Architecture', 'icon': Icons.location_city, 'query': 'architecture'},
    {'name': 'Animals', 'icon': Icons.pets, 'query': 'animals'},
    {'name': 'Technology', 'icon': Icons.computer, 'query': 'technology'},
    {'name': 'Food', 'icon': Icons.restaurant, 'query': 'food'},
    {'name': 'Travel', 'icon': Icons.flight, 'query': 'travel'},
    {'name': 'Art', 'icon': Icons.palette, 'query': 'art'},
  ];

  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      if (mounted) {
        ref.read(imagesProvider.notifier).loadRandomImages();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 500) {
      // Load more when 500px from bottom
      ref.read(imagesProvider.notifier).loadMore();
    }
  }

  void _onCategoryChanged(String category, String query) {
    setState(() {
      _selectedCategory = category;
    });
    
    if (query.isEmpty) {
      ref.read(imagesProvider.notifier).loadRandomImages(forceRefresh: true);
    } else {
      ref.read(imagesProvider.notifier).searchImages(query);
    }
  }

  void _openImageDetail(BuildContext context, dynamic image) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ImageDetailScreen(image: image),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imagesState = ref.watch(imagesProvider);
    final images = imagesState.images;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          final query = _categories.firstWhere(
            (cat) => cat['name'] == _selectedCategory,
            orElse: () => {'query': ''},
          )['query'] as String;
          
          if (query.isEmpty) {
            await ref.read(imagesProvider.notifier).loadRandomImages(forceRefresh: true);
          } else {
            await ref.read(imagesProvider.notifier).searchImages(query);
          }
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Add top padding for status bar
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.of(context).padding.top),
            ),
            // Category Chips
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: _categories.map((category) {
                      final isSelected = _selectedCategory == category['name'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _buildCategoryChip(
                          label: category['name'] as String,
                          icon: category['icon'] as IconData,
                          isSelected: isSelected,
                          onTap: () => _onCategoryChanged(
                            category['name'] as String,
                            category['query'] as String,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            // Content
            if (imagesState.isLoading && images.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return ShimmerLoading(
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: BorderRadius.circular(16),
                      );
                    },
                    childCount: 6,
                  ),
                ),
              )
            else if (imagesState.error != null && images.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(imagesState.error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => ref.read(imagesProvider.notifier).loadRandomImages(forceRefresh: true),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (images.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.collections_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No images available\nPull down to refresh',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return _buildDynamicLayout(images, index, context);
                    },
                    childCount: (images.length / 3).ceil(),
                  ),
                ),
              ),

            // Loading more indicator
            if (imagesState.isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: CircularShimmer(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                )
              : null,
          color: isSelected ? null : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicLayout(List images, int groupIndex, BuildContext context) {
    final startIndex = groupIndex * 3;
    
    if (startIndex >= images.length) {
      return const SizedBox.shrink();
    }

    // Pattern 1: Wide hero image
    if (groupIndex % 5 == 0 && startIndex < images.length) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: WideImageCard(
          image: images[startIndex],
          heroPrefix: 'images_',
          onTap: () => _openImageDetail(context, images[startIndex]),
        ),
      );
    }
    
    // Pattern 2: Two squares side by side
    if (groupIndex % 5 == 1 && startIndex + 1 < images.length) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            Expanded(
              child: SquareImageCard(
                image: images[startIndex],
                heroPrefix: 'images_',
                onTap: () => _openImageDetail(context, images[startIndex]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SquareImageCard(
                image: images[startIndex + 1],
                heroPrefix: 'images_',
                onTap: () => _openImageDetail(context, images[startIndex + 1]),
              ),
            ),
          ],
        ),
      );
    }
    
    // Pattern 3: Portrait + 2 squares grid
    if (groupIndex % 5 == 2 && startIndex + 2 < images.length) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: PortraitImageCard(
                image: images[startIndex],
                heroPrefix: 'images_',
                onTap: () => _openImageDetail(context, images[startIndex]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  SquareImageCard(
                    image: images[startIndex + 1],
                    heroPrefix: 'images_',
                    onTap: () => _openImageDetail(context, images[startIndex + 1]),
                  ),
                  const SizedBox(height: 12),
                  SquareImageCard(
                    image: images[startIndex + 2],
                    heroPrefix: 'images_',
                    onTap: () => _openImageDetail(context, images[startIndex + 2]),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
    // Pattern 4: Masonry 3-column
    if (groupIndex % 5 == 3 && startIndex + 2 < images.length) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: MasonryImageCard(
                image: images[startIndex],
                height: 200,
                heroPrefix: 'images_',
                onTap: () => _openImageDetail(context, images[startIndex]),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MasonryImageCard(
                image: images[startIndex + 1],
                height: 250,
                heroPrefix: 'images_',
                onTap: () => _openImageDetail(context, images[startIndex + 1]),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MasonryImageCard(
                image: images[startIndex + 2],
                height: 180,
                heroPrefix: 'images_',
                onTap: () => _openImageDetail(context, images[startIndex + 2]),
              ),
            ),
          ],
        ),
      );
    }
    
    // Pattern 5: Single wide + two squares below
    final itemsToShow = images.skip(startIndex).take(3).toList();
    if (itemsToShow.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          WideImageCard(
            image: itemsToShow[0],
            heroPrefix: 'images_',
            onTap: () => _openImageDetail(context, itemsToShow[0]),
          ),
          if (itemsToShow.length > 1) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (itemsToShow.length > 1)
                  Expanded(
                    child: SquareImageCard(
                      image: itemsToShow[1],
                      heroPrefix: 'images_',
                      onTap: () => _openImageDetail(context, itemsToShow[1]),
                    ),
                  ),
                if (itemsToShow.length > 2) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: SquareImageCard(
                      image: itemsToShow[2],
                      heroPrefix: 'images_',
                      onTap: () => _openImageDetail(context, itemsToShow[2]),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

