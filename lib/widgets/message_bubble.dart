import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import '../models/message.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final VoidCallback? onTranslate;

  const MessageBubble({
    super.key,
    required this.message,
    this.onTranslate,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.message.type == MessageType.video) {
      _videoController = VideoPlayerController.file(
        File(widget.message.content),
      )..initialize().then((_) {
          setState(() {});
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
    return Align(
      alignment:
          widget.message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.message.isMe ? Colors.blue[200] : Colors.grey[300],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: widget.message.isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (widget.message.type == MessageType.text) ...[
              Text(widget.message.content),
              if (widget.onTranslate != null)
                TextButton(
                  onPressed: widget.onTranslate,
                  child: const Text("Перевести"),
                ),
            ] else if (_videoController != null &&
                _videoController!.value.isInitialized) ...[
              AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
              IconButton(
                icon: Icon(
                  _videoController!.value.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
                onPressed: () {
                  setState(() {
                    _videoController!.value.isPlaying
                        ? _videoController!.pause()
                        : _videoController!.play();
                  });
                },
              ),
            ] else
              const Text("Загрузка видео..."),
          ],
        ),
      ),
    );
  }
}
