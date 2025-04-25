import 'package:flutter/material.dart';
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
      title: 'Food Waste Reducer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        bottomNavigationBarTheme: BottomNavigationBarTheme.of(context).copyWith(
          backgroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const MainLayout(),
    );
  }
}
