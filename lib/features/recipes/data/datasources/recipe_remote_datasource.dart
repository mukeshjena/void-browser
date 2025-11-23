import 'package:dio/dio.dart';
import '../models/recipe_model.dart';

abstract class RecipeRemoteDataSource {
  Future<List<RecipeModel>> getRandomRecipes();
  Future<List<RecipeModel>> searchRecipes(String query);
  Future<RecipeModel> getRecipeById(String id);
  Future<List<RecipeModel>> getRecipesByCategory(String category);
}

class RecipeRemoteDataSourceImpl implements RecipeRemoteDataSource {
  final Dio dio;

  RecipeRemoteDataSourceImpl({required this.dio});

  // TheMealDB is completely free - no API key needed!
  static const String baseUrl = 'https://www.themealdb.com/api/json/v1/1';

  @override
  Future<List<RecipeModel>> getRandomRecipes() async {
    try {
      // Get 10 random meals
      List<RecipeModel> recipes = [];
      for (int i = 0; i < 10; i++) {
        final response = await dio.get('$baseUrl/random.php');
        if (response.statusCode == 200 && response.data['meals'] != null) {
          final meal = RecipeModel.fromJson(response.data['meals'][0]);
          recipes.add(meal);
        }
      }
      return recipes;
    } catch (e) {
      throw Exception('Error fetching random recipes: $e');
    }
  }

  @override
  Future<List<RecipeModel>> searchRecipes(String query) async {
    try {
      final response = await dio.get('$baseUrl/search.php', queryParameters: {'s': query});

      if (response.statusCode == 200 && response.data['meals'] != null) {
        final recipes = (response.data['meals'] as List)
            .map((json) => RecipeModel.fromJson(json))
            .toList();
        return recipes;
      }
      return [];
    } catch (e) {
      throw Exception('Error searching recipes: $e');
    }
  }

  @override
  Future<RecipeModel> getRecipeById(String id) async {
    try {
      final response = await dio.get('$baseUrl/lookup.php', queryParameters: {'i': id});

      if (response.statusCode == 200 && response.data['meals'] != null) {
        return RecipeModel.fromJson(response.data['meals'][0]);
      } else {
        throw Exception('Recipe not found');
      }
    } catch (e) {
      throw Exception('Error fetching recipe: $e');
    }
  }

  @override
  Future<List<RecipeModel>> getRecipesByCategory(String category) async {
    try {
      final response = await dio.get('$baseUrl/filter.php', queryParameters: {'c': category});

      if (response.statusCode == 200 && response.data['meals'] != null) {
        final recipes = (response.data['meals'] as List)
            .map((json) => RecipeModel.fromJson(json))
            .toList();
        return recipes;
      }
      return [];
    } catch (e) {
      throw Exception('Error fetching recipes by category: $e');
    }
  }
}

