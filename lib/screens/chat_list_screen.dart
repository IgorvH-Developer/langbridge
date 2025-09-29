import 'package:flutter/material.dart';
import '../repositories/chat_repository.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  final ChatRepository chatRepository = ChatRepository();

  ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chats = [chatRepository.appChat];

    return Scaffold(
      appBar: AppBar(title: const Text("Чаты")),
      body: ListView.builder(
        itemCount: chats.length,
        itemBuilder: (context, index) {
          final chat = chats[index];
          return ListTile(
            title: Text(chat.title),
            subtitle: Text(
              chat.messages.isNotEmpty
                  ? chat.messages.last.content
                  : "Нет сообщений",
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    chat: chat,
                    chatRepository: chatRepository,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}