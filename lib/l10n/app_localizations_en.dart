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

  @override
  String get translationLanguage => 'Translation Language';

  @override
  String get systemDefault => 'System Default';

  @override
  String get translationError => 'Translation failed';

  @override
  String get cancel => 'cancel';

  @override
  String get upp => 'upp';

  @override
  String get permissionToCallNotification => 'Permission to call notification';

  @override
  String get permissionToVideoNotification =>
      'Permission to video notification';

  @override
  String get incoming => 'incoming';

  @override
  String get video => 'video';

  @override
  String get audio => 'audio';

  @override
  String get reject => 'reject';

  @override
  String get accept => 'accept';

  @override
  String get recordingError => 'recording error';

  @override
  String get noMessages => 'no messages';

  @override
  String get noPermissionToCall => 'no permission to call';

  @override
  String get chats => 'Chats';

  @override
  String get youDontHaveChatsYet => 'You don\'t have chats yet';

  @override
  String get draft => 'draft';

  @override
  String get profileSaved => 'Profile saved!';

  @override
  String get saveErrorTryAgain => 'Save error. Try again';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get nativeLanguage => 'Native language';

  @override
  String get chooseNativeLanguage => 'Choose native language';

  @override
  String get learningLanguages => 'Learning languages';

  @override
  String get youDidntAddAnyLanguage => 'You didn\'t add any language';

  @override
  String get level => 'level';

  @override
  String get addLearningLanguage => 'Add learning language';

  @override
  String get chooseLanguage => 'Choose language';

  @override
  String get knowledgeLevel => 'Knowledge level';

  @override
  String get add => 'add';

  @override
  String get publications => 'Publications';

  @override
  String get failedToCreateChat => 'Failed to create chat';

  @override
  String get failedToLoadProfile => 'Failed to load profile';

  @override
  String get aboutMyself => 'About myself';

  @override
  String get languages => 'Languages';

  @override
  String get noInformation => 'No information';

  @override
  String get failedToLoadChat => 'Failed to load chat';

  @override
  String get native => 'Native';

  @override
  String get learn => 'Learn';

  @override
  String get age => 'Age';

  @override
  String get country => 'Country';

  @override
  String get heigh => 'Heigh';

  @override
  String get recordVideo => 'Record video';

  @override
  String get send => 'send';

  @override
  String get notSpecified => 'not specified';

  @override
  String get centimeters => 'cm';
}
