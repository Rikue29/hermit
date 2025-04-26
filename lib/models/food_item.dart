class FoodItem {
  final String name;
  final double confidence;
  final int daysRemaining;
  final double carbonFootprint;
  final bool isLocal;

  FoodItem({
    required this.name,
    required this.confidence,
    required this.daysRemaining,
    required this.carbonFootprint,
    this.isLocal = false,
  });
} 