import 'package:flutter/material.dart';
import 'package:LangBridge/models/message.dart';
import 'package:LangBridge/repositories/chat_repository.dart';
import 'media_transcription_widget.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final String currentUserId;
  final ChatRepository chatRepository;
  final Map<String, String> nicknamesCache;
  final Future<String> Function(String userId) getNickname;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.currentUserId,
    required this.chatRepository,
    required this.nicknamesCache,
    required this.getNickname,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == currentUserId;
    final isSystem = message.sender == "system";

    return Align(
      alignment: isSystem ? Alignment.center : (isUser ? Alignment.centerRight : Alignment.centerLeft),
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSystem
              ? Colors.amber.shade100
              : isUser
              ? Colors.blue.shade100
              : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isUser && !isSystem)
                FutureBuilder<String>(
                  future: getNickname(message.sender),
                  initialData: nicknamesCache[message.sender],
                  builder: (context, snapshot) {
                    final displayName = snapshot.data ?? message.sender;
                    return Text(
                      displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54),
                    );
                  },
                ),
              if (message.type == MessageType.text)
                Text(message.content)
              else if (message.type == MessageType.video || message.type == MessageType.audio)
                MediaTranscriptionWidget(
                  message: message,
                  chatRepository: chatRepository,
                  isUser: isUser,
                  key: ValueKey('${message.id}_transcription'),
                )
              else
                const Text("Unsupported message type"),
              const SizedBox(height: 4),
              Text(
                "${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}",
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
