import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

class Recipe {
  final String name;
  final String description;
  final List<String> ingredients;
  final List<String> steps;
  final String difficulty;
  final String prepTime;
  final String cookTime;
  final String servings;
  final String category;
  final String imageEmoji;

  Recipe({
    required this.name,
    required this.description,
    required this.ingredients,
    required this.steps,
    required this.difficulty,
    required this.prepTime,
    required this.cookTime,
    required this.servings,
    required this.category,
    required this.imageEmoji,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      name: json['name'],
      description: json['description'],
      ingredients: List<String>.from(json['ingredients']),
      steps: List<String>.from(json['steps']),
      difficulty: json['difficulty'],
      prepTime: json['prepTime'],
      cookTime: json['cookTime'],
      servings: json['servings'],
      category: json['category'],
      imageEmoji: json['imageEmoji'],
    );
  }
}

class RecipeService {
  final GenerativeModel _model;

  RecipeService({required String apiKey})
      : _model = GenerativeModel(
          model: 'gemini-2.0-flash',
          apiKey: apiKey,
        );

  Future<List<Recipe>> getRecipeSuggestions(String foodItem) async {
    try {
      final prompt = '''
Generate 3 creative recipe suggestions for $foodItem. 
For each recipe, provide the following in JSON format:
{
  "name": "Recipe name",
  "description": "Brief description",
  "ingredients": ["list", "of", "ingredients"],
  "steps": ["step 1", "step 2", "etc"],
  "difficulty": "Easy/Medium/Hard",
  "prepTime": "X mins",
  "cookTime": "X mins",
  "servings": "X servings",
  "category": "Main Course/Dessert/Snack/etc",
  "imageEmoji": "relevant food emoji"
}
Return the response as a JSON array of 3 recipes.
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final responseText = response.text;

      if (responseText == null) {
        throw Exception('Failed to generate recipes');
      }

      // Extract JSON array from the response
      final jsonString = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
      final List<dynamic> recipesJson = json.decode(jsonString);
      
      return recipesJson.map((json) => Recipe.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to generate recipes: $e');
    }
  }

  Future<List<Recipe>> getRecipeSuggestionsForMultipleItems(List<String> foodItems) async {
    try {
      final itemsList = foodItems.join(', ');
      final prompt = '''
Generate 3 creative recipe suggestions that combine some or all of these ingredients: $itemsList. 
Prioritize recipes that use multiple items from the list to reduce food waste.
For each recipe, provide the following in JSON format:
{
  "name": "Recipe name",
  "description": "Brief description",
  "ingredients": ["list", "of", "ingredients"],
  "steps": ["step 1", "step 2", "etc"],
  "difficulty": "Easy/Medium/Hard",
  "prepTime": "X mins",
  "cookTime": "X mins",
  "servings": "X servings",
  "category": "Main Course/Dessert/Snack/etc",
  "imageEmoji": "relevant food emoji"
}
Return the response as a JSON array of 3 recipes.
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final responseText = response.text;

      if (responseText == null) {
        throw Exception('Failed to generate recipes');
      }

      // Extract JSON array from the response
      final jsonString = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
      final List<dynamic> recipesJson = json.decode(jsonString);
      
      return recipesJson.map((json) => Recipe.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to generate recipes for multiple items: $e');
    }
  }
} 