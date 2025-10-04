import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';

class AuthRepository {
  // ApiService теперь не final, чтобы избежать проблем с инициализацией
  late ApiService _apiService;

  final _storage = const FlutterSecureStorage();

  // Ключи для безопасного хранилища теперь публичные
  static const accessTokenKey = 'access_token';
  static const userIdKey = 'user_id';

  // Используем конструктор для инициализации
  AuthRepository() {
    // ApiService создается здесь, цикл разорван
    _apiService = ApiService();
  }

  /// Производит вход пользователя, получает и сохраняет токен и ID пользователя.
  /// Возвращает `true` при успехе, иначе `false`.
  Future<bool> login(String username, String password) async {
    final token = await _apiService.loginAndGetToken(username, password);
    if (token == null) {
      return false;
    }
    await _storage.write(key: accessTokenKey, value: token);

    final profile = await _apiService.getMyProfile();
    if (profile != null && profile['id'] != null) {
      await _storage.write(key: userIdKey, value: profile['id']);
      return true;
    } else {
      await logout();
      return false;
    }
  }

  /// Регистрирует нового пользователя.
  Future<bool> register(String username, String password) async {
    return await _apiService.register(username, password);
  }

  /// Производит выход пользователя, удаляя все сохраненные данные аутентификации.
  Future<void> logout() async {
    await _storage.deleteAll();
  }

  /// Получает сохраненный токен доступа.
  Future<String?> getToken() async {
    return await _storage.read(key: accessTokenKey);
  }

  /// Статический метод для получения ID текущего аутентифицированного пользователя.
  static Future<String?> getCurrentUserId() async {
    const storage = FlutterSecureStorage();
    return await storage.read(key: userIdKey);
  }

  /// Проверяет, залогинен ли пользователь (наличие токена).
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }
}
