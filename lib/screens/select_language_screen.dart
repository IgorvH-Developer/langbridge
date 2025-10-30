// lib/screens/select_language_screen.dart
import 'package:flutter/material.dart';
import 'package:LangBridge/models/language.dart';
import 'package:LangBridge/services/api_service.dart';
import 'package:LangBridge/screens/register_screen.dart';
import 'package:LangBridge/l10n/app_localizations.dart';
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
  bool _isDependenciesInitialized = false;
  Language? _selectedLanguage;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isDependenciesInitialized) {
      _isDependenciesInitialized = true;
      _fetchLanguages();
    }
  }

  Future<void> _fetchLanguages() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = Localizations.localeOf(context);

    try {
      final languages = await ApiService().getAllLanguages();
      if (mounted) {
        Language? suggested;
        if (languages != null && languages.isNotEmpty) {
          try {
            suggested = languages.firstWhere((lang) => lang.code == currentLocale.languageCode);
          } catch (e) {
            suggested = languages.first;
          }
        }

        setState(() {
          _languages = languages;
          _selectedLanguage = suggested;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = l10n.failedToLoadLanguages;
          _isLoading = false;
        });
      }
    }
  }

  void _onLanguageTap(Language language) {
    setState(() {
      _selectedLanguage = language;
    });
  }

  void _confirmSelection() async {
    if (_selectedLanguage == null) return; // Защита от случайного вызова

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (context) => RegisterScreen(selectedLanguage: _selectedLanguage!),
    ));
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectNativeLanguage),
        centerTitle: true,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _selectedLanguage != null ? _confirmSelection : null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 18),
          ),
          child: Text(l10n.confirm),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_languages == null || _languages!.isEmpty) {
      return Center(child: Text(l10n.noLanguagesFound));
    }

    final displayLanguages = List<Language>.from(_languages!);

    return ListView.builder(
      itemCount: displayLanguages.length,
      itemBuilder: (context, index) {
        final language = displayLanguages[index];
        final bool isSelected = language.id == _selectedLanguage?.id;

        return ListTile(
          tileColor: isSelected ? Colors.blue.withOpacity(0.1) : null,
          leading: isSelected
              ? const Icon(Icons.check_circle, color: Colors.blue)
              : const Icon(Icons.language, color: Colors.grey),
          title: Text(
            language.name,
            style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
          ),
          subtitle: Text(language.code.toUpperCase()),
          onTap: () => _onLanguageTap(language),
        );
      },
    );
  }
}
