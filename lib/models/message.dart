import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:LangBridge/config/app_config.dart';
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
        final rawVideoUrl = data['video_url'];
        if (rawVideoUrl != null && rawVideoUrl.isNotEmpty) {
          // --- ДОБАВЬТЕ ЭТУ ЛОГИКУ ---
          if (rawVideoUrl.startsWith('http')) {
            videoUrl = rawVideoUrl;
          } else {
            videoUrl = "${AppConfig.apiBaseUrl}$rawVideoUrl";
          }
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

  factory Message.fromLastMessageJson(Map<String, dynamic> json) {
    // Этот конструктор очень упрощен, так как нам нужны только content и timestamp
    return Message(
      id: '', // ID не важен для отображения в списке
      sender: '', // Sender не важен
      content: json['content'] ?? '',
      type: MessageType.values.firstWhere(
              (e) => e.toString().split('.').last == (json['type'] ?? 'text'),
          orElse: () => MessageType.text),
      timestamp: DateTime.parse(json['timestamp']),
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
