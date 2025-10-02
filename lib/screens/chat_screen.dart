import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:uuid/uuid.dart';

import '../models/chat.dart';
import '../models/message.dart';
import '../repositories/chat_repository.dart';

String currentUserId = const Uuid().v4();

class ChatScreen extends StatefulWidget {
  final Chat chat; // Передаем весь объект Chat
  final ChatRepository chatRepository;

  const ChatScreen({
    super.key,
    required this.chat,
    required this.chatRepository,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // _chat больше не нужен как отдельное состояние, так как сообщения будут приходить из notifier
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker(); // Оставляем для выбора видео

  // ID текущего пользователя (замените на реальный способ получения)
  final String _currentUserId = currentUserId; // Пример, получите это из аутентификации

  @override
  void initState() {
    super.initState();
    print('connecting to chat: ${widget.chat.id}');
    // Подключаемся к чату при инициализации экрана
    widget.chatRepository.connectToChat(widget.chat);
  }

  void _sendMessage() {
    if (_textController.text.trim().isEmpty) return;

    widget.chatRepository.sendChatMessage(
      sender: _currentUserId, // Передаем ID текущего пользователя
      content: _textController.text.trim(),
      type: MessageType.text,
    );
    _textController.clear();
  }Future<void> _sendVideo() async {
    final pickedFile = await _picker.pickVideo(source: ImageSource.camera);
    if (pickedFile == null) return;

    // В реальном приложении:
    // 1. Загрузить видео на сервер (например, через HTTP POST запрос).
    // 2. Получить URL или идентификатор загруженного видео от сервера.
    // 3. Отправить сообщение через WebSocket с типом 'video' и этим URL/ID.

    // Пока что для примера отправляем путь к файлу, но это не будет работать
    // для другого пользователя, так как у него не будет доступа к этому файлу.
    // Это нужно будет изменить для реальной работы.
    widget.chatRepository.sendChatMessage(
      sender: _currentUserId,
      content: pickedFile.path, // ЗАМЕНИТЬ НА URL после загрузки на сервер
      type: MessageType.video,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.chat.title)), // Используем title из переданного chat
      body: Column(
        children: [
          Expanded(
            // Слушаем изменения в ValueNotifier из ChatRepository
            child: ValueListenableBuilder<List<Message>>(
              valueListenable: widget.chatRepository.messagesStream,
              builder: (context, messages, child) {
                // Если список сообщений пуст, можно показать заглушку
                if (messages.isEmpty && widget.chat.id != appChatFixedId && !widget.chatRepository.chatSocketService.isConnected) {
                  return const Center(child: Text("Подключение к чату..."));
                } else if (messages.isEmpty) {
                  return const Center(child: Text("Нет сообщений. Начните диалог!"));
                }
                return ListView.builder(
                  reverse: false, // Или true, если хотите, чтобы ввод был снизу, а сообщения добавлялись сверху
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    // Передаем currentUserId в _MessageBubble, чтобы он мог определить, кто отправитель
                    return _MessageBubble(message: msg, currentUserId: _currentUserId);
                  },
                );
              },
            ),
          ),
          Padding( // Обернул Row в Padding для отступов
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.videocam),
                  onPressed: _sendVideo,
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: "Введите сообщение...",
                      border: OutlineInputBorder(), // Добавил границу для наглядности
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Отключаемся от чата при закрытии экрана
    widget.chatRepository.disconnectFromChat();
    _textController.dispose();
    super.dispose();
  }
}

// Модифицируем _MessageBubble для приема currentUserId
class _MessageBubble extends StatefulWidget {
  final Message message;
  final String currentUserId; // ID текущего пользователя

  const _MessageBubble({required this.message, required this.currentUserId});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.message.type == MessageType.video) {
      // Важно: если content это URL, используйте VideoPlayerController.networkUrl
      // Если это путь к файлу (как в примере _sendVideo), то это будет работать только локально.
      // Для реального приложения здесь должен быть URL видео на сервере.
      Uri? videoUri;
      if (widget.message.content.startsWith('http')) {
        videoUri = Uri.tryParse(widget.message.content);
      }

      if (videoUri != null) {
        _videoController = VideoPlayerController.networkUrl(videoUri)
          ..initialize().then((_) {
            if (mounted) setState(() {});
          }).catchError((error) {
            print("Ошибка инициализации видеоплеера: $error");
            if (mounted) setState(() {}); // Чтобы показать ошибку или заглушку
          });
      } else if (widget.message.content.contains('/')) { // Попытка как локальный файл (для тестов)
        _videoController = VideoPlayerController.file(File(widget.message.content))
          ..initialize().then((_) {
            if (mounted) setState(() {});
          }).catchError((error) {
            print("Ошибка инициализации видеоплеера (файл): $error");
            if (mounted) setState(() {});
          });
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.sender == widget.currentUserId; // Сравниваем с ID текущего пользователя

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75), // Ограничение ширины бабла
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.message.sender == "system"
              ? Colors.amber.shade100 // Цвет для системных сообщений
              : isUser
              ? Colors.blue.shade100
              : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Опционально: показать имя отправителя, если это не текущий пользователь и не система
            if (!isUser && widget.message.sender != "system")
              Text(
                widget.message.sender,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54),
              ),
            if (widget.message.type == MessageType.text)
              Text(widget.message.content)
            else if (widget.message.type == MessageType.video)
              _videoController != null && _videoController!.value.isInitialized
                  ? AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_videoController!),
                    IconButton(
                      icon: Icon(
                        _videoController!.value.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: () {
                        setState(() {
                          _videoController!.value.isPlaying
                              ? _videoController!.pause()
                              : _videoController!.play();
                        });
                      },
                    ),
                  ],
                ),
              )
                  : widget.message.content.startsWith('http') || widget.message.content.contains('/')
                  ? Column( // Показать текст + индикатор, если видео грузится или ошибка
                children: [
                  Text("Видео: ${widget.message.content.split('/').last}", style: TextStyle(fontStyle: FontStyle.italic)),
                  SizedBox(height: 8),
                  CircularProgressIndicator(),
                ],
              )
                  : Text("Не удалось загрузить видео: ${widget.message.content}"), // Если контент не похож на путь или URL
            SizedBox(height: 4),
            Text(
              "${widget.message.timestamp.hour.toString().padLeft(2, '0')}:${widget.message.timestamp.minute.toString().padLeft(2, '0')}",
              style: TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
