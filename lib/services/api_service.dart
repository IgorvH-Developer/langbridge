import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:LangBridge/repositories/auth_repository.dart';

const String _apiBaseUrl = "http://10.0.2.2/api";

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
  Future<String?> loginAndGetToken(String username, String password) async {
    final url = Uri.parse('$_apiBaseUrl/users/token');
    // Для этого запроса не нужны auth headers
    final response = await http.post(url, body: {
      'username': username,
      'password': password,
    }, headers: {'Content-Type': 'application/x-www-form-urlencoded'});

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['access_token'];
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

  // Метод logout() здесь больше не нужен, он будет вызываться напрямую из AuthRepository

  // --- Profile ---
  Future<Map<String, dynamic>?> getMyProfile() async {
    final url = Uri.parse('$_apiBaseUrl/users/me');
    final headers = await _getAuthHeaders();
    if (!headers.containsKey('Authorization')) return null;

    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    return null;
  }

  Future<Map<String, dynamic>?> updateUserProfile(Map<String, dynamic> data) async {
    final url = Uri.parse('$_apiBaseUrl/users/me');
    final headers = await _getAuthHeaders();
    if (!headers.containsKey('Authorization')) return null;

    final response = await http.put(
      url,
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    return null;
  }

  // --- Chats (остаются как были) ---
  Future<Map<String, dynamic>?> createChat(String title) async {
    final url = Uri.parse('$_apiBaseUrl/chats/');
    final headers = await _getAuthHeaders();
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(<String, String>{'title': title}),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    return null;
  }


  Future<List<Map<String, dynamic>>?> getAllChats() async {
    final url = Uri.parse('$_apiBaseUrl/chats/');
    try {
      final response = await http.get(url);
      if (kDebugMode) {
        print('Get All Chats URL: $url');
        print('Get All Chats Response Status: ${response.statusCode}');
        print('Get All Chats Response Body: ${response.body}');
      }
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching chats: $e');
      }
      return null;
    }
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
}
