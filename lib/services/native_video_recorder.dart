// lib/services/native_video_recorder.dart
import 'dart:async';
import 'package:flutter/services.dart';

class NativeVideoRecorder {
  static const MethodChannel _channel = MethodChannel('com.langbridge.app/video_recorder');
  static final _streamController = StreamController<List<Map<String, dynamic>>?>.broadcast();
  static Stream<List<Map<String, dynamic>>?> get onRecordingResult => _streamController.stream;

  static void initialize() {
    _channel.setMethodCallHandler(_handleMethod);
  }

  static Future<dynamic> _handleMethod(MethodCall call) async {
    if (call.method == 'onRecordingFinished') {
      final arguments = call.arguments;
      if (arguments is List) {
        // Приводим List<dynamic> к List<Map<String, dynamic>>
        final segments = arguments.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _streamController.add(segments);
      } else {
        _streamController.add(null);
      }
    }
  }

  static Future<void> startRecording() async {
    try {
      await _channel.invokeMethod('startRecording');
    } on PlatformException catch (e) {
      print("Failed to start recording: '${e.message}'.");
    }
  }

  static Future<void> stopRecording() async {
    try {
      await _channel.invokeMethod('stopRecording');
    } on PlatformException catch (e) {
      print("Failed to stop recording: '${e.message}'.");
    }
  }

  static Future<void> cancelRecording() async {
    try {
      // Вызываем новый нативный метод
      await _channel.invokeMethod('cancelRecording');
    } on PlatformException catch (e) {
      print("Failed to cancel recording: '${e.message}'.");
    }
  }

  static Future<void> toggleCamera() async {
    try {      await _channel.invokeMethod('toggleCamera');
    print("Flutter: Команда переключения камеры отправлена.");
    } on PlatformException catch (e) {
      print("Failed to toggle camera: '${e.message}'.");
    }
  }

  static Future<void> toggleFlash() async {
    try {
      await _channel.invokeMethod('toggleFlash');
      print("Flutter: Команда переключения вспышки отправлена.");
    } on PlatformException catch (e) {
      print("Failed to toggle flash: '${e.message}'.");
    }
  }
}
