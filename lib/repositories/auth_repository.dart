import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';

class AuthRepository {
  late ApiService _apiService;

  final _storage = const FlutterSecureStorage();

  AndroidOptions _getAndroidOptions() => const AndroidOptions(
    resetOnError: true,
  );

  static const accessTokenKey = 'access_token';
  static const userIdKey = 'user_id';

  AuthRepository() {
    _apiService = ApiService();
  }

  Future<bool> login(String username, String password) async {
    final loginData = await _apiService.loginAndGetData(username, password);

    if (loginData == null || loginData['access_token'] == null || loginData['user_id'] == null) {
      return false;
    }

    final token = loginData['access_token']!;
    final userId = loginData['user_id']!;

    final options = _getAndroidOptions();
    try {
      await _storage.write(key: accessTokenKey, value: token, aOptions: options);
      await _storage.write(key: userIdKey, value: userId, aOptions: options);
    } catch (e) {
      print("КРИТИЧЕСКАЯ ОШИБКА при записи в Secure Storage: $e");
      await _storage.deleteAll(aOptions: options);
      return false;
    }

    return true;
  }

  Future<bool> registerAndLogin({
    required String username,
    required String password,
    required int nativeLanguageId,
  }) async {
    // 1. Пытаемся зарегистрироваться
    final bool didRegister = await _apiService.register(username, password, nativeLanguageId);

    if (didRegister) {
      // 2. Если регистрация прошла успешно, сразу же пытаемся войти с теми же данными
      print("Регистрация успешна. Выполняется автоматический вход...");
      final bool didLogin = await login(username, password);
      return didLogin;
    } else {
      // 3. Если регистрация не удалась, возвращаем false
      print("Регистрация не удалась.");
      return false;
    }
  }

  /// Получает сохраненный токен доступа.
  Future<String?> getToken() async {
    return await _storage.read(key: accessTokenKey, aOptions: _getAndroidOptions());
  }

  /// Статический метод для получения ID текущего аутентифицированного пользователя.
  static Future<String?> getCurrentUserId() async {
    const storage = FlutterSecureStorage();
    return await storage.read(key: userIdKey, aOptions: const AndroidOptions(resetOnError: true));
  }

  /// Проверяет, залогинен ли пользователь (наличие токена).
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  Future<void> logout() async {
    await _storage.deleteAll(aOptions: _getAndroidOptions());
  }

  Future<bool> register(String username, String password, int nativeLanguageId) async {
    return await _apiService.register(username, password, nativeLanguageId);
  }
}
