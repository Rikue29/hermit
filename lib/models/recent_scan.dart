class RecentScan {
  final String foodItem;
  final DateTime timestamp;
  final String? imagePath;

  RecentScan({required this.foodItem, required this.timestamp, this.imagePath});

  Map<String, dynamic> toJson() => {
        'foodItem': foodItem,
        'timestamp': timestamp.toIso8601String(),
        'imagePath': imagePath,
      };

  factory RecentScan.fromJson(Map<String, dynamic> json) {
    return RecentScan(
      foodItem: json['foodItem'],
      timestamp: DateTime.parse(json['timestamp']),
      imagePath: json['imagePath'],
    );
  }
}
