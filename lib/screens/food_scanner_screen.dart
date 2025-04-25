import 'dart:io'; // Required for File type
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// Correct the import path for food_detection.dart
import '../models/food_detection.dart';

/// A screen that allows users to pick an image (camera/gallery)
/// and uses the FoodDetector to identify items via Roboflow API.
class FoodScannerScreen extends StatefulWidget {
  const FoodScannerScreen({super.key});

  @override
  State<FoodScannerScreen> createState() => _FoodScannerScreenState();
}

class _FoodScannerScreenState extends State<FoodScannerScreen> {
  // Instance of the detector class (from food_detection.dart)
  final FoodDetector _detector = FoodDetector();
  // Instance of the image picker plugin
  final ImagePicker _picker = ImagePicker();

  // State variables
  List<DetectionResult> _detections = []; // Holds the results from the API
  XFile? _imageFile; // Holds the picked image file (path and other info)
  bool _isLoading = false; // Tracks if the API call is in progress
  String? _errorMessage; // Stores any error messages
  List<Map<String, dynamic>> _recentScans = []; // Holds recent scan results
  TextEditingController _detectionController =
      TextEditingController(); // Controller for editing detection text

  // Add initState to handle potential lost data on Android
  @override
  void initState() {
    super.initState();
    // Check for lost data when the screen initializes.
    // Do not handle orientation changes or other complex scenarios here,
    // just the basic lost data retrieval as recommended.
    // Run this in a microtask to avoid blocking initState directly if retrieveLostData does work.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Platform.isAndroid) {
        // Only necessary on Android
        _retrieveLostData();
      }
    });
  }

  /// Retrieves lost image data potentially caused by the OS killing the
  /// MainActivity while the image picker was active (Android).
  Future<void> _retrieveLostData() async {
    print("Checking for lost image data...");
    final LostDataResponse response = await _picker.retrieveLostData();
    if (response.isEmpty) {
      print("No lost data found.");
      return;
    }

    if (response.file != null) {
      print("Lost data found: \\${response.file!.path}");
      setState(() {
        _imageFile = response.file; // Restore the lost image file
        _isLoading = false; // Ensure loading is off
        _errorMessage = null; // Clear any previous error
        _detections = []; // Clear detections, user needs to re-scan
      });
      // Optionally, you could trigger detection automatically here:
      // _detectItems(_imageFile!); // Example: _detectItems would contain the core logic
    } else if (response.exception != null) {
      print("Error retrieving lost data: \\${response.exception!.code}");
      setState(() {
        _errorMessage =
            "Error recovering image: \\${response.exception!.message}";
        _isLoading = false;
      });
    } else {
      print(
        "Lost data response was not empty but contained no file or exception.",
      );
    }
  }

  /// Handles picking an image from the specified [source] (gallery or camera)
  /// and then triggers the food detection process.
  Future<void> _pickAndDetectImage(ImageSource source) async {
    // Prevent multiple concurrent operations
    if (_isLoading) return;

    try {
      // Clear previous state before picking
      setState(() {
        _imageFile = null;
        _detections = [];
        _errorMessage = null;
        // Keep _isLoading false until image is actually picked
      });

      // Pick an image using the image_picker plugin
      final XFile? image = await _picker.pickImage(source: source);

      // If the user picked an image (didn't cancel)
      if (image != null) {
        setState(() {
          _imageFile = image; // Store the selected image file
          _isLoading = true; // Show loading indicator
          _errorMessage = null; // Clear previous error
          _detections = []; // Clear previous results
        });

        // Call the food detection method from our FoodDetector class
        try {
          print("Calling detectFoodItems with path: \\${image.path}");
          final results = await _detector.detectFoodItems(image.path);

          // Update state with results or empty message
          setState(() {
            _detections = results;
            _isLoading = false; // Hide loading indicator
            if (results.isEmpty) {
              print("No items detected by the API.");
              // Set a message if no items were found, but no error occurred
              // _errorMessage = "No food items detected.";
            } else {
              // Set the detection text for editing
              _detectionController.text =
                  results.map((e) => e.className).join(', ');
            }
          });
        } catch (e) {
          // Handle errors specifically from the API call
          print("Error caught during detection: \\${e}");
          setState(() {
            _errorMessage = "Error detecting food: \\${e.toString()}";
            _isLoading = false; // Hide loading indicator
          });
        }
      } else {
        // User cancelled the image picker
        print("Image selection cancelled.");
        // Optionally reset state if needed, but often just doing nothing is fine
        // setState(() { _isLoading = false; });
      }
    } catch (e) {
      // Handle potential errors from the image picker itself (e.g., permissions)
      print("Error picking image: \\${e}");
      setState(() {
        _errorMessage = "Error selecting image: \\${e.toString()}";
        _isLoading = false; // Ensure loading is off if picker fails
      });
    }
  }

  /// Confirms the detection and adds it to recent scans
  void _confirmDetection() {
    setState(() {
      _recentScans.add({
        'title': _detectionController.text,
        'subtitle': 'Just now',
        'trailing': 'N/A',
        'imagePath': _imageFile?.path, // Store the image path
      });
      _imageFile = null; // Clear the current image
      _detections = []; // Clear detections
      _detectionController.clear(); // Clear the text field
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Food'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // Show info dialog or navigate to info screen
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                    onPressed: _isLoading
                        ? null
                        : () => _pickAndDetectImage(ImageSource.gallery),
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
            const SizedBox(height: 40),
            const Text(
              'Recent Scans',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            // Display recent scans
            ..._recentScans.map(
              (scan) => Card(
                child: ListTile(
                  leading: scan['imagePath'] != null
                      ? Image.file(
                          File(scan['imagePath']),
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        )
                      : const CircleAvatar(
                          backgroundColor: Colors.red,
                          child: Icon(Icons.food_bank, color: Colors.white),
                        ),
                  title: Text(scan['title'] ?? 'Unknown'),
                  subtitle: Text(scan['subtitle'] ?? ''),
                  trailing: Text(scan['trailing'] ?? ''),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
