import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';import 'package:LangBridge/config/app_config.dart';
import 'package:LangBridge/repositories/chat_repository.dart'; // <<< ИМПОРТ
import '../models/message.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final String currentUserId;
  // Добавляем репозиторий для доступа к API
  final ChatRepository chatRepository;

  const MessageBubble({
    super.key,
    required this.message,
    required this.currentUserId,
    required this.chatRepository, // <<< ДОБАВЛЕНО
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  VideoPlayerController? _videoController;
  bool _showTranscription = false;

  // Состояния для ленивой загрузки транскрипции
  bool _isTranscriptionLoading = false;
  String? _transcriptionText;

  @override
  void initState() {
    super.initState();
    // Запоминаем уже имеющийся текст, если он пришел сразу
    _transcriptionText = widget.message.transcription;

    if (widget.message.type == MessageType.video && widget.message.videoUrl != null) {
      final fullVideoUrl = "http://${AppConfig.serverAddr}${widget.message.videoUrl!}";

      print("Initializing video from URL: $fullVideoUrl"); // <-- Очень полезно для отладки!

      _videoController = VideoPlayerController.networkUrl(Uri.parse(fullVideoUrl))
        ..initialize().then((_) {
          // Этот блок выполнится, когда видео будет готово к воспроизведению
          if (mounted) {
            print("Video initialized successfully.");
            setState(() {}); // Перерисовываем виджет, чтобы показать плеер
          }
        }).catchError((error) {
          if(mounted) print("!!! Video player initialization FAILED: $error");
        });
    }
  }

  // Метод для запроса и загрузки транскрипции
  Future<void> _fetchTranscription() async {
    if (_isTranscriptionLoading || _transcriptionText != null) return;

    setState(() {
      _isTranscriptionLoading = true;
    });

    final text = await widget.chatRepository.transcribeMessage(widget.message.id);

    if (mounted) {
      setState(() {
        _transcriptionText = text;
        _isTranscriptionLoading = false;
        // Сразу показываем текст после загрузки
        _showTranscription = true;
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.sender == widget.currentUserId;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue.shade100 : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (widget.message.type == MessageType.text)
              Text(widget.message.content)
            else if (widget.message.type == MessageType.video)
              _buildVideoContent(),

            const SizedBox(height: 4),
            Text(
              "${widget.message.timestamp.hour.toString().padLeft(2, '0')}:${widget.message.timestamp.minute.toString().padLeft(2, '0')}",
              style: const TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoContent() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text("Загрузка видео..."),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_videoController!),
              IconButton(
                icon: Icon(
                  _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 40,
                ),
                onPressed: () => setState(() {
                  _videoController!.value.isPlaying ? _videoController!.pause() : _videoController!.play();
                }),
              ),
            ],
          ),
        ),
        // Кнопка для отображения текста
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: InkWell(
            onTap: () {
              // Если текста еще нет, загружаем его
              if (_transcriptionText == null) {
                _fetchTranscription();
              } else {
                // Иначе просто переключаем видимость
                setState(() => _showTranscription = !_showTranscription);
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isTranscriptionLoading)
                  const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Icon(_showTranscription ? Icons.subtitles_off : Icons.subtitles, size: 18, color: Colors.black54),

                const SizedBox(width: 4),
                Text(
                  _isTranscriptionLoading
                      ? "Генерация..."
                      : (_showTranscription ? "Скрыть текст" : "Показать текст"),
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),

        // Поле с распознанным текстом
        if (_showTranscription && _transcriptionText != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8.0),
            margin: const EdgeInsets.only(top: 8.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _transcriptionText!,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}
