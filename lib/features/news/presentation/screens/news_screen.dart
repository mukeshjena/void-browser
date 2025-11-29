import 'dart:async';
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

class _NewsScreenState extends ConsumerState<NewsScreen> with WidgetsBindingObserver {
  String _selectedCategory = 'all';
  late ScrollController _scrollController;
  bool _hasLoaded = false;
  
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
    WidgetsBinding.instance.addObserver(this);
  }

  void _loadNews() {
    if (mounted) {
      // Load news - will use cache if available, otherwise fetch fresh
      ref.read(newsProvider.notifier).loadTopHeadlines(category: 'general', forceRefresh: false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Always try to load news when screen becomes visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final newsState = ref.read(newsProvider);
        // Load if we don't have articles or if we're not already loading
        if (newsState.articles.isEmpty && !newsState.isLoading && !_hasLoaded) {
          _hasLoaded = true;
          _loadNews();
        } else if (!_hasLoaded) {
          _hasLoaded = true;
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Reload when app comes back to foreground
      _loadNews();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Throttle scroll events for better performance
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 500) {
      // Load more when 500px from bottom
      // Use scheduleMicrotask to avoid blocking scroll
      scheduleMicrotask(() {
        if (mounted) {
          ref.read(newsProvider.notifier).loadMore();
        }
      });
    }
  }

  void _onCategoryChanged(String category) {
    setState(() {
      _selectedCategory = category;
    });
    
    if (category == 'all') {
      // 'all' maps to 'general' category in the API
      ref.read(newsProvider.notifier).loadTopHeadlines(category: 'general', forceRefresh: true);
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

    // Ensure news is loaded if we have no articles and not loading
    if (articles.isEmpty && !isLoading && !_hasLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _hasLoaded = true;
          _loadNews();
        }
      });
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          if (_selectedCategory == 'all') {
            // 'all' maps to 'general' category in the API
            await ref.read(newsProvider.notifier).loadTopHeadlines(category: 'general', forceRefresh: true);
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
            // Category Chips - Modern design (always visible)
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
            else if (articles.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= (articles.length / 3).ceil()) {
                        return const SizedBox.shrink();
                      }
                      try {
                        return RepaintBoundary(
                          child: _buildDynamicLayout(articles, index),
                        );
                      } catch (e) {
                        // Return empty widget if there's an error building the layout
                        return const SizedBox.shrink();
                      }
                    },
                    childCount: (articles.length / 3).ceil(),
                    // Performance optimization: estimate item extent
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: false, // We add RepaintBoundary manually
                  ),
                ),
              )
            else
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
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
          color: isSelected ? null : (isDark ? Colors.grey[800] : Colors.grey[200]),
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
              color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
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
    if (articles.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final startIndex = groupIndex * 3;
    
    // Ensure we don't go out of bounds
    if (startIndex >= articles.length) {
      return const SizedBox.shrink();
    }

    try {
      // Pattern 1: Hero card (full width)
      if (groupIndex % 4 == 0 && startIndex < articles.length) {
        final article = articles[startIndex];
        if (article.url.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: RepaintBoundary(
            key: ValueKey('hero_news_${article.id}'),
            child: HeroNewsCard(article: article),
          ),
        );
      }
      
      // Pattern 2: Two columns grid
      if (groupIndex % 4 == 1 && startIndex + 1 < articles.length) {
        final article1 = articles[startIndex];
        final article2 = articles[startIndex + 1];
        if (article1.url.isEmpty || article2.url.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: RepaintBoundary(
            key: ValueKey('grid_news_${article1.id}_${article2.id}'),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: NewsCardWidget(article: article1, isFullWidth: true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NewsCardWidget(article: article2, isFullWidth: true),
                ),
              ],
            ),
          ),
        );
      }
      
      // Pattern 3: Horizontal scrolling cards
      if (groupIndex % 4 == 2) {
        final itemsToShow = articles.skip(startIndex).take(3).where((a) => a.url.isNotEmpty).toList();
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
                    itemExtent: 312, // 300 + 12 padding for better performance
                    cacheExtent: 500, // Pre-render items outside viewport
                    itemBuilder: (context, i) {
                      return RepaintBoundary(
                        key: ValueKey('horizontal_news_${itemsToShow[i].id}_$i'),
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
      final itemsToShow = articles.skip(startIndex).take(3).where((a) => a.url.isNotEmpty).toList();
      if (itemsToShow.isEmpty) return const SizedBox.shrink();
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          children: itemsToShow.asMap().entries.map((entry) {
            return RepaintBoundary(
              key: ValueKey('compact_news_${entry.value.id}_${entry.key}'),
              child: Padding(
                padding: EdgeInsets.only(bottom: entry.key < itemsToShow.length - 1 ? 12 : 0),
                child: CompactNewsCard(article: entry.value),
              ),
            );
          }).toList(),
        ),
      );
    } catch (e) {
      // Return empty widget if there's an error
      return const SizedBox.shrink();
    }
  }
}
