import 'message.dart';
import 'package:LangBridge/models/user_profile.dart';
import 'package:LangBridge/config/app_config.dart';

class ChatParticipant {
  final String id;
  final String username;
  final String? avatarUrl;

  ChatParticipant({required this.id, required this.username, this.avatarUrl});

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    String? rawAvatarUrl = json['avatar_url'];
    String? fullAvatarUrl;
    if (rawAvatarUrl != null && rawAvatarUrl.isNotEmpty) {
      fullAvatarUrl = rawAvatarUrl.startsWith('http')
          ? rawAvatarUrl
          : "${AppConfig.apiBaseUrl}$rawAvatarUrl";
    }

    return ChatParticipant(
      id: json['id'],
      username: json['username'],
      avatarUrl: fullAvatarUrl,
    );
  }
}


class Chat {
  final String id;
  final String? title;
  final DateTime? createdAt;
  final Message? lastMessage;
  final List<Message>? initialMessages;
  final List<ChatParticipant> participants;
  final int unreadCount;

  Chat({
    required this.id,
    this.title,
    this.createdAt,
    this.lastMessage,
    this.initialMessages,
    required this.participants,
    this.unreadCount = 0,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    var participantList = (json['participants'] as List<dynamic>?) ?? [];
    return Chat(
      id: json['id'] as String,
      title: json['title'] as String?,
      createdAt: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
      participants: participantList.map((p) => ChatParticipant.fromJson(p)).toList(),
      lastMessage: json['last_message'] != null
          ? Message.fromJson(json['last_message'])
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }

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
