import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/shared_item.dart';
import '../models/request.dart';

class SharedItemsService {
  // In-memory storage for actual data
  static final List<SharedItem> _items = [
    // My shared items with requests
    SharedItem(
      id: '1',
      title: 'Canned Goods',
      category: 'Pantry Items',
      description: 'Soup, Beans, Corn',
      expiryDate: DateTime.now().add(const Duration(days: 59)),
      quantity: '5 cans',
      dietaryInfo: ['Non-perishable'],
      address: '456 Oak St',
      notes: 'Moving out sale',
      sharedAt: DateTime.now().subtract(const Duration(days: 1)),
      status: 'Matched',
      requestCount: 3,
      iconData: 'kitchen',
      photoUrl:
          'https://images.unsplash.com/photo-1615589484252-c70def71bb4f?q=80&w=686&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
    ),
    SharedItem(
      id: '2',
      title: 'Fresh Vegetables',
      category: 'Fresh Produce',
      description: 'Fresh from my garden: tomatoes, lettuce, carrots',
      expiryDate: DateTime.now().add(const Duration(days: 3)),
      quantity: '2 kg',
      dietaryInfo: ['Organic', 'Fresh'],
      address: '123 Pine St',
      notes: 'Freshly picked',
      sharedAt: DateTime.now().subtract(const Duration(hours: 5)),
      status: 'Pending',
      requestCount: 2,
      iconData: 'eco',
      photoUrl:
          'https://plus.unsplash.com/premium_photo-1675798983878-604c09f6d154?w=1000&auto=format&fit=crop&q=60&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MXx8dmVnZXRhYmxlc3xlbnwwfHwwfHx8MA%3D%3D',
    ),
    // Completed/Past shared items
    SharedItem(
      id: '3',
      title: 'Bread and Pastries',
      category: 'Bakery',
      description: 'Assorted breads and pastries from local bakery',
      expiryDate: DateTime.now().add(const Duration(days: 1)),
      quantity: '8 pieces',
      dietaryInfo: ['Contains Gluten'],
      address: '789 Maple St',
      notes: 'Baked fresh this morning',
      sharedAt: DateTime.now().subtract(const Duration(days: 3)),
      status: 'Completed',
      requestCount: 1,
      iconData: 'bakery_dining',
      photoUrl:
          'https://plus.unsplash.com/premium_photo-1673111979369-0222c7314b82?w=1000&auto=format&fit=crop&q=60&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8NXx8YnJlYWR8ZW58MHx8MHx8fDA%3D',
    ),
  ];

  static final Map<String, List<Request>> _requests = {
    // Requests for Canned Goods
    '1': [
      Request(
        id: 'r1',
        itemId: '1',
        requesterId: 'user1',
        requesterName: 'Sarah Johnson',
        message:
            'I run a local food bank and these would be perfect for our community!',
        requestedAt: DateTime.now().subtract(const Duration(hours: 22)),
        status: 'Accepted',
        pickupTime: '14:00',
      ),
      Request(
        id: 'r2',
        itemId: '1',
        requesterId: 'user2',
        requesterName: 'Mike Wilson',
        message: 'Could really use these for my family.',
        requestedAt: DateTime.now().subtract(const Duration(hours: 20)),
        status: 'Pending',
      ),
      Request(
        id: 'r3',
        itemId: '1',
        requesterId: 'user3',
        requesterName: 'Emily Brown',
        message: 'I can pick up anytime today!',
        requestedAt: DateTime.now().subtract(const Duration(hours: 18)),
        status: 'Pending',
      ),
    ],
    // Requests for Fresh Vegetables
    '2': [
      Request(
        id: 'r4',
        itemId: '2',
        requesterId: 'user4',
        requesterName: 'David Lee',
        message: 'Would love to make a fresh salad with these vegetables!',
        requestedAt: DateTime.now().subtract(const Duration(hours: 3)),
        status: 'Pending',
      ),
      Request(
        id: 'r5',
        itemId: '2',
        requesterId: 'user5',
        requesterName: 'Lisa Chen',
        message: 'I can pick up in the next hour if available.',
        requestedAt: DateTime.now().subtract(const Duration(hours: 2)),
        status: 'Pending',
      ),
    ],
    // Completed request for Bread
    '3': [
      Request(
        id: 'r6',
        itemId: '3',
        requesterId: 'user6',
        requesterName: 'Tom Harris',
        message: 'Perfect for our community breakfast tomorrow!',
        requestedAt: DateTime.now().subtract(const Duration(days: 3)),
        status: 'Completed',
        pickupTime: '09:00',
      ),
    ],
  };

  static final List<SharedItem> _requestedItems = [
    // Items I've requested
    SharedItem(
      id: '4',
      title: 'Homemade Cookies',
      category: 'Bakery',
      description: 'Chocolate chip and oatmeal raisin cookies',
      expiryDate: DateTime.now().add(const Duration(days: 5)),
      quantity: '24 pieces',
      dietaryInfo: ['Contains Nuts', 'Sweet'],
      address: '321 Elm St',
      notes: 'Freshly baked today',
      sharedAt: DateTime.now().subtract(const Duration(hours: 8)),
      status: 'Pending',
      requestCount: 2,
      iconData: 'bakery_dining',
      photoUrl:
          'https://images.unsplash.com/photo-1629750413458-90c737a1c57b?q=80&w=1974&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
    ),
    // Completed requests
    SharedItem(
      id: '5',
      title: 'Rice and Pasta',
      category: 'Pantry Items',
      description: 'Unopened packages of rice and various pasta',
      expiryDate: DateTime.now().add(const Duration(days: 90)),
      quantity: '4 packs',
      dietaryInfo: ['Non-perishable'],
      address: '567 Oak St',
      notes: 'Moving out next week',
      sharedAt: DateTime.now().subtract(const Duration(days: 2)),
      status: 'Completed',
      requestCount: 1,
      iconData: 'kitchen',
      photoUrl:
          'https://images.unsplash.com/photo-1692731754157-d73327dd6cdc?q=80&w=2070&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
    ),
  ];

  // Simulate network delay
  Future<void> _simulateNetworkDelay() async {
    await Future.delayed(Duration(milliseconds: 500 + Random().nextInt(500)));
  }

  // Get all my items (both shared and requested)
  Future<Map<String, List<SharedItem>>> getMyItems() async {
    await _simulateNetworkDelay();

    // Separate items into active and past
    List<SharedItem> activeShared = _items
        .where((item) => item.status == 'Pending' || item.status == 'Matched')
        .toList();

    List<SharedItem> pastShared = _items
        .where(
            (item) => item.status == 'Completed' || item.status == 'Cancelled')
        .toList();

    List<SharedItem> activeRequested =
        _requestedItems.where((item) => item.status == 'Pending').toList();

    List<SharedItem> pastRequested = _requestedItems
        .where(
            (item) => item.status == 'Completed' || item.status == 'Rejected')
        .toList();

    return {
      'activeShared': activeShared,
      'pastShared': pastShared,
      'activeRequested': activeRequested,
      'pastRequested': pastRequested,
    };
  }

  // Share a new item
  Future<SharedItem> shareItem(Map<String, dynamic> itemData) async {
    await _simulateNetworkDelay();

    final newItem = SharedItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: itemData['title'],
      category: itemData['category'],
      description: itemData['description'] ?? '',
      expiryDate:
          itemData['expiryDate'] ?? DateTime.now().add(const Duration(days: 1)),
      quantity: itemData['quantity'],
      dietaryInfo: List<String>.from(itemData['dietaryInfo'] ?? []),
      address: itemData['address'],
      notes: itemData['notes'] ?? '',
      sharedAt: DateTime.now(),
      status: 'Pending', // Always starts as Pending
      requestCount: 0,
      iconData: _getIconForCategory(itemData['category']),
    );

    _items.insert(0, newItem);
    return newItem;
  }

  // Request an item
  Future<void> requestItem(String itemId, String message) async {
    await _simulateNetworkDelay();

    final item = _items.firstWhere((item) => item.id == itemId);
    final request = Request(
      id: 'r${DateTime.now().millisecondsSinceEpoch}',
      itemId: itemId,
      requesterId: 'currentUser',
      requesterName: 'Current User',
      message: message,
      requestedAt: DateTime.now(),
      status: 'Pending',
    );

    if (!_requests.containsKey(itemId)) {
      _requests[itemId] = [];
    }
    _requests[itemId]!.add(request);

    // Update request count and change status to Matched
    final itemIndex = _items.indexWhere((i) => i.id == itemId);
    if (itemIndex != -1) {
      final updatedItem = SharedItem(
        id: item.id,
        title: item.title,
        category: item.category,
        description: item.description,
        expiryDate: item.expiryDate,
        quantity: item.quantity,
        dietaryInfo: item.dietaryInfo,
        address: item.address,
        notes: item.notes,
        sharedAt: item.sharedAt,
        status: 'Matched', // Change to Matched when there are requests
        requestCount: (_requests[itemId] ?? []).length,
        iconData: item.iconData,
      );
      _items[itemIndex] = updatedItem;
    }

    // Add to my requested items
    _requestedItems.insert(0, item);
  }

  // Get requests for a specific item
  Future<List<Request>> getItemRequests(String itemId) async {
    await _simulateNetworkDelay();
    return _requests[itemId] ?? [];
  }

  // Handle a request (accept/reject)
  Future<Request> handleRequest(String requestId, String action,
      {String? pickupTime}) async {
    await _simulateNetworkDelay();

    // Find and update the request
    for (var requests in _requests.values) {
      for (var request in requests) {
        if (request.id == requestId) {
          final updatedRequest = Request(
            id: request.id,
            itemId: request.itemId,
            requesterId: request.requesterId,
            requesterName: request.requesterName,
            message: request.message,
            requestedAt: request.requestedAt,
            status: action == 'accept' ? 'Accepted' : 'Rejected',
            pickupTime: pickupTime,
          );

          // Update the item status if request is accepted
          if (action == 'accept') {
            final itemIndex =
                _items.indexWhere((item) => item.id == request.itemId);
            if (itemIndex != -1) {
              final item = _items[itemIndex];
              _items[itemIndex] = SharedItem(
                id: item.id,
                title: item.title,
                category: item.category,
                description: item.description,
                expiryDate: item.expiryDate,
                quantity: item.quantity,
                dietaryInfo: item.dietaryInfo,
                address: item.address,
                notes: item.notes,
                sharedAt: item.sharedAt,
                status: 'Completed', // Move to Completed when request accepted
                requestCount: item.requestCount,
                iconData: item.iconData,
              );

              // Reject all other pending requests for this item
              if (_requests.containsKey(item.id)) {
                final otherRequests = _requests[item.id]!;
                for (var i = 0; i < otherRequests.length; i++) {
                  if (otherRequests[i].id != requestId &&
                      otherRequests[i].status == 'Pending') {
                    otherRequests[i] = Request(
                      id: otherRequests[i].id,
                      itemId: otherRequests[i].itemId,
                      requesterId: otherRequests[i].requesterId,
                      requesterName: otherRequests[i].requesterName,
                      message: otherRequests[i].message,
                      requestedAt: otherRequests[i].requestedAt,
                      status: 'Rejected',
                    );
                  }
                }
              }
            }

            // Update in requested items if it exists there
            final requestedIndex =
                _requestedItems.indexWhere((item) => item.id == request.itemId);
            if (requestedIndex != -1) {
              final item = _requestedItems[requestedIndex];
              _requestedItems[requestedIndex] = SharedItem(
                id: item.id,
                title: item.title,
                category: item.category,
                description: item.description,
                expiryDate: item.expiryDate,
                quantity: item.quantity,
                dietaryInfo: item.dietaryInfo,
                address: item.address,
                notes: item.notes,
                sharedAt: item.sharedAt,
                status: 'Completed',
                requestCount: item.requestCount,
                iconData: item.iconData,
              );
            }
          }

          // Update the request in the list
          final index = requests.indexOf(request);
          requests[index] = updatedRequest;
          return updatedRequest;
        }
      }
    }
    throw Exception('Request not found');
  }

  // Cancel a shared item
  Future<void> cancelSharedItem(String itemId) async {
    await _simulateNetworkDelay();

    final index = _items.indexWhere((item) => item.id == itemId);
    if (index != -1) {
      final item = _items[index];
      _items[index] = SharedItem(
        id: item.id,
        title: item.title,
        category: item.category,
        description: item.description,
        expiryDate: item.expiryDate,
        quantity: item.quantity,
        dietaryInfo: item.dietaryInfo,
        address: item.address,
        notes: item.notes,
        sharedAt: item.sharedAt,
        status: 'Cancelled',
        requestCount: item.requestCount,
        iconData: item.iconData,
      );

      // Reject all pending requests for this item
      if (_requests.containsKey(itemId)) {
        final requests = _requests[itemId]!;
        for (var i = 0; i < requests.length; i++) {
          if (requests[i].status == 'Pending') {
            requests[i] = Request(
              id: requests[i].id,
              itemId: requests[i].itemId,
              requesterId: requests[i].requesterId,
              requesterName: requests[i].requesterName,
              message: requests[i].message,
              requestedAt: requests[i].requestedAt,
              status: 'Rejected',
            );
          }
        }
      }
    }
  }

  // Update a shared item
  Future<SharedItem> updateSharedItem(
      String itemId, Map<String, dynamic> updates) async {
    await _simulateNetworkDelay();

    final index = _items.indexWhere((item) => item.id == itemId);
    if (index != -1) {
      final item = _items[index];
      final updatedItem = SharedItem(
        id: item.id,
        title: updates['title'] ?? item.title,
        category: updates['category'] ?? item.category,
        description: updates['description'] ?? item.description,
        expiryDate: updates['expiryDate'] ?? item.expiryDate,
        quantity: updates['quantity'] ?? item.quantity,
        dietaryInfo: updates['dietaryInfo'] ?? item.dietaryInfo,
        address: updates['address'] ?? item.address,
        notes: updates['notes'] ?? item.notes,
        sharedAt: item.sharedAt,
        status: updates['status'] ?? item.status,
        requestCount: item.requestCount,
        iconData: _getIconForCategory(updates['category'] ?? item.category),
      );
      _items[index] = updatedItem;
      return updatedItem;
    }
    throw Exception('Item not found');
  }

  String _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'fresh produce':
        return 'eco';
      case 'bakery':
        return 'bakery_dining';
      case 'pantry items':
        return 'kitchen';
      case 'dairy':
        return 'egg';
      case 'meat':
        return 'restaurant';
      default:
        return 'inventory_2';
    }
  }
}
