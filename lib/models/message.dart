import 'dart:convert';

import 'package:uuid/uuid.dart';

enum MessageType { text, image, video, audio }

class Message {
  final String id;
  final String sender; // На сервере это может быть sender_id
  final String content; // Для видео это будет JSON-строка
  final MessageType type;
  final DateTime timestamp;

  // Новые поля для удобного доступа к данным видео
  String? videoUrl;
  String? transcription;

  Message({
    required this.id,
    required this.sender,
    required this.content,
    required this.type,
    required this.timestamp,
  })
  {
    // Парсим content, если это видео
    if (type == MessageType.video) {
      try {
        final data = jsonDecode(content);
        videoUrl = data['video_url'];
        transcription = data['transcription'];
      } catch (e) {
        // Оставляем поля null, если парсинг не удался
      }
    }
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    MessageType type = MessageType.values.firstWhere(
            (e) => e.toString().split('.').last == (json['type'] ?? 'text'),
        orElse: () => MessageType.text);

    return Message(
      id: json['id'] ?? const Uuid().v4(),
      sender: json['sender_id'] ?? json['sender'] ?? 'unknown_sender',
      content: json['content'] ?? '',
      type: type,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }
}