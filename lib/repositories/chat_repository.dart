import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:LangBridge/services/chat_socket_service.dart';
import 'package:LangBridge/models/chat.dart';
import 'package:LangBridge/models/message.dart';
import 'package:LangBridge/models/transcription_data.dart';
import 'package:LangBridge/services/api_service.dart';
import 'package:LangBridge/models/user_profile.dart';

class ChatRepository {
  final _uuid = const Uuid();

  final ChatSocketService chatSocketService;
  final ApiService _apiService;

  ChatRepository({
    ChatSocketService? socketService,
    ApiService? apiService,
  })  : chatSocketService = socketService ?? ChatSocketService(),
        _apiService = apiService ?? ApiService();

  final ValueNotifier<List<Chat>> _chatsNotifier = ValueNotifier<List<Chat>>([]);
  ValueNotifier<List<Chat>> get chatsStream => _chatsNotifier;

  Future<void> fetchChats() async {
    final chatDataList = await _apiService.getAllChats();
    if (chatDataList != null) {
      final chats = chatDataList.map((data) => Chat.fromJson(data)).toList();
      _chatsNotifier.value = chats;
    } else {
      _chatsNotifier.value = [];
    }
  }

  Future<UserProfile?> getUserProfile(String userId) async {
    return await _apiService.getUserProfile(userId);
  }

  Future<Chat?> getOrCreatePrivateChat(String partnerId) async {
    final chatData = await _apiService.getOrCreatePrivateChat(partnerId);
    if (chatData != null) {
      return Chat.fromJson(chatData);
    }
    return null;
  }

  Future<Chat?> createNewChat(String title) async {
    print("creating new chat $title");
    final chatData = await _apiService.getOrCreatePrivateChat(title);
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

  Future<void> markChatAsRead(String chatId) async {
    // Вызываем API
    await _apiService.markChatAsRead(chatId);

    // Оптимистичное обновление: находим чат в локальном списке и обнуляем счетчик
    final currentChats = List<Chat>.from(_chatsNotifier.value);
    final chatIndex = currentChats.indexWhere((c) => c.id == chatId);
    if (chatIndex != -1) {
      final oldChat = currentChats[chatIndex];
      // Создаем новый экземпляр Chat с обнуленным счетчиком
      currentChats[chatIndex] = Chat(
        id: oldChat.id,
        title: oldChat.title,
        createdAt: oldChat.createdAt,
        participants: oldChat.participants,
        lastMessage: oldChat.lastMessage,
        unreadCount: 0, // <-- Обнуляем
      );
      _chatsNotifier.value = currentChats; // Уведомляем UI
    }
  }

  Future<void> connectToChat(Chat chat) async {

    // 1. Немедленно подключаем сокет, чтобы не пропустить сообщения,
    //    которые могут прийти во время загрузки истории.
    //    Передаем пустой список, так как история будет загружена ниже.
    chatSocketService.connect(chat.id, []);

    // 2. Запрашиваем полную историю сообщений с сервера.
    final messagesData = await _apiService.getChatMessages(chat.id);

    if (messagesData != null) {
      try {
        final newMessages = messagesData.map((data) => Message.fromJson(data)).toList();
        print("Successfully fetched and parsed ${newMessages.length} messages for chat ${chat.id}");

        // Обновляем главный ValueNotifier в ChatSocketService.
        chatSocketService.messagesNotifier.value = newMessages;

      } catch (e) {
        print("Error parsing messages for chat ${chat.id}: $e");
        // В случае ошибки оставляем список пустым.
        chatSocketService.messagesNotifier.value = [];
      }
    } else {
      print("Failed to fetch messages for chat ${chat.id}, setting message list to empty.");
      chatSocketService.messagesNotifier.value = [];
    }
  }

  void sendChatMessage({
    required String sender,
    required String content,
    MessageType type = MessageType.text,
    String? replyToMessageId,
  }) {
    chatSocketService.sendMessage(
      sender: sender,
      content: content,
      type: type,
      replyToMessageId: replyToMessageId,
    );
  }

  void disconnectFromChat() {
    chatSocketService.disconnect();
  }

  Future<void> sendVideoMessage({
    // Меняем тип
    required List<Map<String, dynamic>> segments,
    required String chatId,
    required String senderId,
    String? replyToMessageId,
  }) async {
    await _apiService.uploadVideo(
      segments: segments,
      chatId: chatId,
      senderId: senderId,
      replyToMessageId: replyToMessageId,
    );
  }

  Future<void> sendAudioMessage({
    required String filePath,
    required String chatId,
    required String senderId,
    String? replyToMessageId,
  }) async {
    await _apiService.uploadAudio(
      filePath: filePath,
      chatId: chatId,
      senderId: senderId,
      replyToMessageId: replyToMessageId,
    );
  }

  Future<TranscriptionData?> transcribeMessage(String messageId) async {
    return await _apiService.getTranscriptionForMessage(messageId);
  }

  Future<void> fetchAndApplyTranscription(String messageId) async {
    final transcription = await _apiService.getTranscriptionForMessage(messageId);
    if (transcription != null) {
      final currentMessages = List<Message>.from(chatSocketService.messagesNotifier.value);
      final messageIndex = currentMessages.indexWhere((m) => m.id == messageId);

      if (messageIndex != -1) {
        final originalMessage = currentMessages[messageIndex];
        currentMessages[messageIndex] = originalMessage.withTranscription(transcription);
        chatSocketService.messagesNotifier.value = currentMessages;
      }
    }
  }

  Future<void> saveTranscription(String messageId, TranscriptionData data) async {
    final success = await _apiService.updateTranscriptionForMessage(messageId, data);
    if (success) {
      // Если успешно сохранено на сервере, обновляем и локально
      final currentMessages = List<Message>.from(chatSocketService.messagesNotifier.value);
      final messageIndex = currentMessages.indexWhere((m) => m.id == messageId);

      if (messageIndex != -1) {
        final originalMessage = currentMessages[messageIndex];
        currentMessages[messageIndex] = originalMessage.withTranscription(data);
        chatSocketService.messagesNotifier.value = currentMessages;
      }
    }
  }

  ValueNotifier<List<Message>> get messagesStream => chatSocketService.messagesNotifier;
}
