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

  bool _isTranscriptionLoading = false;
  Future<void>? _initializePlayerFuture;

  @override
  void initState() {
    super.initState();
    if (widget.message.type == MessageType.video) {
      _initializePlayerFuture = _initVideoPlayer();
    } else if (widget.message.type == MessageType.audio && widget.message.audioUrl!.isNotEmpty) {
      _initAudioPlayer();
      _generateFakeWaveform();
    }

    if (widget.message.transcription != null) {
      _editableTranscription = TranscriptionData.fromJson(widget.message.transcription!.toJson());
    }
  }

  @override
  void didUpdateWidget(covariant MediaTranscriptionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message.id != oldWidget.message.id) {
      _disposePlayers();
      setState(() {
        _isPlaying = false;
        _isTranscriptionPanelVisible = false;
        _currentWordIndex = -1;
        _currentPosition = Duration.zero;
        _initializePlayerFuture = null;
        _editableTranscription = null;
        _isTranscriptionLoading = false;

        if (widget.message.type == MessageType.video) {
          _initializePlayerFuture = _initVideoPlayer();
        } else if (widget.message.type == MessageType.audio && widget.message.audioUrl!.isNotEmpty) {
          _initAudioPlayer();
        }
        if (widget.message.transcription != null) {
          _editableTranscription = TranscriptionData.fromJson(widget.message.transcription!.toJson());
        }
      });
    } else if (widget.message.transcription != null && oldWidget.message.transcription == null) {
      setState(() {
        _editableTranscription = TranscriptionData.fromJson(widget.message.transcription!.toJson());
        _isTranscriptionLoading = false;
      });
    }
  }

  void _generateFakeWaveform() {
    final random = Random();
    _waveformData = List<double>.generate(100, (i) => max(0.1, random.nextDouble()));
  }

  void _disposePlayers() {
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    _videoController = null;
    _audioPlayer.stop();
  }

  void _videoListener() {
    if (!mounted || _videoController == null || !_videoController!.value.isInitialized) return;
    final value = _videoController!.value;
    final bool isPlaying = value.isPlaying;
    if (isPlaying != _isPlaying) {
      setState(() { _isPlaying = isPlaying; });
    }
    _onPositionChanged(position: value.position);
    if (mounted) {
      setState(() { _currentPosition = value.position; });
    }
  }

  Future<void> _initVideoPlayer() async {
    if (widget.message.videoUrl!.isEmpty) {
      throw Exception("Video URL is empty");
    }
    _videoController?.dispose();
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.message.videoUrl!));
    await _videoController!.initialize();
    _videoController!.addListener(_videoListener);
    if (mounted) setState(() {});
  }

  void _initAudioPlayer() {
    _audioPlayer.setSourceUrl(widget.message.audioUrl!);
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() { _isPlaying = state == PlayerState.playing; });
      if (state == PlayerState.completed) {
        setState(() { _currentPosition = Duration.zero; });
      }
    });
    _audioPlayer.onPositionChanged.listen((duration) {
      if (!mounted) return;
      _onPositionChanged(position: duration);
      setState(() { _currentPosition = duration; });
    });
  }

  void _onPositionChanged({Duration? position}) {
    if (!mounted || _editableTranscription == null || _editableTranscription!.words.isEmpty) return;
    final currentPositionInSeconds = (position?.inMilliseconds ?? 0) / 1000.0;
    final index = _editableTranscription!.words.lastIndexWhere((word) => currentPositionInSeconds >= word.start);
    if (index != -1 && index != _currentWordIndex) {
      setState(() { _currentWordIndex = index; });
    }
  }

  @override
  void dispose() {
    _disposePlayers();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPause() async {
    if (widget.message.type == MessageType.video) {
      final controller = _videoController;
      if (controller == null || !controller.value.isInitialized) return;
      controller.value.isPlaying ? await controller.pause() : await controller.play();
    } else if (widget.message.type == MessageType.audio) {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        if (_currentPosition >= (widget.message.duration ?? Duration.zero) - const Duration(milliseconds: 200)) {
          await _audioPlayer.seek(Duration.zero);
        }
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
    setState(() { _currentPosition = newPosition; });
  }

  void _editWord(TranscriptionWord word, int index) {
    final textController = TextEditingController(text: word.word);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать слово'),
        content: TextField(controller: textController, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Отмена')),
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

  Future<void> _requestTranscriptionIfNeeded() async {
    if (_editableTranscription != null || _isTranscriptionLoading) return;

    if (mounted) {
      setState(() {
        _isTranscriptionLoading = true;
      });
    }

    await widget.chatRepository.fetchAndApplyTranscription(widget.message.id);
  }

  void _toggleTranscriptionPanel() {
    setState(() {
      _isTranscriptionPanelVisible = !_isTranscriptionPanelVisible;
    });

    if (_isTranscriptionPanelVisible && widget.message.transcription == null) {
      _requestTranscriptionIfNeeded();
    }
  }

  Widget _buildTranscriptionPanel() {
    if (_isTranscriptionLoading) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Center(child: Text("Транскрипция загружается...")),
      );
    }

    if (_editableTranscription == null) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Center(child: Text("Транскрипция недоступна.", style: TextStyle(color: Colors.grey))),
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
                    color: index == _currentWordIndex ? Colors.blue.shade100 : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(word.word),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          if (widget.isUser)
            ElevatedButton(
              onPressed: () {
                widget.chatRepository.saveTranscription(widget.message.id, _editableTranscription!);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Изменения сохранены!")));
              },
              child: const Text('Сохранить изменения'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget mediaWidget;
    if (widget.message.type == MessageType.video) {
      mediaWidget = _buildVideoPlayer();
    } else if (widget.message.type == MessageType.audio) {
      mediaWidget = _buildAudioPlayer();
    } else {
      mediaWidget = const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mediaWidget,
        if (_isTranscriptionPanelVisible) _buildTranscriptionPanel(),
      ],
    );
  }

  Widget _buildAudioPlayer() {
    final totalDuration = (widget.message.duration != null && widget.message.duration! > Duration.zero)
        ? widget.message.duration!
        : const Duration(seconds: 1);

    final playedRatio = (_currentPosition.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0);
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
          mainAxisSize: MainAxisSize.min,
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

  Widget _buildVideoPlayer() {
    return FutureBuilder(
      future: _initializePlayerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && _videoController != null && _videoController!.value.isInitialized) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  VideoPlayer(_videoController!),
                  _buildControlsOverlay(),
                ],
              ),
            ),
          );
        }
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: snapshot.hasError
                  ? const Icon(Icons.error_outline, color: Colors.red, size: 48)
                  : const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlsOverlay() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final totalDuration = _videoController!.value.duration;
    final currentPosition = _videoController!.value.position;

    // Функция для форматирования времени
    String formatDuration(Duration d) {
      final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return "$minutes:$seconds";
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            // Кнопка Play/Pause
            IconButton(
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              color: Colors.white,
              onPressed: _playPause,
            ),
            // Текст текущего времени
            Text(
              formatDuration(currentPosition),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            // Слайдер, который занимает все оставшееся место
            Expanded(
              child: Slider(
                value: currentPosition.inMilliseconds.toDouble().clamp(0.0, totalDuration.inMilliseconds.toDouble()),
                min: 0.0,
                max: totalDuration.inMilliseconds.toDouble(),
                onChanged: (value) {
                  _videoController!.seekTo(Duration(milliseconds: value.toInt()));
                },
                activeColor: Colors.white,
                inactiveColor: Colors.white38,
              ),
            ),
            // Текст общей длительности
            Text(
              formatDuration(totalDuration),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            // Кнопка субтитров
            IconButton(
              icon: const Icon(Icons.subtitles),
              color: _isTranscriptionPanelVisible ? Colors.blueAccent : Colors.white,
              onPressed: _toggleTranscriptionPanel,
            ),
          ],
        ),
      ),
    );
  }
}


class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double playedRatio;
  final bool isUser;

  WaveformPainter({required this.waveformData, required this.playedRatio, required this.isUser});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final playedPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.blueAccent;

    final path = Path();
    final playedPath = Path();

    final middleY = size.height / 2;
    final barWidth = size.width / waveformData.length;

    for (int i = 0; i < waveformData.length; i++) {
      final barHeight = waveformData[i] * size.height;
      final startX = i * barWidth;
      final startY = middleY - barHeight / 2;

      final currentPath = (i / waveformData.length < playedRatio) ? playedPath : path;

      currentPath.moveTo(startX, startY);
      currentPath.lineTo(startX, startY + barHeight);
    }

    paint.color = isUser ? Colors.grey.shade600 : Colors.white70;
    canvas.drawPath(path, paint);
    canvas.drawPath(playedPath, playedPaint);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.playedRatio != playedRatio || oldDelegate.isUser != isUser;
  }
}
