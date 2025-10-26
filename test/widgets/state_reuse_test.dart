import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:LangBridge/config/app_config.dart';
import 'package:LangBridge/models/message.dart';
import 'package:LangBridge/models/transcription_data.dart';
import 'package:LangBridge/repositories/chat_repository.dart';
import 'package:LangBridge/services/api_service.dart';
import 'package:LangBridge/services/chat_socket_service.dart';
import 'package:LangBridge/widgets/message_bubble.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

@GenerateMocks([ChatSocketService, ApiService])
import 'state_reuse_test.mocks.dart';

void main() {
  late ChatRepository realChatRepository;
  late MockChatSocketService mockChatSocketService;
  late MockApiService mockApiService;
  late ValueNotifier<List<Message>> messagesNotifier;
  const uuid = Uuid();

  setUpAll(() {
    AppConfig.load('dev');
  });

  tearDownAll(() {});

  setUp(() {
    mockChatSocketService = MockChatSocketService();
    mockApiService = MockApiService();
    messagesNotifier = ValueNotifier<List<Message>>([]);

    realChatRepository = ChatRepository(
      socketService: mockChatSocketService,
      apiService: mockApiService,
    );

    when(mockChatSocketService.messagesNotifier).thenReturn(messagesNotifier);
  });

  tearDown(() {
    messagesNotifier.dispose();
  });

  testWidgets(
      'При добавлении нового аудиосообщения виджет корректно сбрасывает и отображает новое состояние',
          (WidgetTester tester) async {
        // --- ARRANGE ---
        final messageA = Message.fromJson({
          'id': 'msg-A',
          'sender_id': 'user-1',
          'content': jsonEncode({
            "audio_url": "/uploads/audio_A.m4a",
            "duration_ms": 10000
          }),
          'type': 'audio',
          'timestamp': DateTime.now()
              .subtract(const Duration(minutes: 1))
              .toIso8601String()
        });
        final messageB = Message.fromJson({
          'id': 'msg-B',
          'sender_id': 'user-1',
          'content': jsonEncode({
            "audio_url": "/uploads/audio_B.m4a",
            "duration_ms": 5000
          }),
          'type': 'audio',
          'timestamp': DateTime.now().toIso8601String()
        });

        // Создаем транскрипцию с заполненным списком слов
        final transcriptionB = TranscriptionData(
          fullText: "Текст для НОВОГО сообщения.",
          words: [
            TranscriptionWord(id: uuid.v4(), word: "Текст", start: 0.1, end: 0.5),
            TranscriptionWord(id: uuid.v4(), word: "для", start: 0.6, end: 0.8),
            TranscriptionWord(id: uuid.v4(), word: "НОВОГО", start: 0.9, end: 1.5),
            TranscriptionWord(id: uuid.v4(), word: "сообщения.", start: 1.6, end: 2.5),
          ],
        );

        messagesNotifier.value = [messageA];

        // Мокируем ТОЛЬКО зависимость (ApiService).
        when(mockApiService.getTranscriptionForMessage('msg-B'))
            .thenAnswer((_) => Future.delayed(Duration.zero, () => transcriptionB));

        // --- ACT 1: Отображаем начальное состояние ---
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<List<Message>>(
              valueListenable: realChatRepository.messagesStream,
              builder: (context, messages, child) {
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[messages.length - 1 - index];
                    return MessageBubble(
                      key: ValueKey(msg.id),
                      message: msg,
                      currentUserId: 'user-1',
                      chatRepository: realChatRepository,
                      nicknamesCache: const {},
                      getNickname: (userId) async => userId,
                    );
                  },
                );
              },
            ),
          ),
        ));

        // --- ASSERT 1 & ACT 2 & ASSERT 2 ---
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('msg-A')), findsOneWidget);
        expect(find.byKey(const ValueKey('msg-B')), findsNothing);

        messagesNotifier.value = [messageA, messageB];
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('msg-A')), findsOneWidget);
        expect(find.byKey(const ValueKey('msg-B')), findsOneWidget);

        // --- ACT 3: Взаимодействуем с НОВЫМ сообщением (B) ---
        final subtitleIconForMsgB = find.descendant(
          of: find.byKey(const ValueKey('msg-B')),
          matching: find.byIcon(Icons.subtitles),
        );
        await tester.tap(subtitleIconForMsgB);

        // --- ASSERT 3: Финальная проверка ---
        await tester.pump();

        // Проверяем, что был вызван реальный метод, который обратился к моку API
        verify(mockApiService.getTranscriptionForMessage('msg-B')).called(1);

        expect(find.text("Транскрипция загружается..."), findsOneWidget);

        // Ждем завершения ВСЕХ асинхронных операций
        await tester.pumpAndSettle();

        // Проверяем финальное состояние
        expect(find.text("Транскрипция загружается..."), findsNothing);

        expect(find.text("Текст"), findsOneWidget);
        expect(find.text("для"), findsOneWidget);
        expect(find.text("НОВОГО"), findsOneWidget);
        expect(find.text("сообщения."), findsOneWidget);

        expect(find.textContaining("Текст для СТАРОГО сообщения", findRichText: true), findsNothing);
          }
  );
}
