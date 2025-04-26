import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';

class WasteDisposalSuggestion {
  final String category;
  final String suggestion;
  final String description;
  final List<String> steps;
  final String environmentalImpact;
  final String location;
  final String difficulty;
  final String emoji;

  WasteDisposalSuggestion({
    required this.category,
    required this.suggestion,
    required this.description,
    required this.steps,
    required this.environmentalImpact,
    required this.location,
    required this.difficulty,
    this.emoji = '♻️',
  });

  factory WasteDisposalSuggestion.fromJson(Map<String, dynamic> json) {
    return WasteDisposalSuggestion(
      category: json['category'] as String,
      suggestion: json['suggestion'] as String,
      description: json['description'] as String,
      steps: (json['steps'] as List<dynamic>).map((e) => e as String).toList(),
      environmentalImpact: json['environmentalImpact'] as String,
      location: json['location'] as String,
      difficulty: json['difficulty'] as String,
    );
  }

  @override
  String toString() {
    return 'WasteDisposalSuggestion(category: $category, suggestion: $suggestion, steps: ${steps.length} steps)';
  }
}

class WasteManagementService {
  final GenerativeModel _model;

  WasteManagementService({required String apiKey})
      : _model = GenerativeModel(
          model: 'gemini-2.0-flash',
          apiKey: apiKey,
        );

  Future<List<WasteDisposalSuggestion>> getSustainableSuggestions(String foodItem) async {
    try {
      final prompt = '''
Generate 3 sustainable waste management suggestions for disposing of $foodItem waste.
For each suggestion, provide the following in JSON format:
{
  "category": "Composting/Recycling/Reuse/etc",
  "suggestion": "Brief title of the suggestion",
  "description": "Detailed explanation",
  "steps": ["step 1", "step 2", "etc"],
  "environmentalImpact": "Brief explanation of environmental benefits",
  "location": "Where to dispose (e.g., Home composting, Local recycling center)",
  "difficulty": "Easy/Medium/Hard"
}
Return the response as a JSON array of 3 suggestions.
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        throw Exception('Empty response from model');
      }

      return _parseSuggestions(responseText);
    } catch (e) {
      throw Exception('Failed to generate waste management suggestions: $e');
    }
  }

  Future<List<WasteDisposalSuggestion>> getSustainableSuggestionsForMultipleItems(List<String> foodItems) async {
    try {
      final itemsList = foodItems.join(', ');
      final prompt = '''
Generate 3 sustainable waste management suggestions for disposing of waste from these items: $itemsList.
Focus on solutions that can handle multiple types of waste efficiently.
For each suggestion, provide the following in JSON format:
{
  "category": "Composting/Recycling/Reuse/etc",
  "suggestion": "Brief title of the suggestion",
  "description": "Detailed explanation",
  "steps": ["step 1", "step 2", "etc"],
  "environmentalImpact": "Brief explanation of environmental benefits",
  "location": "Where to dispose (e.g., Home composting, Local recycling center)",
  "difficulty": "Easy/Medium/Hard"
}
Return the response as a JSON array of 3 suggestions.
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        throw Exception('Empty response from model');
      }

      return _parseSuggestions(responseText);
    } catch (e) {
      throw Exception('Failed to generate waste management suggestions for multiple items: $e');
    }
  }

  Future<List<WasteDisposalSuggestion>> getLocationBasedSuggestions(String foodItem, String location) async {
    try {
      final prompt = '''
Generate 3 sustainable waste management suggestions for disposing of $foodItem waste in $location.
Focus on locally available solutions and facilities.
For each suggestion, provide the following in JSON format:
{
  "category": "Composting/Recycling/Reuse/etc",
  "suggestion": "Brief title of the suggestion",
  "description": "Detailed explanation considering local context",
  "steps": ["step 1", "step 2", "etc"],
  "environmentalImpact": "Brief explanation of environmental benefits",
  "location": "Specific local facility or method in $location",
  "difficulty": "Easy/Medium/Hard"
}
Return the response as a JSON array of 3 suggestions.
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        throw Exception('Empty response from model');
      }

      return _parseSuggestions(responseText);
    } catch (e) {
      throw Exception('Failed to generate location-based waste management suggestions: $e');
    }
  }

  List<WasteDisposalSuggestion> _parseSuggestions(String responseText) {
    try {
      // Extract JSON array from the response
      final jsonString = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
      final List<dynamic> suggestionsJson = json.decode(jsonString);
      
      return suggestionsJson.map((json) => WasteDisposalSuggestion.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to parse suggestions: $e');
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1).toLowerCase()}";
  }
} 