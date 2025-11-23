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
    final newsState = ref.watch(newsProvider);

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
                  if (newsState.isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  if (!newsState.isLoading && newsState.articles.isNotEmpty)
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
        if (newsState.error != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              newsState.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (newsState.articles.isEmpty && !newsState.isLoading)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No news articles available'),
          ),
        if (newsState.articles.isNotEmpty)
          SizedBox(
            height: 220, // Match the new card height
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: newsState.articles.length,
              itemBuilder: (context, index) {
                return NewsCardWidget(article: newsState.articles[index]);
              },
            ),
          ),
      ],
    );
  }
}

