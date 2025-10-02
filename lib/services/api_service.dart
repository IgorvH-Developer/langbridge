import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kDebugMode; // Для вывода ошибок в консоль

// Базовый URL вашего API (замените на свой, если отличается)
// Для Android эмулятора, если Nginx на порту 80 хоста
const String _apiBaseUrl = "http://10.0.2.2/api"; // Без слеша в конце, если пути в методах начинаются с /

class ApiService {
  Future<Map<String, dynamic>?> createChat(String title) async {
    final url = Uri.parse('$_apiBaseUrl/chats/'); // Конечный слеш важен, если FastAPI ожидает его
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'title': title,
        }),
      );

      if (kDebugMode) {
        log('Create Chat URL: $url');
        log('Create Chat Request Body: ${jsonEncode(<String, String>{'title': title})}');
        log('Create Chat Response Status: ${response.statusCode}');
        log('Create Chat Response Body: ${response.body}');
      }

      if (response.statusCode == 201) { // HTTP 201 Created
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        // Обработка других кодов состояния (4xx, 5xx)
        if (kDebugMode) {
          log('Failed to create chat. Status: ${response.statusCode}, Body: ${response.body}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        log('Error creating chat: $e');
      }
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> getAllChats() async {
    final url = Uri.parse('$_apiBaseUrl/chats/');
    try {
      final response = await http.get(url);
      if (kDebugMode) {
        log('Get All Chats URL: $url');
        log('Get All Chats Response Status: ${response.statusCode}');
        log('Get All Chats Response Body: ${response.body}');
      }
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        log('Error fetching chats: $e');
      }
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> getChatMessages(String chatId) async {
    final url = Uri.parse('$_apiBaseUrl/chats/$chatId/messages');
    try {
      final response = await http.get(url);
      if (kDebugMode) {
        log('Get Chat Messages URL: $url');
        log('Get Chat Messages Response Status: ${response.statusCode}');
        log('Get Chat Messages Response Body: ${response.body}');
      }
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        log('Failed to fetch messages for chat $chatId. Status: ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        log('Error fetching messages for chat $chatId: $e');
      }
      return null;
    }
  }
}
