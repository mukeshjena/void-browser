import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../news/presentation/providers/news_provider.dart';
import '../../../recipes/presentation/providers/recipes_provider.dart';
import '../../../weather/presentation/providers/weather_provider.dart';
import '../../../images/presentation/providers/images_provider.dart';
import '../../../news/presentation/widgets/horizontal_news_card.dart';
import '../../../recipes/presentation/widgets/recipe_card_widget.dart';
import '../../../images/presentation/widgets/square_image_card.dart';
import '../../../weather/presentation/widgets/weather_card_widget.dart';
import '../../../browser/presentation/providers/browser_navigation_provider.dart';
import '../../../images/presentation/screens/image_detail_screen.dart';
import '../../../../shared/widgets/shimmer_loading.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    
    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final newsState = ref.read(newsProvider);
      final recipesState = ref.read(recipesProvider);
      final weatherState = ref.read(weatherProvider);
      final imagesState = ref.read(imagesProvider);

      if (newsState.articles.isEmpty && !newsState.isLoading) {
        ref.read(newsProvider.notifier).loadTopHeadlines();
      }
      if (recipesState.recipes.isEmpty && !recipesState.isLoading) {
        ref.read(recipesProvider.notifier).loadRandomRecipes();
      }
      // Automatically load weather by GPS location
      if (weatherState.weather == null && !weatherState.isLoading) {
        _loadWeatherByGPS();
      }
      if (imagesState.images.isEmpty && !imagesState.isLoading) {
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
      // Load more news when 500px from bottom
      ref.read(newsProvider.notifier).loadMore();
    }
  }

  Future<void> _loadWeatherByGPS() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services disabled, fallback to default city
        ref.read(weatherProvider.notifier).loadWeatherByCity('London');
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Permission denied, fallback to default city
          ref.read(weatherProvider.notifier).loadWeatherByCity('London');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permission permanently denied, fallback to default city
        ref.read(weatherProvider.notifier).loadWeatherByCity('London');
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10), // Timeout after 10 seconds
      );

      // Fetch weather based on GPS coordinates
      await ref.read(weatherProvider.notifier).loadWeatherByLocation(
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      // If GPS fails, try to load from cache or fallback to default city
      final weatherState = ref.read(weatherProvider);
      if (weatherState.weather == null) {
        // Only fallback if no cached weather exists
        ref.read(weatherProvider.notifier).loadWeatherByCity('London');
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // Use select to only rebuild when specific data changes, not entire state
    final newsArticles = ref.watch(newsProvider.select((state) => state.articles));
    final newsIsLoading = ref.watch(newsProvider.select((state) => state.isLoading));
    final newsIsLoadingMore = ref.watch(newsProvider.select((state) => state.isLoadingMore));
    
    final recipes = ref.watch(recipesProvider.select((state) => state.recipes));
    final recipesIsLoading = ref.watch(recipesProvider.select((state) => state.isLoading));
    
    final images = ref.watch(imagesProvider.select((state) => state.images));
    final imagesIsLoading = ref.watch(imagesProvider.select((state) => state.isLoading));

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait<void>([
            ref.read(newsProvider.notifier).loadTopHeadlines(forceRefresh: true),
            ref.read(recipesProvider.notifier).loadRandomRecipes(forceRefresh: true),
            ref.read(imagesProvider.notifier).loadRandomImages(forceRefresh: true),
          ]);
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Add top padding for status bar (since AppBar is in browser_tab_screen)
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.of(context).padding.top),
            ),
            
            // Hero Weather Card
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                child: const WeatherCardWidget(),
              ),
            ),

            // Section: Top Stories
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5E35B1), Color(0xFF1E88E5)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.local_fire_department, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Top Stories',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        ref.read(browserNavigationProvider.notifier).switchTab(1);
                      },
                      child: const Row(
                        children: [
                          Text('View All'),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // News Horizontal Carousel - No overflow, modern design
            if (newsArticles.isNotEmpty)
              SliverToBoxAdapter(
                child: RepaintBoundary(
                  child: SizedBox(
                    height: 220,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: newsArticles.length > 10 ? 10 : newsArticles.length,
                      itemBuilder: (context, index) {
                        return SizedBox(
                          key: ValueKey('news_${newsArticles[index].id}_$index'),
                          width: 300,
                          child: Padding(
                            padding: EdgeInsets.only(right: index < 9 ? 16 : 0),
                            child: HorizontalNewsCard(
                              article: newsArticles[index],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

            // Loading more indicator for news
            if (newsIsLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: CircularShimmer(),
                  ),
                ),
              ),
            
            // News shimmer loader for initial load
            if (newsIsLoading && newsArticles.isEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 220,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: EdgeInsets.only(right: index < 2 ? 16 : 0),
                        child: const NewsCardShimmer(),
                      );
                    },
                  ),
                ),
              ),

            // Section: Recipes
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.restaurant_menu, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Delicious Recipes',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Recipes 2-Column Grid
            if (recipes.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= 4) return null; // Show only 4 recipes
                      return RecipeCardWidget(
                        key: ValueKey('recipe_${recipes[index].id}_$index'),
                        recipe: recipes[index],
                      );
                    },
                    childCount: recipes.length > 4 ? 4 : recipes.length,
                  ),
                ),
              ),
            
            // Recipes shimmer loader for initial load
            if (recipesIsLoading && recipes.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return const RecipeCardShimmer();
                    },
                    childCount: 4,
                  ),
                ),
              ),

            // Section: Image Gallery
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.photo_library, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Stunning Images',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        ref.read(browserNavigationProvider.notifier).switchTab(2);
                      },
                      child: const Row(
                        children: [
                          Text('View All'),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Images Masonry Grid
            if (images.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= 6) return null;
                      return SquareImageCard(
                        key: ValueKey('image_${images[index].id}_$index'),
                        image: images[index],
                        heroPrefix: 'discover_',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ImageDetailScreen(
                                image: images[index],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    childCount: images.length > 6 ? 6 : images.length,
                  ),
                ),
              ),
            
            // Images shimmer loader for initial load
            if (imagesIsLoading && images.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return const ImageCardShimmer();
                    },
                    childCount: 6,
                  ),
                ),
              ),

            // Bottom spacing
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
          ],
        ),
      ),
    );
  }
}
