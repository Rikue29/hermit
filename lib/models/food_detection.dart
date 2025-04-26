import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

/// Represents a single detected object from the Roboflow API.
class DetectionResult {
  final String className;
  final double confidence;
  // You can add bounding box coordinates (x, y, width, height) if needed
  // final double x;
  // final double y;
  // final double width;
  // final double height;

  DetectionResult({
    required this.className,
    required this.confidence,
    // required this.x,
    // required this.y,
    // required this.width,
    // required this.height,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    return DetectionResult(
      className: json['class'] ?? 'Unknown',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      // x: (json['x'] ?? 0.0).toDouble(),
      // y: (json['y'] ?? 0.0).toDouble(),
      // width: (json['width'] ?? 0.0).toDouble(),
      // height: (json['height'] ?? 0.0).toDouble(),
    );
  }

  @override
  String toString() {
    return 'DetectionResult(className: $className, confidence: $confidence)';
    // Add other fields if needed: ', x: $x, y: $y, width: $width, height: $height)';
  }
}

/// Handles communication with the Roboflow API.
class FoodDetector {
  // API credentials - using the model that works with Method 1
  final String _apiKey = "c3XQV0tBY60urmHfsY3d";
  final String _modelId = "initial-test-i1hx0/1";

  /// Detects food items in an image using the Roboflow API.
  ///
  /// Takes the [imagePath] of the local image file.
  /// Returns a list of [DetectionResult] objects.
  /// Throws an exception if the API call fails or the file doesn't exist.
  Future<List<DetectionResult>> detectFoodItems(String imagePath) async {
    try {
      print("⭐ Starting food detection with: $imagePath");

      // 1. Check if file exists
      final file = File(imagePath);
      if (!await file.exists()) {
        print("❌ Error: Image file not found at $imagePath");
        throw Exception("Image file not found: $imagePath");
      }

      // 2. Read image file and encode as base64
      final imageBytes = await file.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // 3. Use the proven working method: detect.roboflow.com with query param auth
      final uri = Uri.parse("https://detect.roboflow.com/$_modelId")
          .replace(queryParameters: {'api_key': _apiKey});

      print("🔗 Sending request to: $uri");

      // 4. Make the API call
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: base64Image,
      );

      print("📥 Response status: ${response.statusCode}");

      // 5. Process the response
      if (response.statusCode == 200) {
        return _processResponse(response);
      } else {
        print("❌ API call failed: ${response.body}");
        throw Exception("API call failed with status: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error during food detection: $e");
      rethrow;
    }
  }

  /// Helper method to process API responses
  List<DetectionResult> _processResponse(http.Response response) {
    if (response.statusCode == 200) {
      print("✅ API call successful");

      try {
        final responseBody = jsonDecode(response.body);
        print("📊 API Response body: ${response.body}");

        // Parse predictions
        if (responseBody['predictions'] != null &&
            responseBody['predictions'] is List) {
          final List predictionsJson = responseBody['predictions'];
          print("🔍 Found ${predictionsJson.length} predictions");

          final List<DetectionResult> detections = predictionsJson
              .map((json) =>
                  DetectionResult.fromJson(json as Map<String, dynamic>))
              .toList();

          print("✅ Parsed detections: $detections");
          return detections;
        } else {
          print(
              "⚠️ Warning: 'predictions' field not found or not a list in response. Full response: ${response.body}");
          return []; // Return empty list if predictions are missing
        }
      } catch (e) {
        print("❌ Error parsing response JSON: $e");
        print("📄 Response that failed to parse: ${response.body}");
        throw Exception("Failed to parse API response: $e");
      }
    } else {
      print("❌ API call failed with status: ${response.statusCode}");
      print("📄 Error response body: ${response.body}");
      throw Exception(
          "API call failed with status code: ${response.statusCode}, body: ${response.body}");
    }
  }
}
