import 'package:flutter/material.dart';
import '../models/message.dart';
import '../widgets/message_bubble.dart';
import '../services/translation_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Message> _messages = [];
  final _controller = TextEditingController();
  final _translationService = TranslationService();

  void _sendTextMessage() {
    if (_controller.text.trim().isEmpty) return;
    final newMessage = Message(
      id: DateTime.now().toString(),
      content: _controller.text,
      isMe: true,
      timestamp: DateTime.now(),
      type: MessageType.text,
    );
    setState(() {
      _messages.add(newMessage);
    });
    _controller.clear();
  }

  void _addVideoMessage(String filePath) {
    final videoMessage = Message(
      id: DateTime.now().toString(),
      content: filePath,
      isMe: true,
      timestamp: DateTime.now(),
      type: MessageType.video,
    );
    setState(() {
      _messages.add(videoMessage);
    });
  }

  Future<void> _translateMessage(int index) async {
    if (_messages[index].type != MessageType.text) return;
    final translated = await _translationService.translate(
      _messages[index].content,
      "en",
    );
    setState(() {
      _messages[index] = Message(
        id: _messages[index].id,
        content: translated,
        isMe: _messages[index].isMe,
        timestamp: _messages[index].timestamp,
        type: MessageType.text,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Чат"),
        actions: [
          IconButton(
            icon: const Icon(Icons.video_call),
            onPressed: () async {
              final filePath =
                  await Navigator.pushNamed(context, '/video') as String?;
              if (filePath != null) {
                _addVideoMessage(filePath);
              }
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (ctx, i) => MessageBubble(
                message: _messages[i],
                onTranslate: _messages[i].type == MessageType.text
                    ? () => _translateMessage(i)
                    : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
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
                  onPressed: _sendTextMessage,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
