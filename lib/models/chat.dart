// lib/models/chat.dart
import 'message.dart';

class Chat {
  final String id; // UUID от сервера
  final String title;
  final DateTime? createdAt; // От сервера
  final List<Message>? initialMessages; // Сообщения для инициализации, если загружаются отдельно

  Chat({
    required this.id,
    required this.title,
    this.createdAt,
    this.initialMessages,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      // initialMessages здесь не парсятся, предполагается, что они будут загружены позже
      // или переданы при подключении к WebSocket
    );
  }

  // copyWith может понадобиться для обновления состояния
  Chat copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    List<Message>? initialMessages,
  }) {
    return Chat(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      initialMessages: initialMessages ?? this.initialMessages,
    );
  }
}
