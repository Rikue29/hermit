import 'package:google_generative_ai/google_generative_ai.dart';

class FoodCarbonData {
  final String impactLevel;
  final double carbonFootprint;
  final String impactDescription;
  final List<String> storageTips;
  final bool isLocallyGrown;
  final String gradeEmoji;

  FoodCarbonData({
    required this.impactLevel,
    required this.carbonFootprint,
    required this.impactDescription,
    required this.storageTips,
    required this.isLocallyGrown,
    required this.gradeEmoji,
  });
}

class FoodCarbonService {
  final GenerativeModel? _model;

  FoodCarbonService({String? apiKey})
      : _model = apiKey != null
            ? GenerativeModel(
                model: 'gemini-2.0-flash',
                apiKey: apiKey,
              )
            : null;

  Future<FoodCarbonData> getFoodCarbonData(String foodItem) async {
    if (_model == null) {
      throw Exception('API key not configured');
    }

    final prompt = '''
Analyze the carbon footprint and provide storage tips for $foodItem in the Malaysian context. 
Format the response exactly as follows:

[IMPACT_LEVEL]
A, B, or C grade (A being lowest impact, C being highest)

[CARBON_FOOTPRINT]
Numeric value in kg CO₂e per kg

[IMPACT_DESCRIPTION]
One sentence about the environmental impact, mentioning if it's locally grown in Malaysia

[STORAGE_TIPS]
- First storage tip
- Second storage tip
- Third storage tip

[IS_LOCAL]
true or false (based on if commonly grown in Malaysia)

[GRADE_EMOJI]
🟢 for A grade (low impact)
🟡 for B grade (medium impact)
🔴 for C grade (high impact)
''';

    try {
      final response = await _model!.generateContent([
        Content.text(prompt),
      ]);
      final text = response.text;

      if (text == null || text.isEmpty) {
        throw Exception('Empty response from API');
      }

      // Parse the response
      final sections = text.split('\n\n');
      final Map<String, String> data = {};
      
      for (final section in sections) {
        if (section.trim().isEmpty) continue;
        final parts = section.split('\n');
        if (parts.length >= 2) {
          final key = parts[0].replaceAll('[', '').replaceAll(']', '');
          final value = parts.sublist(1).join('\n').trim();
          data[key] = value;
        }
      }

      // Extract storage tips
      final storageTipsRaw = data['STORAGE_TIPS'] ?? '';
      final storageTips = storageTipsRaw
          .split('\n')
          .map((tip) => tip.trim().replaceAll('- ', ''))
          .where((tip) => tip.isNotEmpty)
          .toList();

      return FoodCarbonData(
        impactLevel: data['IMPACT_LEVEL'] ?? 'B',
        carbonFootprint: double.tryParse(data['CARBON_FOOTPRINT']?.split(' ')[0] ?? '0.5') ?? 0.5,
        impactDescription: data['IMPACT_DESCRIPTION'] ?? 'No impact description available.',
        storageTips: storageTips.isEmpty ? ['Store in a cool, dry place'] : storageTips,
        isLocallyGrown: data['IS_LOCAL']?.toLowerCase() == 'true',
        gradeEmoji: data['GRADE_EMOJI'] ?? '🟡',
      );
    } catch (e) {
      throw Exception('Failed to get carbon data: $e');
    }
  }
} 