import 'package:flutter/material.dart';
// Import the new screen
import 'package:hermit/screens/food_scanner_screen.dart'; // Adjust path if needed

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Updated title
      title: 'Hermit Food Scanner',
      theme: ThemeData(
        // Using a Material 3 theme
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
        ), // Example theme color
        useMaterial3: true,
      ),
      // Set FoodScannerScreen as the home screen
      home: const FoodScannerScreen(),
    );
  }
}
