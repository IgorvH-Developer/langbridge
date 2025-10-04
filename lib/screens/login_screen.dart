import 'package:flutter/material.dart';
import '../repositories/auth_repository.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authRepository = AuthRepository();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  void _submit() async {
    setState(() => _isLoading = true);
    final username = _usernameController.text;
    final password = _passwordController.text;

    bool success = false;
    if (_isLogin) {
      success = await _authRepository.login(username, password);
    } else {
      // Логика регистрации и последующего входа
      bool registered = await _authRepository.register(username, password);
      if (registered) {
        success = await _authRepository.login(username, password);
      }
    }

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isLogin ? 'Ошибка входа' : 'Ошибка регистрации')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Вход' : 'Регистрация')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Имя пользователя')),
            TextField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Пароль'), obscureText: true),
            const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              ElevatedButton(onPressed: _submit, child: Text(_isLogin ? 'Войти' : 'Зарегистрироваться')),
            TextButton(
              onPressed: () => setState(() => _isLogin = !_isLogin),
              child: Text(_isLogin ? 'Создать аккаунт' : 'Уже есть аккаунт'),
            )
          ],
        ),
      ),
    );
  }
}