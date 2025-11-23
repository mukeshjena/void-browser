import '../../domain/entities/recipe_entity.dart';

class RecipeModel extends RecipeEntity {
  const RecipeModel({
    required super.id,
    required super.name,
    required super.thumbnailUrl,
    required super.category,
    super.cuisine,
    required super.instructions,
    required super.ingredients,
    required super.measures,
    super.youtubeUrl,
    super.sourceUrl,
  });

  factory RecipeModel.fromJson(Map<String, dynamic> json) {
    // Extract ingredients and measures
    List<String> ingredients = [];
    List<String> measures = [];

    for (int i = 1; i <= 20; i++) {
      final ingredient = json['strIngredient$i'];
      final measure = json['strMeasure$i'];

      if (ingredient != null && ingredient.toString().trim().isNotEmpty) {
        ingredients.add(ingredient.toString().trim());
        measures.add(measure?.toString().trim() ?? '');
      }
    }

    return RecipeModel(
      id: json['idMeal'] ?? '',
      name: json['strMeal'] ?? 'Unknown Recipe',
      thumbnailUrl: json['strMealThumb'] ?? '',
      category: json['strCategory'] ?? 'Unknown',
      cuisine: json['strArea'],
      instructions: json['strInstructions'] ?? 'No instructions available',
      ingredients: ingredients,
      measures: measures,
      youtubeUrl: json['strYoutube'],
      sourceUrl: json['strSource'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {
      'idMeal': id,
      'strMeal': name,
      'strMealThumb': thumbnailUrl,
      'strCategory': category,
      'strArea': cuisine,
      'strInstructions': instructions,
      'strYoutube': youtubeUrl,
      'strSource': sourceUrl,
    };

    // Add ingredients and measures
    for (int i = 0; i < ingredients.length; i++) {
      json['strIngredient${i + 1}'] = ingredients[i];
      json['strMeasure${i + 1}'] = i < measures.length ? measures[i] : '';
    }

    return json;
  }

  factory RecipeModel.fromEntity(RecipeEntity entity) {
    return RecipeModel(
      id: entity.id,
      name: entity.name,
      thumbnailUrl: entity.thumbnailUrl,
      category: entity.category,
      cuisine: entity.cuisine,
      instructions: entity.instructions,
      ingredients: entity.ingredients,
      measures: entity.measures,
      youtubeUrl: entity.youtubeUrl,
      sourceUrl: entity.sourceUrl,
    );
  }
}

