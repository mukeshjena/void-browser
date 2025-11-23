import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/news_provider.dart';
import 'news_card_widget.dart';
import '../../../browser/presentation/providers/browser_navigation_provider.dart';

class NewsCarouselWidget extends ConsumerStatefulWidget {
  const NewsCarouselWidget({super.key});

  @override
  ConsumerState<NewsCarouselWidget> createState() => _NewsCarouselWidgetState();
}

class _NewsCarouselWidgetState extends ConsumerState<NewsCarouselWidget> {
  @override
  void initState() {
    super.initState();
    // Load news when widget initializes
    Future.microtask(() => ref.read(newsProvider.notifier).loadTopHeadlines());
  }

  @override
  Widget build(BuildContext context) {
    // Use select to only watch specific fields to reduce rebuilds
    final articles = ref.watch(newsProvider.select((state) => state.articles));
    final isLoading = ref.watch(newsProvider.select((state) => state.isLoading));
    final error = ref.watch(newsProvider.select((state) => state.error));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top News',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Row(
                children: [
                  if (isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  if (!isLoading && articles.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        // Navigate to News tab (index 1 in bottom navigation)
                        ref.read(browserNavigationProvider.notifier).switchTab(1);
                      },
                      child: const Text('View All'),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (articles.isEmpty && !isLoading)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No news articles available'),
          ),
        if (articles.isNotEmpty)
          RepaintBoundary(
            child: SizedBox(
              height: 220, // Match the new card height
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: articles.length,
                itemBuilder: (context, index) {
                  return NewsCardWidget(
                    key: ValueKey('news_carousel_${articles[index].id}_$index'),
                    article: articles[index],
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

