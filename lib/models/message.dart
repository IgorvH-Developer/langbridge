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
  String? audioUrl;
  TranscriptionData? transcription;
  Duration? duration;

  Message({
    required this.id,
    required this.sender,
    required this.content,
    required this.type,
    required this.timestamp,
    this.duration,
  }) {
    if (type == MessageType.video || type == MessageType.audio) {
      try {
        final data = jsonDecode(content);

        // --- ОБНОВЛЕННАЯ ЛОГИКА ---
        final rawUrl = data['video_url'] ?? data['audio_url'];
        if (rawUrl != null && rawUrl.isNotEmpty) {
          final fullUrl = rawUrl.startsWith('http')
              ? rawUrl
              : "${AppConfig.apiBaseUrl}$rawUrl";

          if (type == MessageType.video) {
            videoUrl = fullUrl;
          } else {
            audioUrl = fullUrl;
          }
        }
        if (data['transcription'] != null) {
          transcription = TranscriptionData.fromJson(data['transcription']);
        }
        // Парсим длительность
        if (data['duration_ms'] != null) {
          duration = Duration(milliseconds: data['duration_ms']);
        }
        // --- КОНЕЦ ОБНОВЛЕННОЙ ЛОГИКИ ---

      } catch (e) {
        print('Ошибка парсинга JSON для медиа-сообщения: $e');
      }
    }
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    MessageType type = MessageType.values.firstWhere(
            (e) => e.toString().split('.').last == (json['type'] ?? 'text'),
        orElse: () => MessageType.text);

    dynamic contentJson;
    String contentString;

    // This is the core of the fix. We treat content differently based on message type.
    if (type == MessageType.text) {
      contentString = json['content'] as String;
      contentJson = contentString; // for duration check, it will be a string, so it's safe.
    } else { // For media messages
      if (json['content'] is String) {
        contentString = json['content'];
        try {
          contentJson = jsonDecode(contentString);
        } catch (e) {
          print("Error decoding media content: $e. Content: $contentString");
          contentJson = {}; // avoid crash on duration check
        }
      } else {
        contentJson = json['content'];
        contentString = jsonEncode(contentJson);
      }
    }
    
    Duration? messageDuration;
    // Only check for duration if we have a map
    if (contentJson is Map && contentJson['duration_ms'] != null) {
      messageDuration = Duration(milliseconds: contentJson['duration_ms']);
    }

    return Message(
      id: json['id'] ?? const Uuid().v4(),
      sender: json['sender_id'] ?? json['sender'] ?? 'unknown_sender',
      content: contentString, // Pass the original or encoded string
      type: type,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      // Pass duration if we found it. Constructor might also find it, which is a bit redundant but not harmful.
      duration: messageDuration,
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
      duration: duration, // <--- НЕ ЗАБЫВАЕМ ПЕРЕДАВАТЬ ДЛИТЕЛЬНОСТЬ ПРИ КОПИРОВАНИИ
    );
  }
}