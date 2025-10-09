import 'message.dart';
import 'package:LangBridge/models/user_profile.dart';

class ChatParticipant {
  final String id;
  final String username;
  final String? avatarUrl;

  ChatParticipant({required this.id, required this.username, this.avatarUrl});

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      id: json['id'],
      username: json['username'],
      avatarUrl: json['avatar_url'],
    );
  }
}

class Chat {
  final String id;
  final String? title;
  final DateTime? createdAt;
  final List<Message>? initialMessages;
  final List<ChatParticipant> participants;

  Chat({
    required this.id,
    this.title,
    this.createdAt,
    this.initialMessages,
    required this.participants,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    var participantList = (json['participants'] as List<dynamic>?) ?? [];
    return Chat(
      id: json['id'] as String,
      title: json['title'] as String?,
      createdAt: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
      // initialMessages здесь не парсятся, предполагается, что они будут загружены позже
      // или переданы при подключении к WebSocket
      participants: participantList.map((p) => ChatParticipant.fromJson(p)).toList(),
    );
  }

  // copyWith может понадобиться для обновления состояния
  Chat copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    List<Message>? initialMessages,
    List<ChatParticipant>? participants,
  }) {
    return Chat(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      initialMessages: initialMessages ?? this.initialMessages,
      participants: participants ?? this.participants
    );
  }
}
