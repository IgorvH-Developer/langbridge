import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../models/chat.dart';
import '../models/message.dart';
import '../repositories/chat_repository.dart';

class ChatScreen extends StatefulWidget {
  final Chat chat;
  final ChatRepository chatRepository;

  const ChatScreen({
    super.key,
    required this.chat,
    required this.chatRepository,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late Chat _chat;
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _chat = widget.chat;
  }

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;

    final message = widget.chatRepository.createMessage(
      sender: "user",
      content: _controller.text.trim(),
      type: MessageType.text,
    );

    setState(() {
      _chat = widget.chatRepository.addMessage(_chat, message);
    });

    _controller.clear();
  }

  Future<void> _sendVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.camera);
    if (picked == null) return;

    final message = widget.chatRepository.createMessage(
      sender: "user",
      content: picked.path, // путь к файлу видео
      type: MessageType.video,
    );

    setState(() {
      _chat = widget.chatRepository.addMessage(_chat, message);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_chat.title)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _chat.messages.length,
              itemBuilder: (context, index) {
                final msg = _chat.messages[index];
                return _MessageBubble(message: msg);
              },
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.videocam),
                onPressed: _sendVideo,
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: "Введите сообщение...",
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  final Message message;

  const _MessageBubble({required this.message});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.message.type == MessageType.video) {
      _controller = VideoPlayerController.file(
        File(widget.message.content),
      )..initialize().then((_) {
          setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.sender == "user";

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue.shade100 : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: widget.message.type == MessageType.text
            ? Text(widget.message.content)
            : _controller != null && _controller!.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        VideoPlayer(_controller!),
                        IconButton(
                          icon: Icon(
                            _controller!.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                          ),
                          onPressed: () {
                            setState(() {
                              _controller!.value.isPlaying
                                  ? _controller!.pause()
                                  : _controller!.play();
                            });
                          },
                        ),
                      ],
                    ),
                  )
                : const CircularProgressIndicator(),
      ),
    );
  }
}