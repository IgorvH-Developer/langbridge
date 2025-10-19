// /home/hlopin/Study_Projects/langbridge/test/widgets/fake_video_player.dart

import 'dart:async';
import 'package:flutter/widgets.dart'; // <<< ИЗМЕНЕНИЕ: Импортируем flutter/widgets.dart
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

// Эта реализация взята из официальных тестов пакета video_player
// и адаптирована для простоты.

class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  Completer<void>? _initCompleter;
  StreamController<VideoEvent>? _streamController;
  bool isInitialized = false;
  final Map<int, bool> _isBuffering = <int, bool>{};
  final Map<int, Duration> _position = <int, Duration>{};

  @override
  Future<void> init() async {
    _initCompleter = Completer<void>();
    return _initCompleter!.future;
  }

  @override
  Future<void> dispose(int textureId) async {
    _streamController?.close();
  }

  @override
  Future<int?> create(DataSource dataSource) async {
    final int textureId = _textureCounter;
    _streamController = StreamController<VideoEvent>();
    _isBuffering[textureId] = false;
    _position[textureId] = Duration.zero;

    // Имитируем успешную инициализацию
    Future<void>.delayed(const Duration(milliseconds: 10), () {
      _streamController!.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 15), // Примерная длительность
          size: const Size(1280, 720),
        ),
      );
      isInitialized = true;
      _initCompleter?.complete();
    });

    _textureCounter++;
    return textureId;
  }

  @override
  Future<void> setLooping(int textureId, bool looping) async {}

  @override
  Future<void> play(int textureId) async {}

  @override
  Future<void> pause(int textureId) async {}

  @override
  Future<void> setVolume(int textureId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) async {}

  @override
  Future<void> seekTo(int textureId, Duration position) async {}

  @override
  Future<Duration> getPosition(int textureId) async {
    return _position[textureId]!;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int textureId) {
    _streamController ??= StreamController<VideoEvent>();
    return _streamController!.stream;
  }

  @override
  Widget buildView(int textureId) {
    return const SizedBox(width: 100, height: 100, child: Text('FakeVideoView'));
  }

  static int _textureCounter = 1;
}
