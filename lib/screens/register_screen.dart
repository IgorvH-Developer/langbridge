// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:LangBridge/models/language.dart';
import 'package:LangBridge/repositories/auth_repository.dart';
import 'package:LangBridge/screens/main_screen.dart';
import 'package:LangBridge/l10n/app_localizations.dart';

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
              (Route<dynamic> route) => false,
        );
      } else {
        // Используем локализованную строку для ошибки
        setState(() { _error = AppLocalizations.of(context)!.registrationError; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.registerWithLanguage(widget.selectedLanguage.name))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.youHaveSelectedAsNative(widget.selectedLanguage.name),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: l10n.username, border: const OutlineInputBorder()),
                validator: (value) => (value == null || value.isEmpty) ? l10n.enterUsername : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: l10n.password, border: const OutlineInputBorder()),
                obscureText: true,
                validator: (value) => (value == null || value.isEmpty) ? l10n.enterPassword : null,
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton(
                  onPressed: _performRegister,
                  child: Text(l10n.registerButton),
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
