import 'package:google_generative_ai/google_generative_ai.dart';

class FoodInformation {
  final String name;
  final double carbonFootprint;
  final List<String> storageTips;
  final bool isLocallyGrown;

  FoodInformation({
    required this.name,
    required this.carbonFootprint,
    required this.storageTips,
    required this.isLocallyGrown,
  });
}

class FoodAnalysisService {
  final GenerativeModel? _model;
  
  FoodAnalysisService({String? apiKey})
      : _model = apiKey != null
            ? GenerativeModel(
                model: 'gemini-2.0-flash',
                apiKey: apiKey,
              )
            : null;

  Future<FoodInformation> getFoodInformation(String foodItem) async {
    if (_model == null) {
      throw Exception('Gemini API key not configured');
    }

    final prompt = '''As a food sustainability expert, provide information about $foodItem in the following format:

[CARBON_FOOTPRINT]
Provide the carbon footprint in kg CO2e per kg. Give a single number between 0.1 and 5.0.

[STORAGE_TIPS]
- First storage tip
- Second storage tip
- Third storage tip
(Provide exactly 3 practical, concise tips)

[LOCAL]
true/false (Is it commonly grown locally in Malaysia?)

Please provide accurate, concise information focusing on practical storage tips and local context for Malaysia.''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);
      
      if (response.text == null || response.text!.isEmpty) {
        throw Exception('Empty response from API');
      }

      return _parseFoodInformation(foodItem, response.text!);
    } catch (e) {
      throw Exception('Error getting food information: $e');
    }
  }

  FoodInformation _parseFoodInformation(String foodItem, String response) {
    double carbonFootprint = 0.4; // default value
    List<String> storageTips = [];
    bool isLocallyGrown = false;

    final sections = response.split('[');
    
    for (var section in sections) {
      if (section.startsWith('CARBON_FOOTPRINT]')) {
        final footprintText = section
            .replaceAll('CARBON_FOOTPRINT]', '')
            .trim()
            .split('\n')[0]
            .replaceAll(RegExp(r'[^\d.]'), '');
        try {
          carbonFootprint = double.parse(footprintText);
        } catch (e) {
          print('Error parsing carbon footprint: $e');
        }
      } else if (section.startsWith('STORAGE_TIPS]')) {
        storageTips = section
            .replaceAll('STORAGE_TIPS]', '')
            .trim()
            .split('\n')
            .where((tip) => tip.trim().startsWith('-'))
            .map((tip) => tip.trim().substring(1).trim())
            .where((tip) => tip.isNotEmpty)
            .take(3)
            .toList();
      } else if (section.startsWith('LOCAL]')) {
        isLocallyGrown = section
            .replaceAll('LOCAL]', '')
            .trim()
            .toLowerCase()
            .startsWith('true');
      }
    }

    // Ensure we have exactly 3 storage tips
    while (storageTips.length < 3) {
      storageTips.add('Store in a cool, dry place');
    }

    return FoodInformation(
      name: foodItem,
      carbonFootprint: carbonFootprint,
      storageTips: storageTips,
      isLocallyGrown: isLocallyGrown,
    );
  }
} 