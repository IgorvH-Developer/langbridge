import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class RecordingOverlay extends StatelessWidget {
  final int recordingDurationSeconds;
  final bool isRecordingLocked;
  final bool isPaused;
  final VoidCallback onCancel;
  final VoidCallback onPauseResume;
  final VoidCallback onSend;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleFlash;

  const RecordingOverlay({
    super.key,
    required this.recordingDurationSeconds,
    required this.isRecordingLocked,
    required this.isPaused,
    required this.onCancel,
    required this.onPauseResume,
    required this.onSend,
    required this.onToggleCamera,
    required this.onToggleFlash,
  });

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor().toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  Widget _buildNativeVideoPreview() {
    if (Platform.isAndroid) {
      return const AndroidView(
        viewType: 'com.langbridge.app/video_preview',
        layoutDirection: TextDirection.ltr,
        creationParamsCodec: StandardMessageCodec(),
      );
    }
    if (Platform.isIOS) {
      return const UiKitView(
        viewType: 'com.langbridge.app/video_preview',
        layoutDirection: TextDirection.ltr,
        creationParamsCodec: StandardMessageCodec(),
      );
    }
    return Container(color: Colors.black, child: const Center(child: Text("Превью недоступно")));
  }

  @override
  Widget build(BuildContext context) {
    final previewSize = MediaQuery.of(context).size.width * 0.75;

    return Stack(
      children: [
        // 1. Затемняющий фон (всегда на весь экран)
        Positioned.fill(
          child: Container(color: Colors.black.withOpacity(0.7)),
        ),

        // 2. Центральный блок, содержащий камеру и кнопки под ней.
        //    Этот блок больше не зависит от isRecordingLocked.
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Таймер для НЕзаблокированного режима
              AnimatedOpacity(
                opacity: isRecordingLocked ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _formatDuration(recordingDurationSeconds),
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),

              // КАМЕРА
              SizedBox(
                width: previewSize,
                height: previewSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40.0),
                  child: _buildNativeVideoPreview(),
                ),
              ),
              const SizedBox(height: 30),

              // КНОПКИ УПРАВЛЕНИЯ КАМЕРОЙ (теперь они всегда здесь)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(icon: Icons.flip_camera_ios, onPressed: onToggleCamera),
                  _buildControlButton(icon: Icons.flash_on, onPressed: onToggleFlash),
                ],
              ),
            ],
          ),
        ),

        // 3. Подсказка для свайпа (видна только в НЕзаблокированном режиме)
        if (!isRecordingLocked)
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              "< Свайп влево для отмены",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),


        // 4. Панель управления для ЗАБЛОКИРОВАННОГО режима
        if (isRecordingLocked)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildLockedVideoControls(context),
          ),
      ],
    );
  }

  // Панель управления (Отмена, Пауза, Отправка)
  Widget _buildLockedVideoControls(BuildContext context) {
    final durationString = _formatDuration(recordingDurationSeconds);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 30), onPressed: onCancel),
            TextButton.icon(
              icon: Icon(isPaused ? Icons.play_arrow : Icons.pause, color: Colors.black, size: 30),
              label: Text(durationString, style: const TextStyle(fontSize: 18, color: Colors.black)),
              onPressed: onPauseResume,
            ),
            IconButton(icon: const Icon(Icons.send, color: Colors.blue, size: 30), onPressed: onSend),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required VoidCallback onPressed}) {
    return CircleAvatar(
      radius: 30,
      backgroundColor: Colors.black.withOpacity(0.5),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 30),
        onPressed: onPressed,
      ),
    );
  }
}
