enum MessageType { text, video }

class Message {
  final String id;
  final String sender;
  final String content; // для текста это сам текст, для видео – путь к файлу
  final MessageType type;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.sender,
    required this.content,
    required this.type,
    required this.timestamp,
  });
}