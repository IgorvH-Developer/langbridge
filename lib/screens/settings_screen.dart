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

    final currentAppLocaleCode = localeProvider.appLocale?.languageCode ?? Localizations.localeOf(context).languageCode;
    final currentTranslationLocaleCode = localeProvider.translationLocale?.languageCode;

    final List<DropdownMenuItem<String>> translationItems = [
      DropdownMenuItem<String>(
        value: null,
        child: Text(l10n.systemDefault),
      ),
      ...AppLocalizations.supportedLocales.map((locale) {
        return DropdownMenuItem<String>(
          value: locale.languageCode,
          child: Text(_getLanguageName(locale.languageCode)),
        );
      }).toList(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text(l10n.appLanguage),
            trailing: DropdownButton<String>(
              value: currentAppLocaleCode,
              onChanged: (String? newLanguageCode) {
                if (newLanguageCode != null) {
                  localeProvider.setAppLocale(Locale(newLanguageCode));
                }
              },
              items: AppLocalizations.supportedLocales.map((locale) {
                return DropdownMenuItem<String>(
                  value: locale.languageCode,
                  child: Text(_getLanguageName(locale.languageCode)),
                );
              }).toList(),
            ),
          ),

          ListTile(
            title: Text(l10n.translationLanguage),
            trailing: DropdownButton<String?>(
              value: currentTranslationLocaleCode,
              onChanged: (String? newLanguageCode) {
                final newLocale = newLanguageCode != null ? Locale(newLanguageCode) : null;
                localeProvider.setTranslationLocale(newLocale);
              },
              items: translationItems,
            ),
          ),
        ],
      ),
    );
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'en': return 'English';
      case 'ru': return 'Русский';
      default: return code;
    }
  }
}
