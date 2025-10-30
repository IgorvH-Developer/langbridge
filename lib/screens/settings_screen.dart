import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:LangBridge/l10n/app_localizations.dart';
import 'package:LangBridge/providers/locale_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeProvider = Provider.of<LocaleProvider>(context);

    final currentLocaleCode = localeProvider.locale?.languageCode ?? Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text(l10n.appLanguage),
            trailing: DropdownButton<String>(
              value: currentLocaleCode,
              onChanged: (String? newLanguageCode) {
                if (newLanguageCode != null) {
                  // Вызываем метод провайдера для смены языка
                  localeProvider.setLocale(Locale(newLanguageCode));
                }
              },
              items: AppLocalizations.supportedLocales.map((locale) {
                return DropdownMenuItem<String>(
                  value: locale.languageCode,
                  child: Text(
                      _getLanguageName(locale.languageCode)),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'ru':
        return 'Русский';
      default:
        return code;
    }
  }
}
