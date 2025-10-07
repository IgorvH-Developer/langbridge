import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:LangBridge/config/app_config.dart';
import 'package:LangBridge/models/message.dart';
import 'package:LangBridge/models/transcription_data.dart';
import 'package:LangBridge/repositories/chat_repository.dart';

class VideoTranscriptionWidget extends StatefulWidget {
  final Message message;
  final ChatRepository chatRepository;
  final bool isUser;

  const VideoTranscriptionWidget({
    Key? key,
    required this.message,
    required this.chatRepository,
    required this.isUser,
  }) : super(key: key);

  @override
  _VideoTranscriptionWidgetState createState() => _VideoTranscriptionWidgetState();
}

class _VideoTranscriptionWidgetState extends State<VideoTranscriptionWidget> {
  VideoPlayerController? _controller;
  bool _isTranscriptionPanelVisible = false;
  Timer? _syncTimer;
  int _currentWordIndex = -1;
  TranscriptionData? _editableTranscription;

  @override
  void initState() {
    super.initState();
    if (widget.message.videoUrl != null) {
      // Собираем полный URL, используя IP-адрес сервера из конфигурации.
      final fullVideoUrl = "http://${AppConfig.serverAddr}${widget.message.videoUrl}";

      _controller = VideoPlayerController.networkUrl(Uri.parse(fullVideoUrl))
        ..initialize().then((_) {
          if (mounted) setState(() {});
          _controller!.addListener(_onVideoPositionChanged);
        }).catchError((error) {
          print("Ошибка инициализации видеоплеера для URL: $fullVideoUrl");
          print("Ошибка: $error");
        });
    }
    if (widget.message.transcription != null) {
      // Создаем редактируемую копию
      _editableTranscription = TranscriptionData.fromJson(widget.message.transcription!.toJson());
    }
  }

  void _onVideoPositionChanged() {
    if (!_isTranscriptionPanelVisible || _editableTranscription == null) return;

    final position = _controller!.value.position.inMilliseconds / 1000.0;
    final index = _editableTranscription!.words.indexWhere(
            (word) => position >= word.start && position <= word.end
    );

    if (index != _currentWordIndex) {
      setState(() {
        _currentWordIndex = index;
      });
    }
  }

  void _toggleTranscriptionPanel() {
    if (_editableTranscription == null) {
      widget.chatRepository.fetchAndApplyTranscription(widget.message.id);
    }
    setState(() {
      _isTranscriptionPanelVisible = !_isTranscriptionPanelVisible;
    });
  }

  void _editWord(TranscriptionWord word, int index) {
    final textController = TextEditingController(text: word.word);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Редактировать слово"),
          content: TextField(controller: textController, autofocus: true),
          actions: [
            TextButton(
              onPressed: () { // Удаление
                setState(() {
                  _editableTranscription!.words.removeAt(index);
                  _editableTranscription!.regenerateFullText();
                });
                Navigator.of(context).pop();
              },
              child: Text("Удалить", style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Отмена"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _editableTranscription!.words[index].word = textController.text;
                  _editableTranscription!.regenerateFullText();
                });
                Navigator.of(context).pop();
              },
              child: Text("Сохранить"),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoPositionChanged);
    _controller?.dispose();
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Если транскрипция пришла после открытия панели, обновим editableTranscription
    if (widget.message.transcription != null && _editableTranscription == null) {
      _editableTranscription = TranscriptionData.fromJson(widget.message.transcription!.toJson());
    }

    return Column(
      crossAxisAlignment: widget.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        _buildVideoPlayer(),
        if (_isTranscriptionPanelVisible) _buildTranscriptionPanel(),
      ],
    );
  }

  Widget _buildVideoPlayer() {
    return AspectRatio(
      aspectRatio: _controller?.value.aspectRatio ?? 16 / 9,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          if (_controller != null && _controller!.value.isInitialized)
            VideoPlayer(_controller!)
          else
            Container(
              color: Colors.black,
              child: Center(child: CircularProgressIndicator()),
            ),
          _buildControlsOverlay(),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Container(
      color: Colors.black26,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(_controller?.value.isPlaying ?? false ? Icons.pause : Icons.play_arrow),
            color: Colors.white,
            onPressed: () {
              setState(() {
                _controller?.value.isPlaying ?? false ? _controller?.pause() : _controller?.play();
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.subtitles),
            color: _isTranscriptionPanelVisible ? Colors.blueAccent : Colors.white,
            onPressed: _toggleTranscriptionPanel,
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptionPanel() {
    if (_editableTranscription == null) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8.0),
      margin: const EdgeInsets.only(top: 4.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Wrap(
            spacing: 4.0,
            runSpacing: 4.0,
            children: _editableTranscription!.words.asMap().entries.map((entry) {
              int index = entry.key;
              TranscriptionWord word = entry.value;
              return InkWell(
                onTap: () => _editWord(word, index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: index == _currentWordIndex ? Colors.yellow.shade400 : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(word.word),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              widget.chatRepository.saveTranscription(widget.message.id, _editableTranscription!);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Транскрипция сохранена")));
            },
            child: Text("Сохранить изменения"),
          )
        ],
      ),
    );
  }
}
