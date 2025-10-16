import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:LangBridge/models/message.dart';
import 'package:LangBridge/models/transcription_data.dart';
import 'package:LangBridge/repositories/chat_repository.dart';

class MediaTranscriptionWidget extends StatefulWidget {
  final Message message;
  final ChatRepository chatRepository;
  final bool isUser;

  const MediaTranscriptionWidget({
    Key? key,
    required this.message,
    required this.chatRepository,
    required this.isUser,
  }) : super(key: key);

  @override
  _MediaTranscriptionWidgetState createState() => _MediaTranscriptionWidgetState();
}

class _MediaTranscriptionWidgetState extends State<MediaTranscriptionWidget> {
  VideoPlayerController? _videoController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  bool _isTranscriptionPanelVisible = false;
  int _currentWordIndex = -1;
  TranscriptionData? _editableTranscription;

  Duration _currentPosition = Duration.zero;
  List<double> _waveformData = [];

  @override
  void initState() {
    super.initState();
    if (widget.message.type == MessageType.video && widget.message.videoUrl != null) {
      _initVideoPlayer();
    } else if (widget.message.type == MessageType.audio && widget.message.audioUrl != null) {
      _initAudioPlayer();
      _generateFakeWaveform();
    }

    if (widget.message.transcription != null) {
      _editableTranscription = TranscriptionData.fromJson(widget.message.transcription!.toJson());
    }
  }

  void _generateFakeWaveform() {
    final random = Random();
    _waveformData = List<double>.generate(100, (i) => max(0.1, random.nextDouble()));
  }

  void _initVideoPlayer() {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.message.videoUrl!))
      ..initialize().then((_) {
        if (mounted) setState(() {});
        _videoController!.addListener(_videoListener);
      });
  }

  void _videoListener() {
    if (!mounted) return;
    final value = _videoController!.value;
    final bool isPlaying = value.isPlaying;
    if (isPlaying != _isPlaying) {
      setState(() {
        _isPlaying = isPlaying;
      });
    }
    // Для видео обновляем позицию здесь
    _onPositionChanged(position: value.position);
    if(mounted) {
      setState(() {
        _currentPosition = value.position;
      });
    }
  }

  void _initAudioPlayer() {
    _audioPlayer.setSourceUrl(widget.message.audioUrl!);

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });

      // **РЕШЕНИЕ ПРОБЛЕМЫ №1**: Если воспроизведение завершено, сбрасываем состояние
      if (state == PlayerState.completed) {
        setState(() {
          _currentPosition = Duration.zero; // Сбрасываем позицию на начало
        });
      }
    });

    // Слушаем изменение позиции
    _audioPlayer.onPositionChanged.listen((duration) {
      if (!mounted) return;
      // Обновляем и позицию, и связанные данные (подсветка слов)
      _onPositionChanged(position: duration);
      setState(() {
        _currentPosition = duration;
      });
    });
  }
  // --- КОНЕЦ ИЗМЕНЕНИЙ ---

  void _onPositionChanged({Duration? position}) {
    if (!mounted || _editableTranscription == null || _editableTranscription!.words.isEmpty) return;

    final currentPositionInSeconds = (position?.inMilliseconds ?? 0) / 1000.0;

    final index = _editableTranscription!.words.lastIndexWhere(
            (word) => currentPositionInSeconds >= word.start
    );

    if (index != -1 && index != _currentWordIndex) {
      setState(() {
        _currentWordIndex = index;
      });
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPause() async {
    if (widget.message.type == MessageType.video) {
      final controller = _videoController;
      if (controller == null) return;
      controller.value.isPlaying ? await controller.pause() : await controller.play();
    } else if (widget.message.type == MessageType.audio) {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        // **РЕШЕНИЕ ПРОБЛЕМЫ №1**: Если плеер завершил работу и позиция в конце,
        // нужно запустить его с самого начала.
        if (_currentPosition >= (widget.message.duration ?? Duration.zero) - const Duration(milliseconds: 200)) {
          // Начинаем с нуля
          await _audioPlayer.seek(Duration.zero);
        }
        // resume() сработает и для начала, и для продолжения после паузы
        await _audioPlayer.resume();
      }
    }
  }

  void _seek(double newPositionRatio) {
    if (widget.message.duration == null) return;
    final newPosition = widget.message.duration! * newPositionRatio;

    if (widget.message.type == MessageType.video) {
      _videoController?.seekTo(newPosition);
    } else if (widget.message.type == MessageType.audio) {
      _audioPlayer.seek(newPosition);
    }

    // Оптимистичное обновление UI, чтобы не ждать следующего тика от плеера
    setState(() {
      _currentPosition = newPosition;
    });
  }

  void _editWord(TranscriptionWord word, int index) {
    final textController = TextEditingController(text: word.word);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать слово'),
        content: TextField(
          controller: textController,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              if (!mounted) return;
              setState(() {
                _editableTranscription!.words[index].word = textController.text.trim();
                _editableTranscription!.regenerateFullText();
              });
              Navigator.of(context).pop();
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  // --- ИЗМЕНЕНИЯ В _buildAudioPlayer ---
  Widget _buildAudioPlayer() {
    // **РЕШЕНИЕ ПРОБЛЕМЫ №2**: Убедимся, что totalDuration не 0.
    final totalDuration = (widget.message.duration != null && widget.message.duration! > Duration.zero)
        ? widget.message.duration!
        : const Duration(seconds: 1); // Безопасное значение по умолчанию

    final playedRatio = (_currentPosition.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0);
    // Отладочный вывод, который поможет, если проблема останется
    // print("Pos: ${_currentPosition.inMilliseconds}, Total: ${totalDuration.inMilliseconds}, Ratio: $playedRatio");

    return GestureDetector(
      onTapDown: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final localDx = box.globalToLocal(details.globalPosition).dx;
        final width = box.size.width;
        _seek(localDx / width);
      },
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            IconButton(
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              color: widget.isUser ? Colors.black : Colors.white,
              onPressed: _playPause,
            ),
            Expanded(
              child: CustomPaint(
                painter: WaveformPainter(
                  waveformData: _waveformData,
                  playedRatio: playedRatio,
                  isUser: widget.isUser,
                ),
                size: const Size(double.infinity, 50),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.subtitles),
              color: _isTranscriptionPanelVisible
                  ? Colors.blueAccent
                  : (widget.isUser ? Colors.black : Colors.white),
              onPressed: _toggleTranscriptionPanel,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.transcription != null && _editableTranscription == null) {
      _editableTranscription = TranscriptionData.fromJson(widget.message.transcription!.toJson());
    }

    return Column(
      crossAxisAlignment: widget.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (widget.message.type == MessageType.video)
          _buildVideoPlayer()
        else if (widget.message.type == MessageType.audio)
        // Для аудио не нужен _buildControlsOverlay, его заменяет _buildAudioPlayer
          _buildAudioPlayer()
        else
        // Это текстовое сообщение, для него не нужен медиа-виджет
        // Этот блок по идее не должен вызываться, т.к. MessageBubble
        // вызывает этот виджет только для media.
          const SizedBox.shrink(),

        // Панель транскрипции идет отдельно
        if (_isTranscriptionPanelVisible) _buildTranscriptionPanel(),
      ],
    );
  }

  Widget _buildVideoPlayer() {
    return AspectRatio(
      aspectRatio: _videoController?.value.aspectRatio ?? 16 / 9,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          if (_videoController != null && _videoController!.value.isInitialized)
            VideoPlayer(_videoController!)
          else
            Container(
              color: Colors.black,
              child: const Center(child: CircularProgressIndicator()),
            ),
          _buildControlsOverlay(),
        ],
      ),
    );
  }

  // Этот виджет теперь ТОЛЬКО для видео
  Widget _buildControlsOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            color: Colors.white,
            onPressed: _playPause,
          ),
          IconButton(
            icon: const Icon(Icons.subtitles),
            color: _isTranscriptionPanelVisible ? Colors.blueAccent : Colors.white,
            onPressed: _toggleTranscriptionPanel,
          ),
        ],
      ),
    );
  }

  Future<void> _requestTranscriptionIfNeeded() async {
    if (_editableTranscription != null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Запрос расшифровки...")),
    );

    await widget.chatRepository.fetchAndApplyTranscription(widget.message.id);
  }

  void _toggleTranscriptionPanel() {
    if (widget.message.transcription == null) {
      _requestTranscriptionIfNeeded();
      return;
    }
    setState(() {
      _isTranscriptionPanelVisible = !_isTranscriptionPanelVisible;
    });
  }

  Widget _buildTranscriptionPanel() {
    if (_editableTranscription == null) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Center(child: Text("Транскрипция загружается...")),
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
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              widget.chatRepository.saveTranscription(widget.message.id, _editableTranscription!);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Транскрипция сохранена")));
            },
            child: const Text("Сохранить изменения"),
          )
        ],
      ),
    );
  }
}


// --- НОВЫЙ КЛАСС PAINTER ---
class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double playedRatio; // От 0.0 до 1.0
  final bool isUser;

  WaveformPainter({
    required this.waveformData,
    required this.playedRatio,
    required this.isUser,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final playedColor = isUser ? Colors.white : Colors.blue.shade200;
    final unplayedColor = isUser ? Colors.blue.shade200 : Colors.grey.shade400;

    final paintPlayed = Paint()..color = playedColor;
    final paintUnplayed = Paint()..color = unplayedColor;

    final barWidth = size.width / waveformData.length;
    final barSpacing = barWidth * 0.4; // 40% от ширины столбика будет отступом
    final singleBarWidth = barWidth - barSpacing;
    final maxHeight = size.height;

    final playedBarsCount = (waveformData.length * playedRatio).floor();

    for (int i = 0; i < waveformData.length; i++) {
      final barHeight = waveformData[i] * maxHeight;
      final x = i * barWidth;
      final y = (maxHeight - barHeight) / 2;

      final rect = Rect.fromLTWH(x, y, singleBarWidth, barHeight);

      final paint = i < playedBarsCount ? paintPlayed : paintUnplayed;
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    // Перерисовываем, если изменился прогресс или данные волны
    return oldDelegate.playedRatio != playedRatio || oldDelegate.waveformData != waveformData;
  }
}
