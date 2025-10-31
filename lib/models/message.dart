import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:LangBridge/config/app_config.dart';
import 'transcription_data.dart';

const String _kMagicNullString = '__MAGIC_NULL__';

enum MessageType { text, image, video, audio }

enum MessageStatus { sent, sending, failed }

class RepliedMessageInfo {
  final String id;
  final String senderId;
  final String content;
  final MessageType type;

  RepliedMessageInfo({
    required this.id,
    required this.senderId,
    required this.content,
    required this.type,
  });

  factory RepliedMessageInfo.fromJson(Map<String, dynamic> json) {
    return RepliedMessageInfo(
      id: json['id'],
      senderId: json['sender_id'],
      content: json['content'] ?? '',
      type: MessageType.values.firstWhere(
              (e) => e.toString().split('.').last == (json['type'] ?? 'text'),
          orElse: () => MessageType.text
      ),
    );
  }
}

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
  final RepliedMessageInfo? repliedTo;
  String? translatedContent;
  bool isTranslating;

  final String? clientMessageId;
  final MessageStatus status;

  Message({
    required this.id,
    required this.sender,
    required this.content,
    required this.type,
    required this.timestamp,
    this.duration,
    this.repliedTo,
    this.translatedContent,
    this.isTranslating = false,
    this.clientMessageId,
    this.status = MessageStatus.sent,
  }) {
    if (type == MessageType.video || type == MessageType.audio) {
      try {
        final data = jsonDecode(content);
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
        } else {
          if (type == MessageType.video) videoUrl = "";
          if (type == MessageType.audio) audioUrl = "";
        }
        if (data['transcription'] != null) {
          transcription = TranscriptionData.fromJson(data['transcription']);
        }
        if (data['duration_ms'] != null) {
          duration = Duration(milliseconds: data['duration_ms']);
        }
      } catch (e) {
        print('Ошибка парсинга JSON для медиа-сообщения: $e');
        if (type == MessageType.video) videoUrl = "";
        if (type == MessageType.audio) audioUrl = "";
      }
    }
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    MessageType type = MessageType.values.firstWhere(
            (e) => e.toString().split('.').last == (json['type'] ?? 'text'),
        orElse: () => MessageType.text);

    dynamic contentJson;
    String contentString;

    if (type == MessageType.text) {
      contentString = json['content'] as String;
      contentJson = contentString;
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

    RepliedMessageInfo? repliedMessageInfo;
    if (json['reply_to_message'] != null) {
      repliedMessageInfo = RepliedMessageInfo.fromJson(json['reply_to_message']);
    }

    return Message(
      id: json['id'] ?? const Uuid().v4(),
      sender: json['sender_id'] ?? json['sender'] ?? 'unknown_sender',
      content: contentString,
      type: type,
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
      duration: messageDuration,
      repliedTo: repliedMessageInfo,
      clientMessageId: json['client_message_id'],
      status: MessageStatus.sent,
    );
  }

  Message withTranscription(TranscriptionData newTranscription) {
    final Map<String, dynamic> contentData = jsonDecode(content);
    contentData['transcription'] = newTranscription.toJson();

    return Message(
      id: id,
      sender: sender,
      content: jsonEncode(contentData),
      type: type,
      timestamp: timestamp,
      duration: duration,
    );
  }

  Message copyWith({
    String? id,
    String? sender,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    Duration? duration,
    RepliedMessageInfo? repliedTo,
    String? translatedContent,
    bool? isTranslating,
    String? clientMessageId,
    MessageStatus? status,
  }) {
    final newTranslatedContent = translatedContent ==_kMagicNullString ? null : (translatedContent ?? this.translatedContent);

    return Message(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      repliedTo: repliedTo ?? this.repliedTo,
      translatedContent: newTranslatedContent,
      isTranslating: isTranslating ?? this.isTranslating,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      status: status ?? this.status,
    );
  }
}
