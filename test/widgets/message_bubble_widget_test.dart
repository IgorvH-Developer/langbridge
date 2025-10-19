import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:LangBridge/config/app_config.dart';
import 'package:LangBridge/models/message.dart';
import 'package:LangBridge/models/transcription_data.dart';
import 'package:LangBridge/repositories/chat_repository.dart';
import 'package:LangBridge/services/chat_socket_service.dart';
import 'package:LangBridge/widgets/message_bubble.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'fake_video_player.dart';

@GenerateMocks([ChatRepository, ChatSocketService])
import 'message_bubble_widget_test.mocks.dart';

void main() {
  // Моки для репозитория и его внутреннего сервиса
  late MockChatRepository mockChatRepository;
  late MockChatSocketService mockChatSocketService;

  setUpAll(() {
    // Заменяем реальную платформу плеера на фейковую
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
    // Инициализируем конфиг для тестов
    AppConfig.load('dev');
  });

  // Этот блок будет выполняться перед каждым тестом (`testWidgets`)
  setUp(() {
    mockChatRepository = MockChatRepository();
    mockChatSocketService = MockChatSocketService();

    // Связываем моки: когда репозиторий обращается к своему notifier,
    // он должен получить notifier из мока socket service.
    when(mockChatRepository.messagesStream)
        .thenAnswer((_) => mockChatSocketService.messagesNotifier);
  });

  testWidgets('MediaTranscriptionWidget запрашивает и отображает транскрипцию', (WidgetTester tester) async {
    // --- ARRANGE (ПОДГОТОВКА) ---

    // 1. Создаем тестовое сообщение без транскрипции
    final videoContent = jsonEncode({
      "video_url": "/uploads/fake_video.mp4",
      "duration_ms": 15000,
      "transcription": null
    });
    final message = Message.fromJson({
      'id': 'video-msg-1',
      'sender_id': 'other-user',
      'content': videoContent,
      'type': 'video',
      'timestamp': DateTime.now().toIso8601String(),
    });

    // 2. Создаем данные транскрипции, которые "вернет" сервер
    final transcriptionResult = TranscriptionData(
      fullText: "Это распознанный текст.",
      words: [ /* ... слова ... */ ],
    );

    // 3. Настраиваем моки
    // Изначально в стриме сообщений лежит наше одно сообщение
    when(mockChatSocketService.messagesNotifier).thenReturn(ValueNotifier<List<Message>>([message]));

    // Настраиваем поведение метода, который запрашивает транскрипцию.
    // Вместо возврата значения он должен обновить стрим сообщений.
    when(mockChatRepository.fetchAndApplyTranscription('video-msg-1')).thenAnswer((_) async {
      // Имитируем задержку сети
      await Future.delayed(const Duration(milliseconds: 100));
      // Создаем "обновленное" сообщение с транскрипцией
      final updatedMessage = message.withTranscription(transcriptionResult);
      // Имитируем, что сервис получил обновленные данные и пушит их в стрим
      mockChatSocketService.messagesNotifier.value = [updatedMessage];
    });

    // --- ACT (ДЕЙСТВИЕ) ---

    // Рендерим виджет, обернув его в SizedBox, чтобы избежать overflow
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center( // Дополнительно центрируем
          child: SizedBox(
            width: 400, // Задаем конечную ширину
            child: MessageBubble(
              message: message,
              currentUserId: 'current-user',
              chatRepository: mockChatRepository,
            ),
          ),
        ),
      ),
    ));

    // --- ASSERT (ПРОВЕРКА) ---

    // Сразу после первой отрисовки должен быть индикатор загрузки видео
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Ждем завершения всех асинхронных операций (инициализация плеера)
    await tester.pumpAndSettle();

    // Теперь индикатор пропал, появились иконки
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.subtitles), findsOneWidget);
    // Текст транскрипции еще не виден
    expect(find.text("Это распознанный текст."), findsNothing);

    // --- ACT 2 ---

    // Нажимаем на иконку субтитров
    await tester.tap(find.byIcon(Icons.subtitles));
    // Делаем pump(), чтобы запустить обработку тапа и показать SnackBar/индикатор
    await tester.pump();

    // --- ASSERT 2 ---

    // Проверяем, что был вызван правильный метод репозитория
    verify(mockChatRepository.fetchAndApplyTranscription('video-msg-1')).called(1);

    // Проверяем, что появился индикатор загрузки транскрипции
    expect(find.text("Транскрипция загружается..."), findsOneWidget);

    // Ждем завершения "сетевого запроса" и всех перерисовок
    await tester.pumpAndSettle();

    // --- ASSERT 3 (ФИНАЛЬНЫЙ) ---

    // Индикатор загрузки пропал
    expect(find.text("Транскрипция загружается..."), findsNothing);
    // Панель с текстом транскрипции появилась
    expect(find.textContaining('Это распознанный текст', findRichText: true), findsOneWidget);
  });
}
