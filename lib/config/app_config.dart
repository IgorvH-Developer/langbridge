import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Приватный конструктор
  AppConfig._();

  static String get serverSchema => dotenv.env['server_schema'] ?? 'http';
  static String get serverAddr => dotenv.env['server_addr'] ?? '';
  static String get apiBaseUrl => '$serverSchema://$serverAddr';

  static Future<void> load(String flavor) async {
    String envFile;
    switch (flavor) {
      case 'prod':
        envFile = 'environments/.env.prod';
        break;
      case 'dev':
      default:
        envFile = 'environments/.env.dev';
        break;
    }
    await dotenv.load(fileName: envFile);
  }
}
