import 'package:flutter/material.dart';
import 'package:LangBridge/repositories/auth_repository.dart';
import 'package:LangBridge/screens/main_screen.dart';
import 'package:LangBridge/screens/select_language_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authRepository = AuthRepository();
  bool _isLoading = false;

  Future<void> _performLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final success = await _authRepository.login(
      _usernameController.text,
      _passwordController.text,
    );
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Неверное имя пользователя или пароль')),
        );
      }
    }
  }

  void _navigateToLanguageSelect() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SelectLanguageScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Вход')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Имя пользователя', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Введите имя пользователя' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Пароль', border: OutlineInputBorder()),
                obscureText: true,
                validator: (v) => v!.isEmpty ? 'Введите пароль' : null,
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: _performLogin,
                      child: const Text('Войти'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _navigateToLanguageSelect,
                      child: const Text('Создать аккаунт'),
                    ),
                  ],
                )
            ],
          ),
        ),
      ),
    );
  }
}
