class Request {
  final String id;
  final String itemId;
  final String requesterId;
  final String requesterName;
  final String message;
  final DateTime requestedAt;
  final String status; // Pending, Accepted, Rejected
  final String? pickupTime;

  Request({
    required this.id,
    required this.itemId,
    required this.requesterId,
    required this.requesterName,
    required this.message,
    required this.requestedAt,
    required this.status,
    this.pickupTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'itemId': itemId,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'message': message,
      'requestedAt': requestedAt.toIso8601String(),
      'status': status,
      'pickupTime': pickupTime,
    };
  }

  factory Request.fromJson(Map<String, dynamic> json) {
    return Request(
      id: json['id'],
      itemId: json['itemId'],
      requesterId: json['requesterId'],
      requesterName: json['requesterName'],
      message: json['message'],
      requestedAt: DateTime.parse(json['requestedAt']),
      status: json['status'],
      pickupTime: json['pickupTime'],
    );
  }
}
