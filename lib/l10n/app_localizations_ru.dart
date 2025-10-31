// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'LangBridge';

  @override
  String registerWithLanguage(String languageName) {
    return 'Регистрация ($languageName)';
  }

  @override
  String youHaveSelectedAsNative(String languageName) {
    return 'Вы выбрали \"$languageName\" как ваш родной язык.';
  }

  @override
  String get username => 'Имя пользователя';

  @override
  String get enterUsername => 'Введите имя пользователя';

  @override
  String get password => 'Пароль';

  @override
  String get enterPassword => 'Введите пароль';

  @override
  String get registerButton => 'Зарегистрироваться';

  @override
  String get registrationError =>
      'Ошибка регистрации. Возможно, имя пользователя уже занято.';

  @override
  String get loginButton => 'Войти';

  @override
  String get createAccountButton => 'Создать аккаунт';

  @override
  String get loginError => 'Неверное имя пользователя или пароль';

  @override
  String get selectNativeLanguage => 'Выберите родной язык';

  @override
  String get failedToLoadLanguages => 'Не удалось загрузить список языков.';

  @override
  String get noLanguagesFound => 'Языки не найдены.';

  @override
  String get registrationSuccessful =>
      'Регистрация успешна! Теперь вы можете войти.';

  @override
  String get settings => 'Настройки';

  @override
  String get appLanguage => 'Язык приложения';

  @override
  String get confirm => 'Подтвердить';

  @override
  String get translationLanguage => 'Язык перевода';

  @override
  String get systemDefault => 'Язык системы';

  @override
  String get translationError => 'Ошибка перевода';
}
