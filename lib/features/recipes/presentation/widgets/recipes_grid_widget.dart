import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/recipes_provider.dart';
import 'recipe_card_widget.dart';

class RecipesGridWidget extends ConsumerStatefulWidget {
  const RecipesGridWidget({super.key});

  @override
  ConsumerState<RecipesGridWidget> createState() => _RecipesGridWidgetState();
}

class _RecipesGridWidgetState extends ConsumerState<RecipesGridWidget> {
  @override
  void initState() {
    super.initState();
    // Load random recipes when widget initializes
    Future.microtask(() => ref.read(recipesProvider.notifier).loadRandomRecipes());
  }

  @override
  Widget build(BuildContext context) {
    final recipesState = ref.watch(recipesProvider);
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
                'Delicious Recipes',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (recipesState.isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        if (recipesState.error != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              recipesState.error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        if (recipesState.recipes.isEmpty && !recipesState.isLoading)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No recipes available'),
          ),
        if (recipesState.recipes.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.82, // Increased from 0.75 to fix overflow
            ),
            itemCount: recipesState.recipes.length > 6 ? 6 : recipesState.recipes.length,
            itemBuilder: (context, index) {
              return RecipeCardWidget(recipe: recipesState.recipes[index]);
            },
          ),
      ],
    );
  }
}

