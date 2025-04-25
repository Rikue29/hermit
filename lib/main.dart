import 'package:flutter/material.dart';
import 'package:hermit/homepage.dart';
import 'package:image_picker/image_picker.dart';
import 'screens/food_scanner_screen.dart'; // Corrected path
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
      title: 'Hermit',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const Homepage(),
    );
  }
}

