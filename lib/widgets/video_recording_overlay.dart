import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:LangBridge/models/message.dart';

class VideoRecordingOverlay extends StatelessWidget {
  final CameraController cameraController;
  final Message? replyingToMessage;
  final VoidCallback onCancelReply;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleFlash;

  const VideoRecordingOverlay({
    super.key,
    required this.cameraController,
    this.replyingToMessage,
    required this.onCancelReply,
    required this.onToggleCamera,
    required this.onToggleFlash,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Затемняющий фон
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.7),
          ),
        ),

        // Виджет превью камеры
        Positioned(
          top: 100,
          left: 20,
          right: 20,
          child: Center(
            child: AspectRatio(
              aspectRatio: 1, // Квадратное превью
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CameraPreview(cameraController),
              ),
            ),
          ),
        ),

        // Рамка с ответом (если есть)
        if (replyingToMessage != null)
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: _buildReplyPreview(context),
          ),

        // Панель с кнопками управления
        Positioned(
          bottom: 150, // Располагаем под превью
          left: 20,
          right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Кнопка смены камеры
              _buildControlButton(
                icon: Icons.flip_camera_ios,
                onPressed: onToggleCamera,
              ),
              // Кнопка вспышки
              _buildControlButton(
                icon: cameraController.value.flashMode == FlashMode.torch
                    ? Icons.flash_on
                    : Icons.flash_off,
                onPressed: onToggleFlash,
              ),
            ],
          ),
        ),

        // Подсказки для свайпов
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Text(
            "< Свайп влево для отмены | Свайп вверх для блокировки >",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        )
      ],
    );
  }

  Widget _buildControlButton({required IconData icon, required VoidCallback onPressed}) {
    return CircleAvatar(
      radius: 30,
      backgroundColor: Colors.black.withOpacity(0.5),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    String getPlaceholderText(Message message) {
      switch (message.type) {
        case MessageType.audio: return "Голосовое сообщение";
        case MessageType.video: return "Видео";
        case MessageType.image: return "Изображение";
        default: return message.content;
      }
    }

    return Material( // Оборачиваем в Material для корректного отображения текста
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade800.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: Colors.blue.shade300, width: 4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Ответ на сообщение", // Здесь нужен более сложный способ получения имени
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    getPlaceholderText(replyingToMessage!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: onCancelReply,
            ),
          ],
        ),
      ),
    );
  }
}
