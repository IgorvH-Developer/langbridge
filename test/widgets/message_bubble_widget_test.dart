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
import 'message_bubble_widget_test.mocks.dart';

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

  testWidgets('MediaTranscriptionWidget запрашивает и отображает транскрипцию', (WidgetTester tester) async {
    // --- ARRANGE ---
    final initialMessage = Message.fromJson({
      'id': 'audio-msg-1',
      'sender_id': 'other-user',
      'content': jsonEncode({
        "audio_url": "/uploads/audio.m4a",
        "duration_ms": 10000
      }),
      'type': 'audio',
      'timestamp': DateTime.now()
          .subtract(const Duration(minutes: 1))
          .toIso8601String()
    });
    messagesNotifier.value = [initialMessage];

    final transcriptionResult = TranscriptionData(
      fullText: "Это распознанный текст.",
      words: [
        TranscriptionWord(id: uuid.v4(), word: "Это", start: 0.1, end: 0.5),
        TranscriptionWord(id: uuid.v4(), word: "распознанный", start: 0.6, end: 0.8),
        TranscriptionWord(id: uuid.v4(), word: "текст.", start: 0.9, end: 1.5),
      ],
    );

    when(mockApiService.getTranscriptionForMessage('audio-msg-1'))
        .thenAnswer((_) => Future.delayed(Duration.zero, () => transcriptionResult));

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
                  currentUserId: 'current-user',
                  chatRepository: realChatRepository,
                );
              },
            );
          },
        ),
      ),
    ));

    // --- ASSERT 1 ---
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('audio-msg-1')), findsOneWidget);
    expect(find.text("Это"), findsNothing);
    expect(find.text("распознанный"), findsNothing);

    // --- ACT 2 ---
    await tester.tap(find.byIcon(Icons.subtitles));
    await tester.pumpAndSettle(); // Ждем завершения setState и мока

    // --- ASSERT 2 ---
    verify(mockApiService.getTranscriptionForMessage('audio-msg-1')).called(1);
    expect(find.text("Транскрипция загружается..."), findsNothing);

    expect(find.text("Это"), findsOneWidget);
    expect(find.text("распознанный"), findsOneWidget);
    expect(find.text("текст."), findsOneWidget);
  });
}
