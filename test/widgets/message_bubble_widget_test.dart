import 'dart:convert';
import 'package:LangBridge/models/user_profile.dart';
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
                  nicknamesCache: const {},
                  getNickname: (userId) async => userId,
                  onReply: (_) {},
                  onTapRepliedMessage: (_) {},
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

  testWidgets('Отображает имя собеседника в заголовке и над его сообщением', (WidgetTester tester) async {
    // --- ARRANGE (Подготовка) ---

    // 1. Определяем ID и имена участников
    const currentUserId = 'user-1';
    const partnerId = 'user-2';
    const partnerNickname = 'Собеседник John';

    // 2. Создаем мок-сообщение от собеседника
    final partnerMessage = Message.fromJson({
      'id': 'msg-partner-1',
      'sender_id': partnerId, // Отправлено собеседником
      'content': 'Привет от собеседника!',
      'type': 'text',
      'timestamp': DateTime.now().toIso8601String(),
    });

    // 3. Заполняем notifier этим сообщением
    messagesNotifier.value = [partnerMessage];

    // 4. Настраиваем мок API: при запросе профиля собеседника, возвращаем его данные
    when(mockApiService.getUserProfile(partnerId)).thenAnswer(
          (_) async => UserProfile(id: partnerId, username: partnerNickname, languages: []),
    );
    // Для нашего пользователя возвращаем просто ID
    when(mockApiService.getUserProfile(currentUserId)).thenAnswer(
          (_) async => UserProfile(id: currentUserId, username: 'Me', languages: []),
    );


    // --- ACT (Действие) ---

    // 1. Рендерим родительский виджет, который содержит и заголовок, и список сообщений.
    //    Для простоты симулируем Scaffold с AppBar и телом, как в ChatScreen.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text(partnerNickname),
        ),
        body: ListView.builder(
          itemCount: messagesNotifier.value.length,
          itemBuilder: (context, index) {
            final msg = messagesNotifier.value[index];
            return MessageBubble(
              message: msg,
              currentUserId: currentUserId,
              chatRepository: realChatRepository,
              nicknamesCache: const {partnerId: partnerNickname},
              getNickname: (userId) => realChatRepository.getUserProfile(userId).then((p) => p?.username ?? userId),
              onReply: (_) {},
              onTapRepliedMessage: (_) {},
            );
          },
        ),
      ),
    ));

    // 2. Ждем завершения всех асинхронных операций (FutureBuilder внутри MessageBubble)
    await tester.pumpAndSettle();


    // --- ASSERT (Проверка) ---

    // 1. Проверяем заголовок экрана (AppBar)
    expect(find.descendant(of: find.byType(AppBar), matching: find.text(partnerNickname)), findsOneWidget,
        reason: "Заголовок AppBar должен содержать имя собеседника");

    // 2. Проверяем, что над сообщением собеседника отображается его имя.
    final messageBubbleFinder = find.byType(MessageBubble);
    expect(messageBubbleFinder, findsOneWidget);

    // Внутри MessageBubble ищем виджет Text с никнеймом собеседника
    final nicknameInBubbleFinder = find.descendant(
      of: messageBubbleFinder,
      matching: find.text(partnerNickname),
    );

    // В нашем `MessageBubble` имя собеседника встречается ДВАЖДЫ:
    // 1. В AppBar (который мы тоже отрендерили).
    // 2. Над самим сообщением.
    // Поэтому мы ищем как минимум один такой виджет.
    expect(nicknameInBubbleFinder, findsAtLeastNWidgets(1),
        reason: "Имя собеседника должно отображаться над его сообщением");

    // 3. Убедимся, что и само сообщение на месте
    expect(find.text('Привет от собеседника!'), findsOneWidget);
  });

  group('Функционал ответов на сообщения', () {
    // Подготовка базовых сообщений для тестов
    final originalMessage = Message.fromJson({
      'id': 'original-msg-1',
      'sender_id': 'partner-id',
      'content': 'Это оригинальное сообщение для ответа.',
      'type': 'text',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String(),
    });

    final audioMessage = Message.fromJson({
      'id': 'original-audio-msg',
      'sender_id': 'partner-id',
      'content': jsonEncode({"audio_url": "/fake.m4a", "duration_ms": 3000}),
      'type': 'audio',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 1)).toIso8601String(),
    });

    testWidgets('Свайп по сообщению собеседника вызывает колбэк onReply', (WidgetTester tester) async {
      // ARRANGE
      messagesNotifier.value = [originalMessage];
      Message? repliedMessage;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: 1,
            itemBuilder: (context, index) {
              return MessageBubble(
                message: originalMessage,
                currentUserId: 'current-user-id', // Мы не собеседник
                chatRepository: realChatRepository,
                nicknamesCache: const {},
                getNickname: (id) async => id,
                onReply: (message) {
                  repliedMessage = message; // Сохраняем сообщение, на которое отвечаем
                },
                onTapRepliedMessage: (_) {},
              );
            },
          ),
        ),
      ));

      // ACT: Симулируем свайп слева направо (endToStart)
      await tester.drag(find.byType(MessageBubble), const Offset(-200.0, 0.0));
      await tester.pumpAndSettle();

      // ASSERT: Проверяем, что колбэк был вызван с правильным сообщением
      expect(repliedMessage, isNotNull);
      expect(repliedMessage!.id, originalMessage.id);
    });

    testWidgets('Отображает рамку ответа, если сообщение является ответом', (WidgetTester tester) async {
      // ARRANGE: Создаем сообщение, которое является ответом на `originalMessage`
      final replyMessage = Message.fromJson({
        'id': 'reply-msg-1',
        'sender_id': 'current-user-id',
        'content': 'Это мой ответ.',
        'type': 'text',
        'timestamp': DateTime.now().toIso8601String(),
        'reply_to_message': { // Вложенная информация об ответе
          'id': 'original-msg-1',
          'sender_id': 'partner-id',
          'content': 'Это оригинальное сообщение для ответа.',
          'type': 'text',
        }
      });
      messagesNotifier.value = [replyMessage];

      // ACT
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: 1,
            itemBuilder: (context, index) {
              return MessageBubble(
                message: replyMessage,
                currentUserId: 'current-user-id',
                chatRepository: realChatRepository,
                nicknamesCache: const {'partner-id': 'John'},
                getNickname: (id) async => 'John',
                onReply: (_) {},
                onTapRepliedMessage: (_) {},
              );
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // ASSERT
      // 1. Ищем имя автора оригинального сообщения
      expect(find.text('John'), findsOneWidget);
      // 2. Ищем текст оригинального сообщения
      expect(find.text('Это оригинальное сообщение для ответа.'), findsOneWidget);
      // 3. Ищем текст самого ответа
      expect(find.text('Это мой ответ.'), findsOneWidget);
    });

    testWidgets('Отображает заглушку "Голосовое сообщение" для ответа на аудио', (WidgetTester tester) async {
      // ARRANGE
      final replyToAudioMessage = Message.fromJson({
        'id': 'reply-to-audio-1',
        'sender_id': 'current-user-id',
        'content': 'Комментирую аудио',
        'type': 'text',
        'timestamp': DateTime.now().toIso8601String(),
        'reply_to_message': {
          'id': 'original-audio-msg',
          'sender_id': 'partner-id',
          'content': '', // У аудио нет текстового контента
          'type': 'audio',
        }
      });
      messagesNotifier.value = [replyToAudioMessage];

      // ACT
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: 1,
            itemBuilder: (context, index) {
              return MessageBubble(
                message: replyToAudioMessage,
                currentUserId: 'current-user-id',
                chatRepository: realChatRepository,
                nicknamesCache: const {'partner-id': 'Mike'},
                getNickname: (id) async => 'Mike',
                onReply: (_) {},
                onTapRepliedMessage: (_) {},
              );
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // ASSERT
      expect(find.text('Mike'), findsOneWidget);
      // Проверяем наличие заглушки вместо контента
      expect(find.text('Голосовое сообщение'), findsOneWidget);
      expect(find.text('Комментирую аудио'), findsOneWidget);
    });
  });
}
