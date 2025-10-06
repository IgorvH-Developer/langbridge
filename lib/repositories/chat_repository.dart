import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart'; // Если все еще нужен для локальных ID
import 'package:LangBridge/services/chat_socket_service.dart';
import 'package:LangBridge/models/chat.dart'; // Убедитесь, что модель Chat имеет конструктор fromJson
import 'package:LangBridge/models/message.dart';
import 'package:LangBridge/services/api_service.dart'; // Импортируем ApiService

// Константа для фиксированного системного чата, если он вам все еще нужен
// Если app_chat тоже должен создаваться через API, то эта константа может быть не нужна
// или использоваться только для его первоначального отображения/поиска.
const String appChatFixedId = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a10";

class ChatRepository {
  final _uuid = const Uuid();
  final ChatSocketService chatSocketService = ChatSocketService();
  final ApiService _apiService = ApiService(); // Экземпляр ApiService

  // Локальный список чатов, который будет обновляться из API
  // Используем ValueNotifier для обновления UI списка чатов
  final ValueNotifier<List<Chat>> _chatsNotifier = ValueNotifier<List<Chat>>([]);
  ValueNotifier<List<Chat>> get chatsStream => _chatsNotifier;

  // --- Методы для работы с чатами через API ---

  Future<void> fetchChats() async {
    final chatDataList = await _apiService.getAllChats();
    if (chatDataList != null) {
      final chats = chatDataList.map((data) => Chat.fromJson(data)).toList();
      _chatsNotifier.value = chats;
    } else {
      // Обработка ошибки загрузки чатов
      _chatsNotifier.value = []; // Или показать сообщение об ошибке
    }
  }

  Future<Chat?> createNewChat(String title) async {
    print("creating new chat $title");
    final chatData = await _apiService.createChat(title);
    if (chatData != null) {
      final newChat = Chat.fromJson(chatData);
      // Опционально: обновить список чатов
      // await fetchChats(); // Или добавить новый чат в _chatsNotifier.value локально
      final currentChats = List<Chat>.from(_chatsNotifier.value);
      currentChats.add(newChat);
      _chatsNotifier.value = currentChats;
      return newChat;
    }
    print("failed to create new chat $title");
    return null;
  }

  // --- Методы для взаимодействия с ChatSocketService ---
  Future<void> connectToChat(Chat chat) async {
    // Теперь chat.id должен быть валидным UUID, полученным от API
    List<Message> initialMessages = chat.initialMessages ?? [];

    // Запрашиваем историю сообщений с сервера
    final messagesData = await _apiService.getChatMessages(chat.id);
    if (messagesData != null) {
      try {
        initialMessages = messagesData.map((data) => Message.fromJson(data)).toList();
        print("Successfully fetched and parsed ${initialMessages.length} messages for chat ${chat.id}");
      } catch (e) {
        print("Error parsing messages for chat ${chat.id}: $e");
        // Оставляем initialMessages пустым или с тем, что было в chat.initialMessages
      }
    } else {
      print("Failed to fetch messages for chat ${chat.id}, using local initialMessages (if any).");
    }

    chatSocketService.connect(chat.id, initialMessages);
  }

  void sendChatMessage({
    required String sender,
    required String content,
    MessageType type = MessageType.text,
  }) {
    chatSocketService.sendMessage(sender: sender, content: content, type: type);
  }

  void disconnectFromChat() {
    chatSocketService.disconnect();
  }

  // Новый метод для отправки видео
  Future<void> sendVideoMessage({
    required String filePath,
    required String chatId,
    required String senderId,
  }) async {
    // Просто вызываем метод API, остальное сделает бэкенд
    // (отправит WebSocket сообщение после обработки)
    await _apiService.uploadVideo(
      filePath: filePath,
      chatId: chatId,
      senderId: senderId,
    );
  }

  ValueNotifier<List<Message>> get messagesStream => chatSocketService.messagesNotifier;

// --- Локальные сообщения (если все еще нужны) ---
// ... (addLocalMessage, createMessage)
}
