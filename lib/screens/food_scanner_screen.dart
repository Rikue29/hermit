import 'dart:io'; // Required for File type
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// Correct the import path for food_detection.dart
import '../models/food_detection.dart';
import '../services/food_analysis_service.dart';
import '../services/food_carbon_service.dart';
import '../services/env_service.dart';
import '../services/waste_management_service.dart';
import '../services/recipe_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recent_scan.dart';

/// A screen that allows users to pick an image (camera/gallery)
/// and uses the FoodDetector to identify items via Roboflow API.
class FoodScannerScreen extends StatefulWidget {
  final Function(Recipe recipe)? onAddRecipeTask;
  final Function(WasteDisposalSuggestion suggestion)? onAddWasteSuggestionTask;

  const FoodScannerScreen({
    super.key,
    this.onAddRecipeTask,
    this.onAddWasteSuggestionTask,
  });

  @override
  State<FoodScannerScreen> createState() => _FoodScannerScreenState();
}

class _FoodScannerScreenState extends State<FoodScannerScreen> {
  // Instance of the detector class (from food_detection.dart)
  final FoodDetector _detector = FoodDetector();
  // Instance of the image picker plugin
  final ImagePicker _picker = ImagePicker();
  late FoodAnalysisService _foodAnalysisService;
  late FoodCarbonService _foodCarbonService;
  late SharedPreferences _prefs;

  // State variables
  List<RecentScan> _recentScans = []; // Holds recent scan results
  bool _isLoading = false; // Tracks if the API call is in progress
  String? _errorMessage; // Stores any error messages
  XFile? _imageFile; // Holds the picked image file (path and other info)
  List<DetectionResult> _detections = []; // Holds the results from the API
  TextEditingController _detectionController =
      TextEditingController(); // Controller for editing detection text
  late dynamic _selectedFoodInfo; // Declare _selectedFoodInfo
  final Set<String> _selectedItems = <String>{}; // Track selected food items

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      if (EnvService.geminiApiKey.isEmpty) {
        throw Exception('Gemini API key not found in environment variables');
      }
      _foodAnalysisService = FoodAnalysisService(
        apiKey: EnvService.geminiApiKey,
      );
      _foodCarbonService = FoodCarbonService(apiKey: EnvService.geminiApiKey);
      _prefs = await SharedPreferences.getInstance();
      await _loadRecentScans();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadRecentScans() async {
    final scansJson = _prefs.getStringList('recent_scans') ?? [];
    print('Loaded scans from SharedPreferences: ' + scansJson.toString());
    setState(() {
      _recentScans = scansJson
          .map(
            (json) => RecentScan.fromJson(
              jsonDecode(json) as Map<String, dynamic>,
            ),
          )
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  Future<void> _startScanning() async {
    if (_isLoading) return;

    try {
      setState(() {
        _imageFile = null;
        _detections = [];
        _errorMessage = null;
      });

      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        setState(() {
          _imageFile = image;
          _isLoading = true;
          _errorMessage = null;
          _detections = [];
        });

        try {
          print("Calling detectFoodItems with path: ${image.path}");
          final results = await _detector.detectFoodItems(image.path);

          setState(() {
            _detections = results;
            _isLoading = false;
            if (results.isEmpty) {
              print("No items detected by the API.");
            } else {
              _detectionController.text =
                  results.map((e) => e.className).join(', ');
            }
          });
        } catch (e) {
          print("Error caught during detection: ${e}");
          setState(() {
            _errorMessage = "Error detecting food: ${e.toString()}";
            _isLoading = false;
          });
        }
      } else {
        print("Image selection cancelled.");
      }
    } catch (e) {
      print("Error picking image: ${e}");
      setState(() {
        _errorMessage = "Error selecting image: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  Future<void> _showFoodDetails(String foodItem) async {
    setState(() => _isLoading = true);

    try {
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Food'),
        actions: [
          if (_selectedItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _selectedItems.clear();
                });
              },
              tooltip: 'Clear selection',
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // Show info dialog or navigate to info screen
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      if (_imageFile != null)
                        Image.file(
                          File(_imageFile!.path),
                          height: 200,
                          fit: BoxFit.cover,
                        )
                      else
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.green[100],
                          child: const Icon(
                            Icons.camera_alt,
                            size: 50,
                            color: Colors.green,
                          ),
                        ),
                      const SizedBox(height: 20),
                      const Text(
                        'Scan Your Food',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Take a photo of your food to get expiry estimates, carbon footprint, and recipe suggestions',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _startScanning,
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
                const SizedBox(height: 40),
                if (_imageFile != null) ...[
                  const SizedBox(height: 20),
                  if (_isLoading) const Center(child: CircularProgressIndicator()),
                  if (!_isLoading && _detections.isNotEmpty) ...[
                    TextField(
                      controller: _detectionController,
                      decoration: const InputDecoration(
                        labelText: 'Detected Item',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _confirmDetection,
                      child: const Text('Confirm'),
                    ),
                  ],
                ],
              ],
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.3,
            minChildSize: 0.15,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
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
                    // Drag handle with animation feedback
                    GestureDetector(
                      onVerticalDragUpdate: (details) {
                        // The drag is handled by DraggableScrollableSheet
                      },
                      child: Container(
                        width: 100,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
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
                    Expanded(
                      child: _recentScans.isEmpty
                          ? Center(
                              child: Text(
                                'No recent scans',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _recentScans.length,
                              itemBuilder: (context, index) {
                                final scan = _recentScans[index];
                                final isSelected = _selectedItems.contains(scan.foodItem);
                                
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.green.shade50 : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? Colors.green.shade200 : Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _showFoodDetails(scan.foodItem),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8),
                                                color: Colors.grey.shade200,
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: scan.imagePath != null
                                                    ? Image.file(
                                                        File(scan.imagePath!),
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context, error, stackTrace) {
                                                          return Icon(
                                                            Icons.image_not_supported,
                                                            color: Colors.grey[400],
                                                          );
                                                        },
                                                      )
                                                    : Icon(
                                                        Icons.image_not_supported,
                                                        color: Colors.grey[400],
                                                      ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    scan.foodItem,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Scanned on: ${scan.timestamp.year}-${scan.timestamp.month.toString().padLeft(2, '0')}-${scan.timestamp.day.toString().padLeft(2, '0')} ${scan.timestamp.hour.toString().padLeft(2, '0')}:${scan.timestamp.minute.toString().padLeft(2, '0')}:${scan.timestamp.second.toString().padLeft(2, '0')}.${scan.timestamp.millisecond.toString().padLeft(3, '0')}',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Checkbox(
                                              value: isSelected,
                                              onChanged: (bool? value) {
                                                setState(() {
                                                  if (value == true) {
                                                    // Remove any other scan of the same food item
                                                    _selectedItems.removeWhere((item) => 
                                                      item.toLowerCase() == scan.foodItem.toLowerCase()
                                                    );
                                                    _selectedItems.add(scan.foodItem);
                                                  } else {
                                                    _selectedItems.remove(scan.foodItem);
                                                  }
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    _buildActionButtons(),
                  ],
                ),
              );
            },
          ),
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

  Future<void> _confirmDetection() async {
    if (_imageFile != null) {
      final newScan = RecentScan(
        foodItem: _detectionController.text,
        timestamp: DateTime.now(),
        imagePath: _imageFile!.path,
      );

      setState(() {
        _recentScans.insert(0, newScan);

        // Save to SharedPreferences
        final scansJson =
            _recentScans.map((scan) => jsonEncode(scan.toJson())).toList();
        _prefs.setStringList('recent_scans', scansJson);

        _imageFile = null;
        _detections = [];
        _detectionController.clear();
      });
    }
  }

  Future<void> _showWasteManagementDialog(
    String foodItem,
    FoodCarbonData carbonData,
  ) async {
    final wasteService = WasteManagementService(
      apiKey: EnvService.geminiApiKey,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return FutureBuilder<List<WasteDisposalSuggestion>>(
            future: wasteService.getSustainableSuggestions(foodItem),
            builder: (context, snapshot) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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
                          color: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
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
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
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
                                  _showWasteManagementDialog(
                                    foodItem,
                                    carbonData,
                                  );
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
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: Colors.grey[600]),
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
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
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
                                        Icon(
                                          categoryIcon,
                                          size: 16,
                                          color: color,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            suggestion.category,
                                            style: TextStyle(
                                              color: color,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
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
                                          borderRadius:
                                              const BorderRadius.vertical(
                                            bottom: Radius.circular(12),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (suggestion.location !=
                                                null) ...[
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    8,
                                                  ),
                                                  border: Border.all(
                                                    color:
                                                        color.withOpacity(0.2),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.location_on,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(
                                                      width: 8,
                                                    ),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          const Text(
                                                            'Where to go:',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              fontSize: 12,
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          Text(
                                                            suggestion
                                                                .location!,
                                                            style:
                                                                const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: Colors
                                                                  .black87,
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
                                              padding: const EdgeInsets.all(
                                                12,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                  8,
                                                ),
                                                border: Border.all(
                                                  color: color.withOpacity(
                                                    0.2,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.home,
                                                    color: color,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Text(
                                                    'Common household items',
                                                  ),
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
                                            ...suggestion.steps
                                                .asMap()
                                                .entries
                                                .map((
                                              entry,
                                            ) {
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 12,
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      width: 24,
                                                      height: 24,
                                                      margin:
                                                          const EdgeInsets.only(
                                                        right: 8,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            color.withOpacity(
                                                          0.1,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                          12,
                                                        ),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          '${entry.key + 1}',
                                                          style: TextStyle(
                                                            color: color,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                        entry.value,
                                                        style: Theme.of(
                                                          context,
                                                        ).textTheme.bodyMedium,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      // Add to Tasks button
                                      Center(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            if (widget.onAddWasteSuggestionTask != null) {
                                              widget.onAddWasteSuggestionTask!(suggestion);
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Added "${suggestion.suggestion}" to tasks'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          },
                                          icon: const Icon(Icons.add_task),
                                          label: const Text('Add to Tasks'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF4A5F4A),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 10,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(30),
                                            ),
                                          ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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
                          color: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
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
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
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
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 16),
                              ...snapshot.data!.map((recipe) {
                                final Color difficultyColor = {
                                      'Easy': Colors.green,
                                      'Medium': Colors.orange,
                                      'Hard': Colors.red,
                                    }[recipe.difficulty] ??
                                    Colors.grey;

                                return Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            Expanded(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                ),
                                                child: _buildInfoChip(
                                                  Icons.timer,
                                                  recipe.prepTime,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                ),
                                                child: _buildInfoChip(
                                                  Icons.local_fire_department,
                                                  recipe.cookTime,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                ),
                                                child: _buildInfoChip(
                                                  Icons.people,
                                                  recipe.servings,
                                                ),
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
                                          borderRadius:
                                              const BorderRadius.vertical(
                                            bottom: Radius.circular(12),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Theme(
                                              data: Theme.of(
                                                context,
                                              ).copyWith(
                                                dividerColor:
                                                    Colors.transparent,
                                              ),
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
                                                    physics:
                                                        const NeverScrollableScrollPhysics(),
                                                    itemCount: recipe
                                                        .ingredients.length,
                                                    itemBuilder: (
                                                      context,
                                                      index,
                                                    ) {
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                          bottom: 4,
                                                        ),
                                                        child: Row(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            const Icon(
                                                              Icons
                                                                  .fiber_manual_record,
                                                              size: 8,
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                recipe.ingredients[
                                                                    index],
                                                                style:
                                                                    const TextStyle(
                                                                  height: 1.4,
                                                                ),
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
                                              data: Theme.of(
                                                context,
                                              ).copyWith(
                                                dividerColor:
                                                    Colors.transparent,
                                              ),
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
                                                    physics:
                                                        const NeverScrollableScrollPhysics(),
                                                    itemCount:
                                                        recipe.steps.length,
                                                    itemBuilder: (
                                                      context,
                                                      index,
                                                    ) {
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                          bottom: 12,
                                                        ),
                                                        child: Row(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Container(
                                                              width: 24,
                                                              height: 24,
                                                              margin:
                                                                  const EdgeInsets
                                                                      .only(
                                                                right: 8,
                                                              ),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Theme.of(
                                                                  context,
                                                                )
                                                                    .primaryColor
                                                                    .withOpacity(
                                                                      0.1,
                                                                    ),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                  12,
                                                                ),
                                                              ),
                                                              child: Center(
                                                                child: Text(
                                                                  '${index + 1}',
                                                                  style:
                                                                      TextStyle(
                                                                    color: Theme
                                                                        .of(
                                                                      context,
                                                                    ).primaryColor,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                recipe.steps[
                                                                    index],
                                                                style:
                                                                    const TextStyle(
                                                                  height: 1.4,
                                                                ),
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

  Future<void> _saveRecentScan(String foodItem) async {
    final newScan = RecentScan(
      foodItem: foodItem,
      timestamp: DateTime.now(),
      imagePath: _imageFile?.path,
    );

    _recentScans.insert(0, newScan);
    if (_recentScans.length > 20) {
      _recentScans.removeLast();
    }
    await _prefs.setStringList(
      'recent_scans',
      _recentScans.map((scan) => jsonEncode(scan.toJson())).toList(),
    );
    setState(() {});
  }

  Widget _buildFoodDetailsDialog(String foodItem, dynamic foodInfo) {
    // Find the corresponding scan for this food item to get the image
    final scan = _recentScans.firstWhere(
      (scan) => scan.foodItem == foodItem,
      orElse: () => RecentScan(
        foodItem: foodItem,
        timestamp: DateTime.now(),
      ),
    );

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
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.grey[200],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: scan.imagePath != null
                                      ? Image.file(
                                          File(scan.imagePath!),
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey[200],
                                              child: Icon(
                                                Icons.image_not_supported,
                                                color: Colors.grey[400],
                                                size: 40,
                                              ),
                                            );
                                          },
                                        )
                                      : Container(
                                          color: Colors.grey[200],
                                          child: Icon(
                                            Icons.image_not_supported,
                                            color: Colors.grey[400],
                                            size: 40,
                                          ),
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
                                    const SizedBox(height: 8),
                                    Text(
                                      'Scanned on: ${scan.timestamp.day}/${scan.timestamp.month}/${scan.timestamp.year} at ${scan.timestamp.hour}:${scan.timestamp.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        fontSize: 14,
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
                          ...carbonData.storageTips.map(
                            (tip) => Padding(
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
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showRecipeSuggestionsDialog(foodItem);
                          },
                          icon: const Icon(Icons.restaurant_menu, size: 20),
                          label: const Text('Suggest Recipes'),
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
                          icon: const Icon(Icons.eco, size: 20),
                          label: const Text(
                            'Waste\n\tManagement',
                            textAlign: TextAlign.center,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A5F4A),
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


  void _clearRecentScans() {
    setState(() {
      _recentScans.clear();
      _prefs.remove('recent_scans');
    });
  }

  Widget _buildActionButtons() {
    if (_selectedItems.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${_selectedItems.length} selected',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showBatchRecipeSuggestionsDialog(_selectedItems.toList());
                    },
                    icon: const Icon(Icons.restaurant_menu, size: 20),
                    label: const Text('Suggest\nRecipes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3E6B3D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showBatchWasteManagementDialog(_selectedItems.toList());
                    },
                    icon: const Icon(Icons.eco, size: 20),
                    label: const Text('Waste\nManagement'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A5F4A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBatchRecipeSuggestionsDialog(List<String> foodItems) async {
    final recipeService = RecipeService(apiKey: EnvService.geminiApiKey);

    showDialog(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return FutureBuilder<List<Recipe>>(
            future: recipeService.getRecipeSuggestionsForMultipleItems(foodItems),
            builder: (context, snapshot) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.restaurant_menu),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Recipe Suggestions (${foodItems.length} items)',
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
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
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
                                  _showBatchRecipeSuggestionsDialog(foodItems);
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
                                'Recipes using: ${foodItems.join(", ")}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 16),
                              ...snapshot.data!.map((recipe) {
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
                                      ],
                                    ),
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        width: double.infinity,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Ingredients',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            ...recipe.ingredients.map(
                                              (ingredient) => Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 4,
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.fiber_manual_record,
                                                      size: 8,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(ingredient),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            const Text(
                                              'Instructions',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            ...recipe.steps.asMap().entries.map(
                                              (entry) {
                                                return Padding(
                                                  padding: const EdgeInsets.only(
                                                    bottom: 12,
                                                  ),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Container(
                                                        width: 24,
                                                        height: 24,
                                                        margin:
                                                            const EdgeInsets.only(
                                                          right: 8,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: Theme.of(context)
                                                              .primaryColor
                                                              .withOpacity(0.1),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                            12,
                                                          ),
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            '${entry.key + 1}',
                                                            style: TextStyle(
                                                              color: Theme.of(
                                                                context,
                                                              ).primaryColor,
                                                              fontWeight:
                                                                  FontWeight.bold,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Text(
                                                          entry.value,
                                                          style: const TextStyle(
                                                            height: 1.4,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 16),
                                            // Add to Tasks button
                                            Center(
                                              child: ElevatedButton.icon(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                  if (widget.onAddRecipeTask != null) {
                                                    widget.onAddRecipeTask!(recipe);
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('Added "${recipe.name}" to tasks'),
                                                        backgroundColor: Colors.green,
                                                      ),
                                                    );
                                                  }
                                                },
                                                icon: const Icon(Icons.add_task),
                                                label: const Text('Add to Tasks'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF3E6B3D),
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 24,
                                                    vertical: 12,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(30),
                                                  ),
                                                ),
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

  Future<void> _showBatchWasteManagementDialog(List<String> foodItems) async {
    final wasteService = WasteManagementService(
      apiKey: EnvService.geminiApiKey,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return FutureBuilder<List<WasteDisposalSuggestion>>(
            future: wasteService.getSustainableSuggestionsForMultipleItems(foodItems),
            builder: (context, snapshot) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.eco),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Waste Management (${foodItems.length} items)',
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
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
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
                                  _showBatchWasteManagementDialog(foodItems);
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
                                'Suggestions for: ${foodItems.join(", ")}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: Colors.grey[600]),
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
                                        Icon(
                                          categoryIcon,
                                          size: 16,
                                          color: color,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            suggestion.category,
                                            style: TextStyle(
                                              color: color,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (suggestion.location != null) ...[
                                              Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: color.withOpacity(0.2),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.location_on,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          const Text(
                                                            'Where to go:',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight.w500,
                                                              fontSize: 12,
                                                              color: Colors.grey,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            suggestion.location!,
                                                            style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight.w500,
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
                                              'Steps to follow:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            ...suggestion.steps
                                                .asMap()
                                                .entries
                                                .map((entry) {
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 12,
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      width: 24,
                                                      height: 24,
                                                      margin:
                                                          const EdgeInsets.only(
                                                        right: 8,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: color.withOpacity(
                                                          0.1,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                          12,
                                                        ),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          '${entry.key + 1}',
                                                          style: TextStyle(
                                                            color: color,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                        entry.value,
                                                        style: const TextStyle(
                                                          height: 1.4,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      // Add to Tasks button
                                      Center(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            if (widget.onAddWasteSuggestionTask != null) {
                                              widget.onAddWasteSuggestionTask!(suggestion);
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Added "${suggestion.suggestion}" to tasks'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          },
                                          icon: const Icon(Icons.add_task),
                                          label: const Text('Add to Tasks'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF4A5F4A),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 10,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(30),
                                            ),
                                          ),
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
}
