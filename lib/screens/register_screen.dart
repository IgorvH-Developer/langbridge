// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:LangBridge/models/language.dart';
import 'package:LangBridge/repositories/auth_repository.dart';
import 'package:LangBridge/screens/main_screen.dart';

class RegisterScreen extends StatefulWidget {
  final Language selectedLanguage;

  const RegisterScreen({super.key, required this.selectedLanguage});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authRepository = AuthRepository();
  bool _isLoading = false;
  String? _error;

  Future<void> _performRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; });

    final success = await _authRepository.registerAndLogin(
      username: _usernameController.text,
      password: _passwordController.text,
      nativeLanguageId: widget.selectedLanguage.id,
    );

    if (mounted) {
      setState(() { _isLoading = false; });
      if (success) {
        // Если все прошло успешно, переходим на главный экран приложения
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainScreen()),
              (Route<dynamic> route) => false, // Удаляем все предыдущие экраны
        );
      } else {
        setState(() { _error = "Ошибка регистрации. Возможно, имя пользователя уже занято."; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Регистрация (${widget.selectedLanguage.name})')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Вы выбрали "${widget.selectedLanguage.name}" как ваш родной язык.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Имя пользователя', border: OutlineInputBorder()),
                validator: (value) => (value == null || value.isEmpty) ? 'Введите имя пользователя' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Пароль', border: OutlineInputBorder()),
                obscureText: true,
                validator: (value) => (value == null || value.isEmpty) ? 'Введите пароль' : null,
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton(
                  onPressed: _performRegister,
                  child: const Text('Зарегистрироваться'),
                ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
