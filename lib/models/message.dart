enum MessageType { text, video }

class Message {
  final String id;
  final String content; // либо текст, либо путь к видеофайлу
  final bool isMe;
  final DateTime timestamp;
  final MessageType type;

  Message({
    required this.id,
    required this.content,
    required this.isMe,
    required this.timestamp,
    required this.type,
  });
}
