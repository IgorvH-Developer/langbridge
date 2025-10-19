// test/models/message_model_test.dart

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:LangBridge/config/app_config.dart';
import 'package:LangBridge/models/message.dart';
import 'package:LangBridge/models/transcription_data.dart';

void main() {
  setUpAll(() async {
    await AppConfig.load('dev');
  });

  group('Message.fromJson', () {
    test('корректно парсит текстовое сообщение', () {
      // Arrange: Подготовка данных
      final jsonMap = {
        'id': '123',
        'sender_id': 'user-abc',
        'content': 'Hello, world!',
        'type': 'text',
        'timestamp': '2025-10-06T10:00:00Z',
      };

      // Act: Выполнение действия
      final message = Message.fromJson(jsonMap);

      // Assert: Проверка результата
      expect(message.id, '123');
      expect(message.sender, 'user-abc');
      expect(message.content, 'Hello, world!');
      expect(message.type, MessageType.text);
      expect(message.timestamp, DateTime.parse('2025-10-06T10:00:00Z'));
      expect(message.videoUrl, isNull);
      expect(message.transcription, isNull);
    });

    test('корректно парсит видеосообщение с полной транскрипцией', () {
      // Arrange
      final contentJson = {
        "video_url": "/uploads/video.mp4",
        "duration_ms": 15000,
        "transcription": {
          "full_text": "Hello world",
          "words": [
            {"id": "word-1", "word": "Hello", "start": 0.5, "end": 1.0},
            {"id": "word-2", "word": "world", "start": 1.1, "end": 1.5}
          ]
        }
      };
      final jsonMap = {
        'id': '456',
        'sender_id': 'user-xyz',
        'content': jsonEncode(contentJson),
        'type': 'video',
        'timestamp': '2025-10-06T11:00:00Z',
      };

      // Act
      final message = Message.fromJson(jsonMap);

      // Assert
      expect(message.type, MessageType.video);
      expect(message.videoUrl, startsWith('http'));
      expect(message.videoUrl, endsWith('/uploads/video.mp4'));

      expect(message.duration, const Duration(milliseconds: 15000));
      expect(message.transcription, isA<TranscriptionData>());
      expect(message.transcription!.fullText, "Hello world");
      expect(message.transcription!.words.length, 2);
    });
  });
}
