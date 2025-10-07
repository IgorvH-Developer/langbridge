import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'transcription_data.dart';

enum MessageType { text, image, video, audio }

class Message {
  final String id;
  final String sender;
  final String content;
  final MessageType type;
  final DateTime timestamp;

  String? videoUrl;
  // ЗАМЕНЯЕМ String? transcription на TranscriptionData? transcription
  TranscriptionData? transcription;

  Message({
    required this.id,
    required this.sender,
    required this.content,
    required this.type,
    required this.timestamp,
  }) {
    if (type == MessageType.video) {
      try {
        final data = jsonDecode(content);
        videoUrl = data['video_url'];
        // Парсим сложный объект транскрипции
        if (data['transcription'] != null) {
          transcription = TranscriptionData.fromJson(data['transcription']);
        }
      } catch (e) {
        print('Ошибка парсинга JSON: $e');
        // Ошибка парсинга
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
      content: json['content'] is String ? json['content'] : jsonEncode(json['content']), // Контент может приходить как JSON
      type: type,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  // Метод для обновления сообщения новой транскрипцией
  Message withTranscription(TranscriptionData newTranscription) {
    final Map<String, dynamic> contentData = jsonDecode(content);
    contentData['transcription'] = newTranscription.toJson();

    return Message(
      id: id,
      sender: sender,
      content: jsonEncode(contentData),
      type: type,
      timestamp: timestamp,
    );
  }
}
