import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:LangBridge/repositories/chat_repository.dart';
import 'package:LangBridge/models/message.dart';
import 'package:LangBridge/screens/chat_screen.dart';
import 'package:LangBridge/models/chat.dart';
import 'package:LangBridge/repositories/auth_repository.dart';
import 'package:LangBridge/l10n/app_localizations.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatRepository _chatRepository = ChatRepository();
  bool _isLoading = true;
  String? _currentUserId;
  // --- НОВОЕ ПОЛЕ: ХРАНИМ ЧАТЫ И ИХ ЧЕРНОВИКИ ---
  Map<String, String> _drafts = {};
  List<Chat> _chats = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final userId = await AuthRepository.getCurrentUserId();
    await _chatRepository.fetchChats(); // Загружаем чаты из репозитория
    final drafts = await _loadAllDrafts(); // Загружаем все черновики

    if (mounted) {
      setState(() {
        _currentUserId = userId;
        // Слушаем изменения в репозитории
        _chats = _chatRepository.chatsStream.value;
        _drafts = drafts;
        _isLoading = false;
      });
      // Подписываемся на будущие обновления
      _chatRepository.chatsStream.addListener(_updateChats);
    }
  }

  // --- НОВЫЙ МЕТОД ДЛЯ ОБНОВЛЕНИЯ ЧАТОВ ---
  void _updateChats() {
    if(mounted) {
      setState(() {
        _chats = _chatRepository.chatsStream.value;
      });
    }
  }

  // --- НОВЫЙ МЕТОД ДЛЯ ЗАГРУЗКИ ЧЕРНОВИКОВ ---
  Future<Map<String, String>> _loadAllDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final drafts = <String, String>{};
    for (String key in keys) {
      if (key.startsWith('draft_')) {
        drafts[key] = prefs.getString(key) ?? '';
      }
    }
    return drafts;
  }

  @override
  void dispose() {
    _chatRepository.chatsStream.removeListener(_updateChats);
    super.dispose();
  }

  // --- ОСНОВНОЙ МЕТОД BUILD ---
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chats),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
          ? Center(child: Text(l10n.youDontHaveChatsYet))
          : ListView.builder(itemCount: _chats.length,
        itemBuilder: (context, index) {
          final chat = _chats[index];
          final draft = _drafts['draft_${chat.id}'];
          final displayData = _getDisplayData(chat, _currentUserId);
          final bool hasUnread = chat.unreadCount > 0;

          return ListTile(
            tileColor: hasUnread ? Colors.blue.withOpacity(0.05) : null,
            leading: CircleAvatar(
              radius: 28,
              backgroundImage: displayData.avatarUrl != null
                  ? NetworkImage(displayData.avatarUrl!)
                  : null,
              child: displayData.avatarUrl == null
                  ? Icon(displayData.isPrivateChat ? Icons.person : Icons.group)
                  : null,
            ),
            title: Text(
              displayData.title,
              style: TextStyle(
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: _buildSubtitle(draft, chat.lastMessage),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  chat.lastMessage != null
                      ? DateFormat('HH:mm').format(chat.lastMessage!.timestamp)
                      : '',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                if (hasUnread) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      chat.unreadCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ]
              ],
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    chat: chat,
                    chatRepository: _chatRepository,
                  ),
                ),
              );
              final updatedDrafts = await _loadAllDrafts();
              if (mounted) setState(() => _drafts = updatedDrafts);
            },
          );
        },
      ),
    );
  }

  // --- ВСПОМОГАТЕЛЬНЫЙ ВИДЖЕТ ДЛЯ SUBTITLE ---
  Widget _buildSubtitle(String? draft, Message? lastMessage) {
    final l10n = AppLocalizations.of(context)!;

    if (draft != null && draft.isNotEmpty) {
      return Row(
        children: [
          Text("[${l10n.draft}] ", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              draft,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ],
      );
    }

    // 2. Если нет последнего сообщения
    if (lastMessage == null) {
      return Text(l10n.noMessages, style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey));
    }

    // 3. Определяем контент в зависимости от типа сообщения
    String content;
    switch (lastMessage.type) {
      case MessageType.video:
        content = "Видеосообщение";
        break;
      case MessageType.audio: // На будущее, если добавите аудио
        content = "Голосовое сообщение";
        break;
      case MessageType.text:
      default:
        content = lastMessage.content;
        break;
    }

    // 4. Возвращаем простой текст без префиксов
    return Text(
      content,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Colors.grey), // Делаем текст серым для лучшего вида
    );
  }

  // --- ВСПОМОГАТЕЛЬНЫЙ МЕТОД ДЛЯ ПОЛУЧЕНИЯ ДАННЫХ ЧАТА ---
  _ChatDisplayData _getDisplayData(Chat chat, String? currentUserId) {
    bool isPrivateChat = chat.title == null || chat.title!.isEmpty;
    String title;
    String? avatarUrl;

    if (isPrivateChat) {
      final otherParticipant = chat.participants.firstWhere(
            (p) => p.id != currentUserId,
        orElse: () => chat.participants.first, // На случай чата с самим собой
      );
      title = otherParticipant.username;
      if (otherParticipant.avatarUrl != null && otherParticipant.avatarUrl!.isNotEmpty) {
        avatarUrl = otherParticipant.avatarUrl!; // URL уже полный из модели UserProfile
      }
    } else {
      title = chat.title!;
      // Логика для аватара группы (пока нет)
    }

    return _ChatDisplayData(title: title, avatarUrl: avatarUrl, isPrivateChat: isPrivateChat);
  }
}

class _ChatDisplayData {
  final String title;
  final String? avatarUrl;
  final bool isPrivateChat;

  _ChatDisplayData({required this.title, this.avatarUrl, required this.isPrivateChat});
}
