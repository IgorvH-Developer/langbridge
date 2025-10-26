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
  final void Function(Message message) onReply;
  final void Function(String messageId) onTapRepliedMessage;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.currentUserId,
    required this.chatRepository,
    required this.nicknamesCache,
    required this.getNickname,
    required this.onReply,
    required this.onTapRepliedMessage,
  }) : super(key: key);

  Widget _buildRepliedMessage(BuildContext context) {
    if (message.repliedTo == null) return const SizedBox.shrink();

    final replied = message.repliedTo!;
    final isReplyToSelf = replied.senderId == currentUserId;

    // Такая же логика для заглушек, как в ChatScreen
    String getPlaceholderText(RepliedMessageInfo message) {
      switch (message.type) {
        case MessageType.audio: return "Голосовое сообщение";
        case MessageType.video: return "Видео";
        case MessageType.image: return "Изображение";
        default: return message.content;
      }
    }

    return GestureDetector(
      onTap: () => onTapRepliedMessage(replied.id),
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 3, color: isReplyToSelf ? Colors.green : Colors.purple),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isReplyToSelf ? "Вы" : (nicknamesCache[replied.senderId] ?? replied.senderId),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isReplyToSelf ? Colors.green : Colors.purple
                      ),
                    ),
                    Text(
                      getPlaceholderText(replied),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == currentUserId;
    final isSystem = message.sender == "system";
    final bubble = Container( /* ... */ );

    return Dismissible(
      key: ValueKey('dismiss_${message.id}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {
        DismissDirection.endToStart: 0.2,
      },
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          onReply(message);
          return false;
        }
        return false;
      },
      background: Container(
        color: Colors.blue.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.reply, color: Colors.blue),
      ),
      child: Align(
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
                _buildRepliedMessage(context),
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
      ),
    );
  }
}
