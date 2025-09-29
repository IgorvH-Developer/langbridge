import 'package:uuid/uuid.dart';
import '../models/chat.dart';
import '../models/message.dart';

class ChatRepository {
  final _uuid = const Uuid();

  // "Системный чат" с приложением
  final Chat _appChat = Chat(
    id: "app_chat",
    title: "Чат с приложением",
    messages: [
      Message(
        id: "welcome",
        sender: "app",
        content: "Привет! Это тестовый чат для обмена сообщениями 🚀",
        type: MessageType.text,
        timestamp: DateTime.now(),
      ),
    ],
  );

  Chat get appChat => _appChat;

  Chat addMessage(Chat chat, Message message) {
    final updatedMessages = List<Message>.from(chat.messages)..add(message);
    return chat.copyWith(messages: updatedMessages);
  }

  Message createMessage({
    required String sender,
    required String content,
    MessageType type = MessageType.text,
  }) {
    return Message(
      id: _uuid.v4(),
      sender: sender,
      content: content,
      type: type,
      timestamp: DateTime.now(),
    );
  }
}