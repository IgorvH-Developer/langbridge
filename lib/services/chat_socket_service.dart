import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import 'package:LangBridge/repositories/auth_repository.dart'; // <<< Добавить
import 'webrtc_manager.dart';

import 'package:LangBridge/config/app_config.dart';
import 'package:LangBridge/models/message.dart';

// Интерфейс для обратного вызова при получении нового сообщения
typedef OnMessageReceivedCallback = void Function(Message message);

class ChatSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  final Uuid _uuid = const Uuid();
  final ValueNotifier<Map<String, dynamic>?> signalingMessageNotifier = ValueNotifier(null); // <<< Добавить
  WebRTCManager? webRTCManager;

  static final String _socketBaseUrl = "ws://${AppConfig.serverAddr}/ws/";
  bool get isConnected => _channel != null && _channelSubscription != null && !_channelSubscription!.isPaused;
  final ValueNotifier<List<Message>> messagesNotifier = ValueNotifier<List<Message>>([]);
  String? currentChatId; // Made public

  Future<void> connect(String chatId, List<Message> initialMessages) async {
    if (currentChatId == chatId && isConnected) {
      print("Уже подключен к чату: $chatId");
      return;
    }
    disconnect();

    currentChatId = chatId;
    messagesNotifier.value = List<Message>.from(initialMessages);

    final userId = await AuthRepository.getCurrentUserId();
    if (userId == null) {
      print("Ошибка: не удалось получить ID пользователя для подключения к сокету.");
      return;
    }

    final uri = Uri.parse("$_socketBaseUrl$chatId?user_id=$userId");

    print("Подключение к WebSocket: $uri");

    _channel = WebSocketChannel.connect(uri);

    _channelSubscription = _channel!.stream.listen(
      (event) {
        print("Получено от сокета ($chatId): $event");
        try {
          final Map<String, dynamic> data = jsonDecode(event);
          final type = data['type'] as String?;

          // <<< НАЧАЛО ИЗМЕНЕНИЙ: Обработка сигнальных сообщений >>>
          if (type == 'call_offer' || type == 'call_answer' || type == 'ice_candidate' || type == 'call_end') {
            signalingMessageNotifier.value = data;
          } else {
            final newMessage = Message.fromJson(data);
            final updatedMessages = List<Message>.from(messagesNotifier.value)..add(newMessage);
            messagesNotifier.value = updatedMessages;
          }

        } catch (e) {
          print("Ошибка декодирования сообщения от сокета ($chatId): $e");
          final errorMessage = Message(
            id: _uuid.v4(),
            sender: "system",
            content: "Ошибка обработки данных: $e",
            type: MessageType.text, // или специальный тип для ошибок
            timestamp: DateTime.now(),
          );
          final updatedMessages = List<Message>.from(messagesNotifier.value)..add(errorMessage);
          messagesNotifier.value = updatedMessages;
        }
      },
      onError: (error) {
        print("Ошибка WebSocket ($chatId): $error");
        final errorMessage = Message(
          id: _uuid.v4(),
          sender: "system",
          content: "Ошибка соединения с чатом. Попробуйте позже.",
          type: MessageType.text,
          timestamp: DateTime.now(),
        );
        final updatedMessages = List<Message>.from(messagesNotifier.value)..add(errorMessage);
        messagesNotifier.value = updatedMessages;
        _channel = null; // Сбрасываем канал
      },
      onDone: () {
        print("WebSocket соединение закрыто для чата $chatId");
        if (currentChatId == chatId) { // Updated usage // Только если это текущее активное соединение
          final systemMessage = Message(
            id: _uuid.v4(),
            sender: "system",
            content: "Соединение с чатом завершено.",
            type: MessageType.text,
            timestamp: DateTime.now(),
          );
          final updatedMessages = List<Message>.from(messagesNotifier.value)..add(systemMessage);
          messagesNotifier.value = updatedMessages;
          currentChatId = null; // Updated usage
          _channel = null;
        }
      },
      cancelOnError: true,
    );
  }

  void sendSignalingMessage(Map<String, dynamic> message) {
    if (_channel == null) return;
    final messageJson = jsonEncode(message);
    print("Отправка сигнального сообщения: $messageJson");
    _channel!.sink.add(messageJson);
  }

  void sendMessage({
    required String sender, // ID текущего пользователя
    required String content,
    MessageType type = MessageType.text,
    String? replyToMessageId,
  }) {
    if (_channel == null || currentChatId == null) { // Updated usage
      print("Невозможно отправить сообщение: нет активного соединения с чатом.");
      // Можно добавить сообщение об ошибке в UI через messagesNotifier
      final errorMessage = Message(
        id: _uuid.v4(),
        sender: "system",
        content: "Не удалось отправить сообщение. Нет соединения.",
        type: MessageType.text,
        timestamp: DateTime.now(),
      );
      final updatedMessages = List<Message>.from(messagesNotifier.value)..add(errorMessage);
      messagesNotifier.value = updatedMessages;
      return;
    }

    final message = Message(
      id: _uuid.v4(), // Клиент генерирует ID для оптимистичного обновления
      sender: sender,
      content: content,
      type: type,
      timestamp: DateTime.now(),
    );

    // Оптимистичное обновление: добавляем сообщение в UI сразу
    final updatedMessages = List<Message>.from(messagesNotifier.value)..add(message);
    messagesNotifier.value = updatedMessages;

    final messageJson = jsonEncode({
      'sender_id': message.sender,
      'content': message.content,
      'type': message.type.toString().split('.').last,
      'reply_to_message_id': replyToMessageId,
    });
    print("Отправка сообщения ($currentChatId): $messageJson"); // Updated usage
    _channel!.sink.add(messageJson);
  }

  void disconnect() {
    print("Отключение от чата: $currentChatId");
    webRTCManager?.dispose(); // <<< Добавить
    webRTCManager = null; // <<< Добавить
    _channelSubscription?.cancel();
    _channel?.sink.close();
    _channelSubscription = null;
    _channel = null;
    currentChatId = null;
  }
}
