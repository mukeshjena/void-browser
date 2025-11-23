import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/news_provider.dart';
import '../widgets/news_card_widget.dart';
import '../widgets/hero_news_card.dart';
import '../widgets/compact_news_card.dart';
import '../widgets/horizontal_news_card.dart';
import '../../../../shared/widgets/shimmer_loading.dart';

class NewsScreen extends ConsumerStatefulWidget {
  const NewsScreen({super.key});

  @override
  ConsumerState<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen> {
  String _selectedCategory = 'all';
  late ScrollController _scrollController;
  
  final Map<String, IconData> _categories = {
    'all': Icons.grid_view_rounded,
    'technology': Icons.computer_rounded,
    'business': Icons.business_center_rounded,
    'sports': Icons.sports_soccer_rounded,
    'entertainment': Icons.movie_rounded,
    'health': Icons.favorite_rounded,
    'science': Icons.science_rounded,
  };

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    
    Future.microtask(() {
      if (mounted) {
        ref.read(newsProvider.notifier).loadTopHeadlines();
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
      ref.read(newsProvider.notifier).loadMore();
    }
  }

  void _onCategoryChanged(String category) {
    setState(() {
      _selectedCategory = category;
    });
    
    if (category == 'all') {
      ref.read(newsProvider.notifier).loadTopHeadlines(forceRefresh: true);
    } else {
      ref.read(newsProvider.notifier).loadNewsByCategory(category, forceRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use select to only watch specific fields to reduce rebuilds
    final articles = ref.watch(newsProvider.select((state) => state.articles));
    final isLoading = ref.watch(newsProvider.select((state) => state.isLoading));
    final isLoadingMore = ref.watch(newsProvider.select((state) => state.isLoadingMore));
    final error = ref.watch(newsProvider.select((state) => state.error));

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          if (_selectedCategory == 'all') {
            await ref.read(newsProvider.notifier).loadTopHeadlines(forceRefresh: true);
          } else {
            await ref.read(newsProvider.notifier).loadNewsByCategory(_selectedCategory, forceRefresh: true);
          }
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Add top padding for status bar
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.of(context).padding.top),
            ),
            // Category Chips - Modern design
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: _categories.entries.map((entry) {
                      final isSelected = _selectedCategory == entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _buildCategoryChip(
                          label: entry.key[0].toUpperCase() + entry.key.substring(1),
                          icon: entry.value,
                          isSelected: isSelected,
                          onTap: () => _onCategoryChanged(entry.key),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            // Content
            if (isLoading && articles.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ShimmerLoading(
                          width: double.infinity,
                          height: 200,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      );
                    },
                    childCount: 5,
                  ),
                ),
              )
            else if (error != null && articles.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(error, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => ref.read(newsProvider.notifier).loadTopHeadlines(forceRefresh: true),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (articles.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No news available\nPull down to refresh',
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
                      return _buildDynamicLayout(articles, index);
                    },
                    childCount: (articles.length / 3).ceil(),
                  ),
                ),
              ),

            // Loading more indicator
            if (isLoadingMore)
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
                  colors: [Color(0xFF5E35B1), Color(0xFF1E88E5)],
                )
              : null,
          color: isSelected ? null : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF5E35B1).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
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

  Widget _buildDynamicLayout(List articles, int groupIndex) {
    final startIndex = groupIndex * 3;
    
    // Ensure we don't go out of bounds
    if (startIndex >= articles.length) {
      return const SizedBox.shrink();
    }

    // Pattern 1: Hero card (full width)
    if (groupIndex % 4 == 0 && startIndex < articles.length) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: HeroNewsCard(article: articles[startIndex]),
      );
    }
    
    // Pattern 2: Two columns grid
    if (groupIndex % 4 == 1 && startIndex + 1 < articles.length) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: NewsCardWidget(article: articles[startIndex], isFullWidth: true),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NewsCardWidget(article: articles[startIndex + 1], isFullWidth: true),
            ),
          ],
        ),
      );
    }
    
    // Pattern 3: Horizontal scrolling cards
    if (groupIndex % 4 == 2) {
      final itemsToShow = articles.skip(startIndex).take(3).toList();
      if (itemsToShow.isEmpty) return const SizedBox.shrink();
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Trending Now',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            RepaintBoundary(
              child: SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: itemsToShow.length,
                  itemBuilder: (context, i) {
                    return SizedBox(
                      key: ValueKey('horizontal_news_${itemsToShow[i].id}_$i'),
                      width: 300,
                      child: Padding(
                        padding: EdgeInsets.only(right: i < itemsToShow.length - 1 ? 12 : 0),
                        child: HorizontalNewsCard(article: itemsToShow[i]),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // Pattern 4: Compact list
    final itemsToShow = articles.skip(startIndex).take(3).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: itemsToShow.asMap().entries.map((entry) {
          return Padding(
            padding: EdgeInsets.only(bottom: entry.key < itemsToShow.length - 1 ? 12 : 0),
            child: CompactNewsCard(article: entry.value),
          );
        }).toList(),
      ),
    );
  }
}
