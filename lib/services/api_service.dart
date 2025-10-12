import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:LangBridge/config/app_config.dart';
import 'package:LangBridge/models/language.dart';
import 'package:LangBridge/models/user_profile.dart';
import 'package:LangBridge/models/transcription_data.dart';
import 'package:LangBridge/repositories/auth_repository.dart';

// const String _apiBaseUrl = "http://10.0.2.2/api";
final String _apiBaseUrl = "${AppConfig.apiBaseUrl}/api";

class ApiService {
  // Теперь ApiService не зависит от AuthRepository, а только от хранилища
  final _storage = const FlutterSecureStorage();

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _storage.read(key: AuthRepository.accessTokenKey);
    if (token == null) {
      return {'Content-Type': 'application/json; charset=UTF-8'};
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json; charset=UTF-8',
    };
  }

  // --- Auth ---
  Future<Map<String, String>?> loginAndGetData(String username, String password) async {
    final url = Uri.parse('$_apiBaseUrl/users/token');
    final response = await http.post(url, body: {
      'username': username,
      'password': password,
    }, headers: {'Content-Type': 'application/x-www-form-urlencoded'});

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'access_token': data['access_token'],
        'user_id': data['user_id'],
      };
    }
    return null;
  }

  Future<bool> register(String username, String password) async {
    final url = Uri.parse('$_apiBaseUrl/users/register');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    return response.statusCode == 201;
  }

  // --- Profile ---
  Future<UserProfile?> getMyProfile() async {
    final url = Uri.parse('$_apiBaseUrl/users/me');
    final headers = await _getAuthHeaders();
    if (!headers.containsKey('Authorization')) return null;

    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      return UserProfile.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    }
    return null;
  }

  Future<UserProfile?> updateUserProfile(String userId, Map<String, dynamic> data) async {
    final url = Uri.parse('$_apiBaseUrl/users/$userId');
    final headers = await _getAuthHeaders();

    // --- НАЧАЛО БЛОКА ДИАГНОСТИКИ ---
    print('--- ОТЛАДКА ЗАПРОСА НА ОБНОВЛЕНИЕ ПРОФИЛЯ ---');
    print('URL: $url');
    print('Headers: $headers'); // <-- Самый важный print! Проверяем наличие 'Authorization'.
    print('Body: ${jsonEncode(data)}');
    print('-----------------------------------------');
    // --- КОНЕЦ БЛОКА ДИАГНОСТИКИ ---

    if (!headers.containsKey('Authorization')) {
      print("КРИТИЧЕСКАЯ ОШИБКА: Заголовок 'Authorization' не был добавлен в headers.");
      return null;
    }

    final response = await http.put(
      url,
      headers: headers,
      body: jsonEncode(data),
    );

    // --- ОТЛАДКА ОТВЕТА ---
    print('Ответ сервера: ${response.statusCode}');
    print('Тело ответа: ${response.body}');
    // --------------------

    if (response.statusCode == 200) {
      return UserProfile.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    }
    return null;
  }

  Future<UserProfile?> getUserProfile(String userId) async {
    print('getting profile of user: $userId');
    final url = Uri.parse('$_apiBaseUrl/users/$userId');
    final headers = await _getAuthHeaders();

    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      return UserProfile.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    }
    return null;
  }

  Future<List<UserProfile>?> findUsers({String? nativeLangCode, String? learningLangCode}) async {
    final queryParams = {
      if (nativeLangCode != null) 'native_lang_code': nativeLangCode,
      if (learningLangCode != null) 'learning_lang_code': learningLangCode,
    };
    final url = Uri.parse('$_apiBaseUrl/users/').replace(queryParameters: queryParams);
    final headers = await _getAuthHeaders();

    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      // ВАЖНО: UserProfileResponse от сервера немного отличается от UserProfile,
      // поэтому используем UserProfile.fromJson. Если бы схемы были разные, нужна была бы другая модель.
      return data.map((item) => UserProfile.fromJson(item)).toList();
    }
    return null;
  }

  Future<String?> uploadAvatar(String userId, String filePath) async {
    final url = Uri.parse('$_apiBaseUrl/media/upload/avatar/$userId');
    final request = http.MultipartRequest('POST', url);

    final headers = await _getAuthHeaders();
    // Удаляем Content-Type, так как для multipart/form-data он будет установлен автоматически с границей
    headers.remove('Content-Type');
    request.headers.addAll(headers);

    request.files.add(
      await http.MultipartFile.fromPath(
        'file', // Имя поля, ожидаемое на бэкенде
        filePath,
        contentType: MediaType('image', 'jpeg'), // Тип контента
      ),
    );

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['avatar_url']; // Возвращаем относительный URL, например /uploads/avatar.jpg
      } else {
        print('Avatar upload failed: ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error uploading avatar: $e');
      return null;
    }
  }

  /// Получает список всех языков, доступных в системе.
  Future<List<Language>?> getAllLanguages() async {
    // Этот эндпоинт уже существует на бэкенде, мы просто вызываем его
    final url = Uri.parse('$_apiBaseUrl/users/languages/all');
    final headers = await _getAuthHeaders();

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((item) => Language.fromJson(item)).toList();
      }
    } catch (e) {
      print('Error fetching all languages: $e');
    }
    return null;
  }

  // --- Chats ---

  Future<Map<String, dynamic>?> getOrCreatePrivateChat(String partnerId) async {
    final url = Uri.parse('$_apiBaseUrl/chats/get-or-create/private')
        .replace(queryParameters: {'partner_id': partnerId});
    final headers = await _getAuthHeaders();
    if (!headers.containsKey('Authorization')) return null;

    final response = await http.post(url, headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    return null;
  }

  Future<List<Map<String, dynamic>>?> getAllChats() async {
    final url = Uri.parse('$_apiBaseUrl/chats/');
    final headers = await _getAuthHeaders();
    try {
      final response = await http.get(url, headers: headers); // <<< ПЕРЕДАЕМ ЗАГОЛОВОК
      print('Get All Chats URL: $url');
      print('Get All Chats Response Status: ${response.statusCode}');
      print('Get All Chats Response Body: ${response.body}');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        return null;
      }
    } catch (e) {
      print('Error fetching chats: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>?> getChatMessages(String chatId) async {
    final url = Uri.parse('$_apiBaseUrl/chats/$chatId/messages');
    try {
      final response = await http.get(url);
      if (kDebugMode) {
        print('Get Chat Messages URL: $url');
        print('Get Chat Messages Response Status: ${response.statusCode}');
        print('Get Chat Messages Response Body: ${response.body}');
      }
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        print('Failed to fetch messages for chat $chatId. Status: ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching messages for chat $chatId: $e');
      }
      return null;
    }
  }

  // Новый метод для загрузки видео
  Future<Map<String, dynamic>?> uploadVideo({
    required String filePath,
    required String chatId,
    required String senderId,
  }) async {
    final url = Uri.parse('$_apiBaseUrl/media/upload/video')
        .replace(queryParameters: {
      'chat_id': chatId,
      'sender_id': senderId,
    });

    final request = http.MultipartRequest('POST', url);

    // Добавляем токен в заголовки
    final headers = await _getAuthHeaders();
    request.headers.addAll(headers);

    // Добавляем файл
    request.files.add(await http.MultipartFile.fromPath(
      'file', // Это имя поля должно совпадать с ожидаемым на бэкенде
      filePath,
      contentType: MediaType('video', 'mp4'), // Укажите правильный тип
    ));

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse); // Преобразуем ответ

      if (response.statusCode == 200) {
        // Возвращаем тело ответа, которое содержит URL и транскрипцию
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        print('Video upload failed: ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error uploading video: $e');
      return null;
    }
  }

  Future<bool> updateUserLanguages(String userId, List<Map<String, dynamic>> languagesData) async {
    final url = Uri.parse('$_apiBaseUrl/users/$userId/languages');
    final headers = await _getAuthHeaders();
    if (!headers.containsKey('Authorization')) return false;

    final response = await http.put(
      url,
      headers: headers,
      body: jsonEncode(languagesData),
    );
    return response.statusCode == 204; // 204 No Content
  }

  Future<TranscriptionData?> getTranscriptionForMessage(String messageId) async {
    final url = Uri.parse('$_apiBaseUrl/media/transcribe/$messageId');
    final headers = await _getAuthHeaders();
    if (!headers.containsKey('Authorization')) return null;

    try {
      final response = await http.post(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return TranscriptionData.fromJson(data);
      } else {
        print('Transcription request failed: ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting transcription: $e');
      return null;
    }
  }

  Future<bool> updateTranscriptionForMessage(String messageId, TranscriptionData data) async {
    final url = Uri.parse('$_apiBaseUrl/media/transcribe/$messageId');
    final headers = await _getAuthHeaders();
    if (!headers.containsKey('Authorization')) return false;

    try {
      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode(data.toJson()),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating transcription: $e');
      return false;
    }
  }
}
