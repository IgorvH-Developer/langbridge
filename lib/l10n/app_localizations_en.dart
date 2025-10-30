// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'LangBridge';

  @override
  String registerWithLanguage(String languageName) {
    return 'Register ($languageName)';
  }

  @override
  String youHaveSelectedAsNative(String languageName) {
    return 'You have selected \"$languageName\" as your native language.';
  }

  @override
  String get username => 'Username';

  @override
  String get enterUsername => 'Enter username';

  @override
  String get password => 'Password';

  @override
  String get enterPassword => 'Enter password';

  @override
  String get registerButton => 'Register';

  @override
  String get registrationError =>
      'Registration failed. Perhaps the username is already taken.';

  @override
  String get loginButton => 'Login';

  @override
  String get createAccountButton => 'Create Account';

  @override
  String get loginError => 'Invalid username or password';

  @override
  String get selectNativeLanguage => 'Select Native Language';

  @override
  String get failedToLoadLanguages => 'Failed to load language list.';

  @override
  String get noLanguagesFound => 'No languages found.';

  @override
  String get registrationSuccessful =>
      'Registration successful! You can now log in.';

  @override
  String get settings => 'Settings';

  @override
  String get appLanguage => 'Application Language';

  @override
  String get confirm => 'confirm';
}
