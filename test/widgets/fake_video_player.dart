import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final Map<int, Completer<void>> _initCompleters = {};
  final Map<int, StreamController<VideoEvent>> _streamControllers = {};
  int _textureCounter = 0;
  final Map<int, bool> _isBuffering = <int, bool>{};
  final Map<int, Duration> _position = <int, Duration>{};

  @override
  Future<int?> create(DataSource dataSource) async {
    final textureId = _textureCounter++;
    final controller = StreamController<VideoEvent>.broadcast();
    _streamControllers[textureId] = controller;
    controller.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 10),
        size: const Size(100, 100),
      ),
    );
    return textureId;
  }

  @override
  Future<void> dispose(int textureId) async {
    _streamControllers[textureId]?.close();
    _streamControllers.remove(textureId);
  }

  void disposeAll() {
    for (final controller in _streamControllers.values) {
      controller.close();
    }
    _streamControllers.clear();
  }
  // >>>>> КОНЕЦ ИСПРАВЛЕНИЯ <<<<<

  @override
  Stream<VideoEvent> videoEventsFor(int textureId) {
    return _streamControllers[textureId]?.stream ?? const Stream.empty();
  }

  // Остальные методы без изменений

  @override
  Future<void> init() async {
    // Этот метод вызывается один раз и может оставаться пустым.
    // Важная логика теперь в create().
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
    return _position[textureId] ?? Duration.zero;
  }

  @override
  Widget buildView(int textureId) {
    return const SizedBox(width: 100, height: 100, child: Text('FakeVideoView'));
  }
}
