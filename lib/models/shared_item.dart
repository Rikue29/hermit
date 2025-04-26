class SharedItem {
  final String id;
  final String title;
  final String category;
  final String description;
  final DateTime expiryDate;
  final String quantity;
  final List<String> dietaryInfo;
  final String address;
  final String notes;
  final DateTime sharedAt;
  final String status; // Pending, Matched, Reserved
  final int requestCount;
  final String iconData; // Store the icon reference for the category

  SharedItem({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.expiryDate,
    required this.quantity,
    required this.dietaryInfo,
    required this.address,
    required this.notes,
    required this.sharedAt,
    required this.status,
    required this.requestCount,
    required this.iconData,
  });

  // Convert to JSON for backend
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'description': description,
      'expiryDate': expiryDate.toIso8601String(),
      'quantity': quantity,
      'dietaryInfo': dietaryInfo,
      'address': address,
      'notes': notes,
      'sharedAt': sharedAt.toIso8601String(),
      'status': status,
      'requestCount': requestCount,
      'iconData': iconData,
    };
  }

  // Create from JSON from backend
  factory SharedItem.fromJson(Map<String, dynamic> json) {
    return SharedItem(
      id: json['id'],
      title: json['title'],
      category: json['category'],
      description: json['description'],
      expiryDate: DateTime.parse(json['expiryDate']),
      quantity: json['quantity'],
      dietaryInfo: List<String>.from(json['dietaryInfo']),
      address: json['address'],
      notes: json['notes'],
      sharedAt: DateTime.parse(json['sharedAt']),
      status: json['status'],
      requestCount: json['requestCount'],
      iconData: json['iconData'],
    );
  }
}
