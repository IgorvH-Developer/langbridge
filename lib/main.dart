import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:LangBridge/screens/splash_screen.dart';

import 'package:LangBridge/config/app_config.dart';
import 'package:LangBridge/repositories/auth_repository.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  // 1. Убедимся, что Flutter Engine инициализирован
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Определяем flavor сборки (по умолчанию 'dev')
  const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');

  // 3. Загружаем соответствующий .env файл
  await AppConfig.load(flavor);

  // 4. Запускаем приложение
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LangBridge',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
