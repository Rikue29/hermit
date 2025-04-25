import 'package:flutter/material.dart';
import 'package:hermit/screens/food_scanner_screen.dart'; // Adjust path if needed
import 'screens/main_layout.dart';
import 'services/env_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Updated title
      title: 'Hermit Food Scanner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        bottomNavigationBarTheme: BottomNavigationBarTheme.of(context).copyWith(
          backgroundColor: Colors.white,
          elevation: 0,
        ), // Example theme color
        useMaterial3: true,
      ),
      // Set FoodScannerScreen as the home screen
      home: const MainLayout(),
    );
  }
}
