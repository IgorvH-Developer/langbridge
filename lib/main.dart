import 'package:LangBridge/repositories/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final _authRepository = AuthRepository();

  Future<bool> _checkLoginStatus() async {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'access_token');
    return token != null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LangBridge',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: FutureBuilder<bool>(
        future: _authRepository.isLoggedIn(), // Используем метод репозитория
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData && snapshot.data == true) {
            return const MainScreen(); // Пользователь залогинен
          }
          return const LoginScreen(); // Пользователь не залогинен
        },
      ),
    );
  }
}
