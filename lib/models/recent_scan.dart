class RecentScan {
  final String? id;
  final String foodItem;
  final DateTime timestamp;
  final String? imagePath;

  RecentScan(
      {this.id,
      required this.foodItem,
      required this.timestamp,
      this.imagePath});

  Map<String, dynamic> toJson() => {
        'foodItem': foodItem,
        'timestamp': timestamp.toIso8601String(),
        'imagePath': imagePath,
      };

  factory RecentScan.fromJson(Map<String, dynamic> json, {String? id}) {
    return RecentScan(
      id: id,
      foodItem: json['foodItem'],
      timestamp: DateTime.parse(json['timestamp']),
      imagePath: json['imagePath'],
    );
  }
}
