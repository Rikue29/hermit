import 'dart:convert';
import 'dart:io';
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

/// Handles communication with the Roboflow hosted inference API.
class FoodDetector {
  // IMPORTANT: Avoid hardcoding API keys in production. Use secure storage.
  final String _apiKey = "vrEeEAx2vhjcfk6Ub5U3";
  final String _modelEndpoint = "ingredients-detection-yolov8-npkkb/5";
  // Using detect.roboflow.com as the common inference endpoint
  final String _apiUrl = "https://detect.roboflow.com";

  /// Detects food items in an image using the Roboflow API.
  ///
  /// Takes the [imagePath] of the local image file.
  /// Returns a list of [DetectionResult] objects.
  /// Throws an exception if the API call fails or the file doesn't exist.
  Future<List<DetectionResult>> detectFoodItems(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      print("Error: Image file not found at $imagePath");
      throw Exception("Image file not found: $imagePath");
    }

    // 1. Read and encode image to Base64
    final imageBytes = await file.readAsBytes();
    final base64Image = base64Encode(imageBytes);

    // 2. Construct the API URL
    // Example: https://detect.roboflow.com/ingredients-detection-yolov8-npkkb/5?api_key=YOUR_API_KEY
    final uri = Uri.parse(
      "$_apiUrl/$_modelEndpoint",
    ).replace(queryParameters: {'api_key': _apiKey});

    print("Sending request to: $uri"); // For debugging

    // 3. Make the POST request
    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        // Send the base64 image data directly as the body
        body: base64Image,
      );

      // 4. Handle the response
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        print("API Response: ${response.body}"); // For debugging

        // Parse predictions
        if (responseBody['predictions'] is List) {
          final List predictionsJson = responseBody['predictions'];
          final List<DetectionResult> detections = predictionsJson
              .map(
                (json) =>
                    DetectionResult.fromJson(json as Map<String, dynamic>),
              )
              .toList();
          print("Detected items: $detections"); // For debugging
          return detections;
        } else {
          print(
            "Warning: 'predictions' field not found or not a list in response.",
          );
          return []; // Return empty list if predictions are missing
        }
      } else {
        print(
          "Error: Failed to detect food items. Status: ${response.statusCode}, Body: ${response.body}",
        );
        throw Exception(
          "Failed to detect food items. Status code: ${response.statusCode}",
        );
      }
    } catch (e) {
      print("Error during food detection API call: $e");
      // Rethrow the exception to be handled by the caller
      rethrow;
    }
  }
}
