import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/food_analysis_service.dart';
import '../services/food_carbon_service.dart';
import '../services/env_service.dart';
import '../models/food_item.dart';
import '../services/waste_management_service.dart';
import '../services/recipe_service.dart';

class RecentScan {
  final String foodItem;
  final DateTime timestamp;

  RecentScan({required this.foodItem, required this.timestamp});

  Map<String, dynamic> toJson() => {
    'foodItem': foodItem,
    'timestamp': timestamp.toIso8601String(),
  };

  factory RecentScan.fromJson(Map<String, dynamic> json) => RecentScan(
    foodItem: json['foodItem'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

class FoodAnalysisResult {
  final String name;
  final double confidence;
  final double carbonFootprint;
  final List<String> storageTips;
  final bool isLocallyGrown;

  FoodAnalysisResult({
    required this.name,
    required this.confidence,
    required this.carbonFootprint,
    required this.storageTips,
    required this.isLocallyGrown,
  });
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  final DraggableScrollableController _controller = DraggableScrollableController();
  late FoodAnalysisService _foodAnalysisService;
  late FoodCarbonService _foodCarbonService;
  late AnimationController _animationController;
  late SharedPreferences _prefs;
  
  FoodInformation? _selectedFoodInfo;
  List<RecentScan> _recentScans = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _initError;
  Map<String, bool> _sectionLoading = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      if (EnvService.geminiApiKey.isEmpty) {
        throw Exception('Gemini API key not found in environment variables');
      }
      _foodAnalysisService = FoodAnalysisService(apiKey: EnvService.geminiApiKey);
      _foodCarbonService = FoodCarbonService(apiKey: EnvService.geminiApiKey);
      _prefs = await SharedPreferences.getInstance();
      
      // Check if this is the first run
      final isFirstRun = _prefs.getBool('is_first_run') ?? true;
      if (isFirstRun) {
        // Add dummy data for testing
        final dummyScans = [
          RecentScan(
            foodItem: 'Apples',
            timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
          ),
          RecentScan(
            foodItem: 'Oranges',
            timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          ),
          RecentScan(
            foodItem: 'Bananas',
            timestamp: DateTime.now().subtract(const Duration(hours: 5)),
          ),
          RecentScan(
            foodItem: 'Grapes',
            timestamp: DateTime.now().subtract(const Duration(days: 1)),
          ),
          RecentScan(
            foodItem: 'Pears',
            timestamp: DateTime.now().subtract(const Duration(days: 2)),
          ),
        ];

        await _prefs.setStringList(
          'recent_scans',
          dummyScans.map((scan) => jsonEncode(scan.toJson())).toList(),
        );
        await _prefs.setBool('is_first_run', false);
      }

      await _loadRecentScans();
      setState(() => _isInitialized = true);
    } catch (e) {
      setState(() {
        _initError = e.toString();
        _isInitialized = true;
      });
    }
  }

  Future<void> _loadRecentScans() async {
    final scansJson = _prefs.getStringList('recent_scans') ?? [];
    setState(() {
      _recentScans = scansJson
          .map((json) => RecentScan.fromJson(jsonDecode(json)))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  Future<void> _saveRecentScan(String foodItem) async {
    final scan = RecentScan(foodItem: foodItem, timestamp: DateTime.now());
    _recentScans.insert(0, scan);
    if (_recentScans.length > 20) {
      _recentScans.removeLast();
    }
    await _prefs.setStringList(
      'recent_scans',
      _recentScans.map((scan) => jsonEncode(scan.toJson())).toList(),
    );
    setState(() {});
  }

  Future<void> _clearRecentScans() async {
    await _prefs.remove('recent_scans');
    setState(() => _recentScans.clear());
  }

  Future<void> _showFoodDetails(String foodItem) async {
    setState(() => _isLoading = true);
    
    try {
      await _saveRecentScan(foodItem);
      
      setState(() {
        _sectionLoading = {
          'storage': true,
          'nutrition': true,
          'environmental': true,
        };
      });

      final foodInfo = await _foodAnalysisService.getFoodInformation(foodItem);
      setState(() => _selectedFoodInfo = foodInfo);
      
      await showDialog(
        context: context,
        builder: (context) => _buildFoodDetailsDialog(foodItem, foodInfo),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _showFoodDetails(foodItem),
          ),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _sectionLoading.clear();
      });
    }
  }

  Future<void> _refreshFoodDetails(String foodItem) async {
    Navigator.pop(context);
    _showFoodDetails(foodItem);
  }

  Widget _buildFoodDetailsDialog(String foodItem, FoodInformation info) {
    return FutureBuilder<FoodCarbonData>(
      future: _foodCarbonService.getFoodCarbonData(foodItem),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Dialog(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analyzing food impact...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Dialog(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          );
        }

        final carbonData = snapshot.data!;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: 600,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Food Analysis',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.pink.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    _getFoodEmoji(foodItem),
                                    style: const TextStyle(fontSize: 40),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      foodItem,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Environmental Grade: ${carbonData.impactLevel}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Carbon Footprint
                          const Text(
                            'Carbon Footprint',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    carbonData.gradeEmoji,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${carbonData.impactLevel} Grade Impact',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${carbonData.carbonFootprint} kg CO₂e per kg',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            carbonData.impactDescription,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Storage Tips
                          const Text(
                            'Storage Tips',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...carbonData.storageTips.map((tip) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    tip,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showRecipeSuggestionsDialog(foodItem);
                          },
                          icon: const Icon(
                            Icons.restaurant_menu,
                            size: 20,
                          ),
                          label: const Text(
                            'Suggest Recipes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3E6B3D),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showWasteManagementDialog(foodItem, carbonData);
                          },
                          icon: const Icon(
                            Icons.eco,
                            size: 20,
                          ),
                          label: const Text(
                            'Waste\nManagement',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A5F4A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentScansSheet() {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        // You can add custom behavior based on sheet position here
        return true;
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.15,
        minChildSize: 0.15,
        maxChildSize: 0.7,
        controller: _controller,
        snap: true,
        snapSizes: const [0.15, 0.7],
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              GestureDetector(
                onTap: () {
                  if (_controller.isAttached) {
                    final currentSize = _controller.size;
                    if (currentSize < 0.7) {
                      _controller.animateTo(
                        0.7,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _controller.animateTo(
                        0.15,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  }
                },
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'Recent Scans (${_recentScans.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (_recentScans.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Clear History'),
                              content: const Text(
                                'Are you sure you want to clear all recent scans?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _clearRecentScans();
                                  },
                                  child: const Text(
                                    'Clear',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Text('Clear All'),
                      ),
                  ],
                ),
              ),
              if (_recentScans.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      'No recent scans',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _recentScans.length,
                    itemBuilder: (context, index) {
                      final scan = _recentScans[index];
                      return GestureDetector(
                        onTap: () => _showFoodDetails(scan.foodItem),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    _getFoodEmoji(scan.foodItem),
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${scan.foodItem} (${_getQuantity(scan.foodItem)})',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getTimeAgo(scan.timestamp),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_initError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Initialization Error',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _initError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade700),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _initializeServices,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 60),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.camera_alt_outlined,
                        size: 48,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Scan Food Items',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Point your camera at food items to get storage tips and sustainability suggestions',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Implement camera scanning
                        _showFoodDetails('Apple');
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Start Scanning',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _buildRecentScansSheet(),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  String _getFoodEmoji(String foodItem) {
    final Map<String, String> foodEmojis = {
      'Apples': '🍎',
      'Oranges': '🍊',
      'Bananas': '🍌',
      'Grapes': '🍇',
      'Pears': '🍐',
      // Add more mappings as needed
    };
    return foodEmojis[foodItem] ?? '🥗';
  }

  String _getQuantity(String foodItem) {
    // This is a placeholder. In a real app, you would get this from your data
    return '4';
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _showWasteManagementDialog(String foodItem, FoodCarbonData carbonData) async {
    final wasteService = WasteManagementService(apiKey: EnvService.geminiApiKey);
    
    showDialog(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return FutureBuilder<List<WasteDisposalSuggestion>>(
            future: wasteService.getSustainableSuggestions(foodItem),
            builder: (context, snapshot) {
              return Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                    maxWidth: 600,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.eco),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Sustainable Disposal Options',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Finding sustainable options...'),
                            ],
                          ),
                        )
                      else if (snapshot.hasError)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                'Error: ${snapshot.error}',
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _showWasteManagementDialog(foodItem, carbonData);
                                },
                                child: const Text('Try Again'),
                              ),
                            ],
                          ),
                        )
                      else if (!snapshot.hasData || snapshot.data!.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No suggestions available'),
                        )
                      else
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              Text(
                                'For: $foodItem',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                              const SizedBox(height: 16),
                              ...snapshot.data!.map((suggestion) {
                                Color color;
                                String timeEstimate;
                                IconData categoryIcon;

                                switch (suggestion.category.toLowerCase()) {
                                  case 'reuse':
                                    color = Colors.green;
                                    timeEstimate = '5-15 mins';
                                    categoryIcon = Icons.home_repair_service;
                                    break;
                                  case 'compost':
                                    color = Colors.brown;
                                    timeEstimate = '10-20 mins';
                                    categoryIcon = Icons.yard;
                                    break;
                                  case 'dispose':
                                    color = Colors.red;
                                    timeEstimate = '5-10 mins';
                                    categoryIcon = Icons.delete_outline;
                                    break;
                                  default:
                                    color = Colors.grey;
                                    timeEstimate = 'varies';
                                    categoryIcon = Icons.info_outline;
                                }

                                return Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: color.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: ExpansionTile(
                                    leading: Text(
                                      suggestion.emoji,
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                    title: Text(
                                      suggestion.suggestion,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Row(
                                      children: [
                                        Icon(categoryIcon, size: 16, color: color),
                                        const SizedBox(width: 4),
                                        Text(
                                          suggestion.category,
                                          style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(Icons.timer_outlined, size: 16, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text(
                                          timeEstimate,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.05),
                                          borderRadius: const BorderRadius.vertical(
                                            bottom: Radius.circular(12),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (suggestion.location != null) ...[
                                              Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: color.withOpacity(0.2)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.location_on, size: 20),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          const Text(
                                                            'Where to go:',
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.w500,
                                                              fontSize: 12,
                                                              color: Colors.grey,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            suggestion.location!,
                                                            style: const TextStyle(
                                                              fontWeight: FontWeight.w500,
                                                              color: Colors.black87,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                            ],
                                            const Text(
                                              'What you\'ll need:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: color.withOpacity(0.2)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.home, color: color),
                                                  const SizedBox(width: 8),
                                                  const Text('Common household items'),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            const Text(
                                              'Steps to follow:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            ...suggestion.steps.asMap().entries.map((entry) {
                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 12),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      width: 24,
                                                      height: 24,
                                                      margin: const EdgeInsets.only(right: 8),
                                                      decoration: BoxDecoration(
                                                        color: color.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          '${entry.key + 1}',
                                                          style: TextStyle(
                                                            color: color,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                        entry.value,
                                                        style: Theme.of(context).textTheme.bodyMedium,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showRecipeSuggestionsDialog(String foodItem) async {
    final recipeService = RecipeService(apiKey: EnvService.geminiApiKey);
    
    showDialog(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return FutureBuilder<List<Recipe>>(
            future: recipeService.getRecipeSuggestions(foodItem),
            builder: (context, snapshot) {
              return Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                    maxWidth: 600,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.restaurant_menu),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Recipe Suggestions',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Generating recipe suggestions...'),
                            ],
                          ),
                        )
                      else if (snapshot.hasError)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                'Error: ${snapshot.error}',
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _showRecipeSuggestionsDialog(foodItem);
                                },
                                child: const Text('Try Again'),
                              ),
                            ],
                          ),
                        )
                      else if (!snapshot.hasData || snapshot.data!.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No recipes available'),
                        )
                      else
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              Text(
                                'Recipes for: $foodItem',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                              const SizedBox(height: 16),
                              ...snapshot.data!.map((recipe) {
                                final Color difficultyColor = {
                                  'Easy': Colors.green,
                                  'Medium': Colors.orange,
                                  'Hard': Colors.red,
                                }[recipe.difficulty] ?? Colors.grey;

                                return Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ExpansionTile(
                                    leading: Text(
                                      recipe.imageEmoji,
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                    title: Text(
                                      recipe.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          recipe.description,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: [
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                                child: _buildInfoChip(Icons.timer, recipe.prepTime),
                                              ),
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                                child: _buildInfoChip(Icons.local_fire_department, recipe.cookTime),
                                              ),
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                                child: _buildInfoChip(Icons.people, recipe.servings),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[50],
                                          borderRadius: const BorderRadius.vertical(
                                            bottom: Radius.circular(12),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Theme(
                                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                              child: ExpansionTile(
                                                tilePadding: EdgeInsets.zero,
                                                title: const Text(
                                                  'Ingredients',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                initiallyExpanded: false,
                                                children: [
                                                  ListView.builder(
                                                    shrinkWrap: true,
                                                    physics: const NeverScrollableScrollPhysics(),
                                                    itemCount: recipe.ingredients.length,
                                                    itemBuilder: (context, index) {
                                                      return Padding(
                                                        padding: const EdgeInsets.only(bottom: 4),
                                                        child: Row(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            const Icon(Icons.fiber_manual_record, size: 8),
                                                            const SizedBox(width: 8),
                                                            Expanded(
                                                              child: Text(
                                                                recipe.ingredients[index],
                                                                style: const TextStyle(height: 1.4),
                                                                softWrap: true,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Theme(
                                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                              child: ExpansionTile(
                                                tilePadding: EdgeInsets.zero,
                                                title: const Text(
                                                  'Instructions',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                initiallyExpanded: false,
                                                children: [
                                                  ListView.builder(
                                                    shrinkWrap: true,
                                                    physics: const NeverScrollableScrollPhysics(),
                                                    itemCount: recipe.steps.length,
                                                    itemBuilder: (context, index) {
                                                      return Padding(
                                                        padding: const EdgeInsets.only(bottom: 12),
                                                        child: Row(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Container(
                                                              width: 24,
                                                              height: 24,
                                                              margin: const EdgeInsets.only(right: 8),
                                                              decoration: BoxDecoration(
                                                                color: Theme.of(context).primaryColor.withOpacity(0.1),
                                                                borderRadius: BorderRadius.circular(12),
                                                              ),
                                                              child: Center(
                                                                child: Text(
                                                                  '${index + 1}',
                                                                  style: TextStyle(
                                                                    color: Theme.of(context).primaryColor,
                                                                    fontWeight: FontWeight.bold,
                                                                    fontSize: 12,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                recipe.steps[index],
                                                                style: const TextStyle(height: 1.4),
                                                                softWrap: true,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
} 