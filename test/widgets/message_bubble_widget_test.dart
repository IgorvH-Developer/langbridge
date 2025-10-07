import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:LangBridge/models/message.dart';
import 'package:LangBridge/repositories/chat_repository.dart';
import 'package:LangBridge/widgets/message_bubble.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'fake_video_player.dart'; // Фейковый плеер для тестов

// Генерируем мок-класс для ChatRepository
@GenerateMocks([ChatRepository])
import 'message_bubble_widget_test.mocks.dart';

void main() {
  // Инициализируем фейковый плеер
  setUpAll(() {
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
  });

  // Создаем мок-объект репозитория
  final mockChatRepository = MockChatRepository();

  testWidgets('MessageBubble для видео, при нажатии на "Показать текст" запрашивает транскрипцию', (WidgetTester tester) async {
    // Arrange: Подготовка данных и моков
    final videoContent = jsonEncode({
      "video_url": "/uploads/fake_video.mp4",
      "transcription": null // Транскрипции изначально нет
    });
    final message = Message.fromJson({
      'id': 'video-msg-1',
      'sender_id': 'other-user',
      'content': videoContent,
      'type': 'video',
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Настраиваем мок: когда будет вызван transcribeMessage с этим ID,
    // вернуть "Распознанный текст" через 100 мс.
    when(mockChatRepository.transcribeMessage('video-msg-1'))
        .thenAnswer((_) async {
      await Future.delayed(const Duration(milliseconds: 100));
      return "Распознанный текст";
    });

    // Act: Рендерим виджет
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MessageBubble(
          message: message,
          currentUserId: 'current-user',
          chatRepository: mockChatRepository,
        ),
      ),
    ));

    // Assert: Сначала видео грузится
    expect(find.text('Загрузка видео...'), findsOneWidget);

    await tester.pumpAndSettle(); // Ждем завершения инициализации видео

    // Теперь видео загружено, и есть кнопка "Показать текст"
    expect(find.text('Загрузка видео...'), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.text('Показать текст'), findsOneWidget);

    // Act: Нажимаем на кнопку "Показать текст"
    await tester.tap(find.text('Показать текст'));
    await tester.pump(); // Начинаем перерисовку

    // Assert: Появился индикатор "Генерация..."
    expect(find.text('Генерация...'), findsOneWidget);
    // Проверяем, что метод репозитория был вызван ровно один раз
    verify(mockChatRepository.transcribeMessage('video-msg-1')).called(1);

    // Ждем завершения Future из мока и перерисовки
    await tester.pump(const Duration(milliseconds: 150));

    // Assert: Появился распознанный текст
    expect(find.text('Генерация...'), findsNothing);
    expect(find.text('Скрыть текст'), findsOneWidget);
//    expect(find.text('Распознанный текст'), findsOneWidget); // Эта строка может не сработать, если текст в другом виджете. Лучше искать по ключу или типу.
    expect(find.byWidgetPredicate((widget) => widget is Text && widget.data == 'Распознанный текст'), findsOneWidget);
  });
}

