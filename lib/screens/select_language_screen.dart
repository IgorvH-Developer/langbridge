// lib/screens/select_language_screen.dart
import 'package:flutter/material.dart';
import 'package:LangBridge/models/language.dart';
import 'package:LangBridge/services/api_service.dart';
import 'package:LangBridge/screens/register_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

class SelectLanguageScreen extends StatefulWidget {
  const SelectLanguageScreen({super.key});

  @override
  State<SelectLanguageScreen> createState() => _SelectLanguageScreenState();
}

class _SelectLanguageScreenState extends State<SelectLanguageScreen> {
  List<Language>? _languages;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLanguages();
  }

  Future<void> _fetchLanguages() async {
    try {
      final languages = await ApiService().getAllLanguages();
      if (mounted) {
        setState(() {
          _languages = languages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Не удалось загрузить список языков.";
          _isLoading = false;
        });
      }
    }
  }

  void _onLanguageSelected(Language language) async { // <<< СДЕЛАТЬ ASYNC
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);

    if (!mounted) return;

    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => RegisterScreen(selectedLanguage: language),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Выберите родной язык"),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_languages == null || _languages!.isEmpty) {
      return const Center(child: Text("Языки не найдены."));
    }
    return ListView.builder(
      itemCount: _languages!.length,
      itemBuilder: (context, index) {
        final language = _languages![index];
        return ListTile(
          title: Text(language.name),
          subtitle: Text(language.code.toUpperCase()),
          onTap: () => _onLanguageSelected(language),
          trailing: const Icon(Icons.arrow_forward_ios),
        );
      },
    );
  }
}
