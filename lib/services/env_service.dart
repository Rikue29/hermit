import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvService {
  static String get geminiApiKey {
    return dotenv.env['GEMINI_API_KEY'] ?? '';
  }

  static Future<void> init() async {
    await dotenv.load();
  }
} 