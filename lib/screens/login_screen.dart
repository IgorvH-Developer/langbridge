import 'package:flutter/material.dart';
import 'package:LangBridge/repositories/auth_repository.dart';
import 'package:LangBridge/screens/main_screen.dart';
import 'package:LangBridge/screens/select_language_screen.dart';
import 'package:LangBridge/l10n/app_localizations.dart';

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
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

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
          SnackBar(content: Text(l10n.loginError)),
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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.loginButton)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                    labelText: l10n.username,
                    border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? l10n.enterUsername : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                    labelText: l10n.password,
                    border: OutlineInputBorder()),
                obscureText: true,
                validator: (v) => v!.isEmpty ? l10n.enterPassword : null,
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
                      child: Text(l10n.loginButton),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _navigateToLanguageSelect,
                      child: Text(l10n.createAccountButton),
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
