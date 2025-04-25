import 'package:google_generative_ai/google_generative_ai.dart';

class WasteDisposalSuggestion {
  final String category;
  final String suggestion;
  final String? details;
  final String emoji;
  final List<String> steps;
  final String? location;

  WasteDisposalSuggestion({
    required this.category,
    required this.suggestion,
    this.details,
    required this.emoji,
    List<String>? steps,
    this.location,
  }) : steps = steps ?? [];

  @override
  String toString() {
    return 'WasteDisposalSuggestion(category: $category, suggestion: $suggestion, steps: ${steps.length} steps)';
  }
}

class WasteManagementService {
  final GenerativeModel? _model;
  
  WasteManagementService({String? apiKey})
      : _model = apiKey != null
            ? GenerativeModel(
                model: 'gemini-2.0-flash',
                apiKey: apiKey,
              )
            : null;

  Future<List<WasteDisposalSuggestion>> getSustainableSuggestions(String foodItem) async {
    if (_model == null) {
      throw Exception('Gemini API key not configured');
    }

    final prompt = '''As a Malaysian sustainability expert, provide 3 practical household solutions for managing $foodItem waste. Format your response EXACTLY as shown:

[REUSE]
Title: Simple home reuse method
Steps:
- First step here
- Second step here
- Final step here

[COMPOST]
Title: Easy home composting
Steps:
- First step here
- Second step here
- Final step here

[DISPOSE]
Title: Safe disposal method
Location: Specific location or facility name in Malaysia
Steps:
- First step here
- Second step here

Make all suggestions:
1. Easy for home use
2. Using basic household items
3. Safe for families
4. Quick (under 30 mins)
5. Suitable for Malaysian climate''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);
      print('Raw Gemini response: ${response.text}'); // Debug print
      
      if (response.text == null || response.text!.isEmpty) {
        print('Error: Empty response from Gemini');
        return [
          WasteDisposalSuggestion(
            category: 'Error',
            suggestion: 'No suggestions available',
            emoji: '⚠️',
            steps: ['Please try again later'],
          )
        ];
      }

      final suggestions = _parseSuggestions(response.text!);
      
      if (suggestions.isEmpty) {
        print('Error: No suggestions parsed from response');
        return [
          WasteDisposalSuggestion(
            category: 'Error',
            suggestion: 'Could not parse suggestions',
            emoji: '⚠️',
            steps: ['Please try again with a different food item'],
          )
        ];
      }

      return suggestions;
    } catch (e) {
      print('Error getting suggestions: $e'); // Debug print
      return [
        WasteDisposalSuggestion(
          category: 'Error',
          suggestion: 'Error getting suggestions',
          emoji: '⚠️',
          steps: ['Error: $e', 'Please try again later'],
        )
      ];
    }
  }

  List<WasteDisposalSuggestion> _parseSuggestions(String response) {
    final suggestions = <WasteDisposalSuggestion>[];
    print('Starting to parse response...'); // Debug print

    // Split by section headers
    final sectionRegex = RegExp(r'\[(REUSE|COMPOST|DISPOSE)\]');
    final matches = sectionRegex.allMatches(response);
    
    if (matches.isEmpty) {
      print('No section headers found in response'); // Debug print
      return [];
    }

    // Process each section
    for (var i = 0; i < matches.length; i++) {
      final match = matches.elementAt(i);
      final category = match.group(1)!;
      
      // Get the content until the next section or end
      final startIndex = match.end;
      final endIndex = i < matches.length - 1 ? matches.elementAt(i + 1).start : response.length;
      final sectionContent = response.substring(startIndex, endIndex).trim();
      
      print('Parsing section: $category'); // Debug print
      print('Section content: $sectionContent'); // Debug print

      // Parse the section content
      String title = '';
      List<String> steps = [];
      String? location;

      final lines = sectionContent.split('\n');
      var inSteps = false;

      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;

        if (trimmedLine.startsWith('Title:')) {
          title = trimmedLine.substring('Title:'.length).trim();
          print('Found title: $title'); // Debug print
        } else if (trimmedLine.startsWith('Steps:')) {
          inSteps = true;
        } else if (trimmedLine.startsWith('Location:')) {
          location = trimmedLine.substring('Location:'.length).trim();
          print('Found location: $location'); // Debug print
        } else if (trimmedLine.startsWith('-') && inSteps) {
          final step = trimmedLine.substring(1).trim();
          steps.add(step);
          print('Added step: $step'); // Debug print
        }
      }

      if (title.isNotEmpty) {
        String emoji;
        switch (category) {
          case 'REUSE':
            emoji = '♻️';
            break;
          case 'COMPOST':
            emoji = '🌱';
            break;
          case 'DISPOSE':
            emoji = '🗑️';
            break;
          default:
            emoji = '📝';
        }

        // Ensure we have at least one step
        if (steps.isEmpty) {
          steps = ['Instructions not provided'];
        }

        suggestions.add(WasteDisposalSuggestion(
          category: category.capitalize(),
          emoji: emoji,
          suggestion: title,
          details: steps.join('\n'),
          steps: steps,
          location: location,
        ));

        print('Added suggestion for category: $category'); // Debug print
      }
    }

    print('Parsed ${suggestions.length} suggestions'); // Debug print
    return suggestions;
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1).toLowerCase()}";
  }
} 