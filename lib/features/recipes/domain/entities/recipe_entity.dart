class RecipeEntity {
  final String id;
  final String name;
  final String thumbnailUrl;
  final String category;
  final String? cuisine;
  final String instructions;
  final List<String> ingredients;
  final List<String> measures;
  final String? youtubeUrl;
  final String? sourceUrl;

  const RecipeEntity({
    required this.id,
    required this.name,
    required this.thumbnailUrl,
    required this.category,
    this.cuisine,
    required this.instructions,
    required this.ingredients,
    required this.measures,
    this.youtubeUrl,
    this.sourceUrl,
  });
}

