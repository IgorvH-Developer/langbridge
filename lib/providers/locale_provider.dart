import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider with ChangeNotifier {
  static const String _appLocaleKey = 'app_locale';
  static const String _translationLocaleKey = 'translation_locale';

  Locale? _appLocale;
  Locale? _translationLocale;

  Locale? get appLocale => _appLocale;
  Locale? get translationLocale => _translationLocale;

  LocaleProvider() {
    _loadLocales();
  }

  Future<void> _loadLocales() async {
    final prefs = await SharedPreferences.getInstance();
    final appLangCode = prefs.getString(_appLocaleKey);
    final translationLangCode = prefs.getString(_translationLocaleKey); // <<< Новое

    if (appLangCode != null) {
      _appLocale = Locale(appLangCode);
    }
    if (translationLangCode != null) { // <<< Новое
      _translationLocale = Locale(translationLangCode);
    }
    notifyListeners();
  }

  Future<void> setAppLocale(Locale newLocale) async {
    if (_appLocale == newLocale) return;

    _appLocale = newLocale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appLocaleKey, newLocale.languageCode);
    notifyListeners();
  }

  Future<void> setTranslationLocale(Locale? newLocale) async {
    if (_translationLocale == newLocale) return;

    _translationLocale = newLocale;
    final prefs = await SharedPreferences.getInstance();
    if (newLocale == null) {
      await prefs.remove(_translationLocaleKey);
    } else {
      await prefs.setString(_translationLocaleKey, newLocale.languageCode);
    }
    notifyListeners();
  }
}
