import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:LangBridge/models/message.dart'; // Путь к вашему файлу модели

void main() {
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

    test('корректно парсит видеосообщение с транскрипцией', () {
      // Arrange
      final contentJson = {
        "video_url": "/uploads/video.mp4",
        "transcription": "This is a test."
      };
      final jsonMap = {
        'id': '456',
        'sender_id': 'user-xyz',
        'content': jsonEncode(contentJson), // Контент - это JSON-строка
        'type': 'video',
        'timestamp': '2025-10-06T11:00:00Z',
      };

      // Act
      final message = Message.fromJson(jsonMap);

      // Assert
      expect(message.id, '456');
      expect(message.sender, 'user-xyz');
      expect(message.type, MessageType.video);
      // Проверяем распарсенные поля
      expect(message.videoUrl, '/uploads/video.mp4');
      expect(message.transcription, 'This is a test.');
    });

    test('корректно парсит видеосообщение без транскрипции', () {
      // Arrange
      final contentJson = {"video_url": "/uploads/video.mp4", "transcription": null};
      final jsonMap = {
        'id': '789',
        'sender_id': 'user-123',
        'content': jsonEncode(contentJson),
        'type': 'video',
        'timestamp': '2025-10-06T12:00:00Z',
      };

      // Act
      final message = Message.fromJson(jsonMap);

      // Assert
      expect(message.type, MessageType.video);
      expect(message.videoUrl, '/uploads/video.mp4');
      expect(message.transcription, isNull); // Транскрипции нет
    });
  });
}

