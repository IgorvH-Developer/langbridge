import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:LangBridge/repositories/auth_repository.dart';
import 'main_screen.dart';
import 'login_screen.dart';
import 'select_language_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _determineNextScreen();
  }

  Future<void> _determineNextScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final authRepository = AuthRepository();

    final bool isLoggedIn = await authRepository.isLoggedIn();
    final bool hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;

    // Небольшая задержка, чтобы сплэш-скрин был виден
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    Widget nextScreen;

    if (isLoggedIn) {
      // 1. Пользователь залогинен -> Главный экран
      nextScreen = const MainScreen();
    } else {
      if (hasCompletedOnboarding) {
        // 2. Не залогинен, но уже проходил онбординг -> Экран входа
        nextScreen = const LoginScreen();
      } else {
        // 3. Самый первый запуск -> Экран выбора языка
        nextScreen = const SelectLanguageScreen();
      }
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Простой экран-заставка, пока идет проверка
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
