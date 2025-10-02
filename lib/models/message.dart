import 'package:uuid/uuid.dart';

enum MessageType { text, image, video, audio }

class Message {
  final String id;
  final String sender; // На сервере это может быть sender_id
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

  // Пример factory constructor для создания Message из JSON
  factory Message.fromJson(Map<String, dynamic> json) {
    String id = json['id'] ?? const Uuid().v4(); // Если сервер не шлет id, генерируем
    DateTime timestamp = json['timestamp'] != null
        ? DateTime.parse(json['timestamp']) // Если сервер шлет timestamp
        : DateTime.now(); // Иначе текущее время
    MessageType type = MessageType.values.firstWhere(
            (e) => e.toString().split('.').last == (json['type'] ?? 'text'),
        orElse: () => MessageType.text);

    return Message(
      id: id,
      sender: json['sender_id'] ?? json['sender'] ?? 'unknown_sender',
      content: json['content'] ?? '',
      type: type,
      timestamp: timestamp,
    );
  }
}