import 'message.dart';

class Chat {
  final String id;
  final String title;
  final List<Message> messages;

  Chat({
    required this.id,
    required this.title,
    this.messages = const [],
  });

  Chat copyWith({List<Message>? messages}) {
    return Chat(
      id: id,
      title: title,
      messages: messages ?? this.messages,
    );
  }
}