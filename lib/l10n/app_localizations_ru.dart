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

  @override
  String get cancel => 'отмена';

  @override
  String get upp => 'вверх';

  @override
  String get permissionToCallNotification =>
      'Для звонков необходим доступ к камере и микрофону';

  @override
  String get permissionToVideoNotification =>
      'Для записи видео нужен доступ к камере и микрофону';

  @override
  String get incoming => 'входящий';

  @override
  String get video => 'видео';

  @override
  String get audio => 'аудио';

  @override
  String get reject => 'отклонить';

  @override
  String get accept => 'принять';

  @override
  String get recordingError => 'ошибка записи';

  @override
  String get noMessages => 'нет сообщений';

  @override
  String get noPermissionToCall => 'нет разрешений для звонка';

  @override
  String get chats => 'Чаты';

  @override
  String get youDontHaveChatsYet => 'У вас пока нет чатов';

  @override
  String get draft => 'черновик';

  @override
  String get profileSaved => 'Профиль сохранен!';

  @override
  String get saveErrorTryAgain => 'Ошибка сохранения. Попробуйте снова';

  @override
  String get editProfile => 'Редактировать профиль';

  @override
  String get saveChanges => 'Сохранить изменения';

  @override
  String get nativeLanguage => 'Родной язык';

  @override
  String get chooseNativeLanguage => 'Родной язык';

  @override
  String get learningLanguages => 'Изучаемые языки';

  @override
  String get youDidntAddAnyLanguage => 'Вы не добавили ни одного языка';

  @override
  String get level => 'уровень';

  @override
  String get addLearningLanguage => 'Добавить изучаемый язык';

  @override
  String get chooseLanguage => 'Выберите язык';

  @override
  String get knowledgeLevel => 'Уровень владения';

  @override
  String get add => 'добавить';

  @override
  String get publications => 'Лента публикаций';

  @override
  String get failedToCreateChat => 'Не удалось создать чат';

  @override
  String get failedToLoadProfile => 'Не удалось загрузить профиль';

  @override
  String get aboutMyself => 'О себе';

  @override
  String get languages => 'Языки';

  @override
  String get noInformation => 'Нет информации';

  @override
  String get failedToLoadChat => 'Не удалось загрузить чат';

  @override
  String get native => 'Родной';

  @override
  String get learn => 'Изучаю';

  @override
  String get age => 'возраст';

  @override
  String get country => 'страна';

  @override
  String get heigh => 'рост';

  @override
  String get recordVideo => 'Запись видео';

  @override
  String get send => 'отправить';

  @override
  String get notSpecified => 'не указан';

  @override
  String get centimeters => 'см';
}
