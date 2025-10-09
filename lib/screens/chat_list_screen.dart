// lib/screens/chat_list_screen.dart
import 'package:flutter/material.dart';
import '../repositories/chat_repository.dart';
import 'chat_screen.dart';
import '../models/chat.dart'; // Импорт модели Chat
import '../repositories/auth_repository.dart'; // <<< ДОБАВЛЕН ИМПОРТ

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  // Получаем ChatRepository. Можно через Provider или создать экземпляр.
  // Для простоты примера создадим здесь, но лучше использовать DI/Provider.
  final ChatRepository _chatRepository = ChatRepository();
  bool _isLoading = true;
  String? _currentUserId; // <<< ДОБАВЛЕНО ПОЛЕ ДЛЯ ID ПОЛЬЗОВАТЕЛЯ

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  // <<< МЕТОД ОБНОВЛЕН ДЛЯ ЗАГРУЗКИ ID ПОЛЬЗОВАТЕЛЯ
  Future<void> _loadChats() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    // Одновременно запрашиваем ID пользователя и чаты для ускорения
    final userIdFuture = AuthRepository.getCurrentUserId();
    final fetchChatsFuture = _chatRepository.fetchChats();

    // Дожидаемся обоих результатов
    final userId = await userIdFuture;
    await fetchChatsFuture;

    if (mounted) {
      setState(() {
        _currentUserId = userId;
        _isLoading = false;
      });
    }
  }

  void _showCreateChatDialog() {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Создать новый чат"),
          content: TextField(
            controller: titleController,
            decoration: const InputDecoration(hintText: "Название чата"),
            autofocus: true,
          ),
          actions: [
            TextButton(
              child: const Text("Отмена"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("Создать"),
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isNotEmpty) {
                  Navigator.of(context).pop(); // Закрыть диалог
                  final newChat = await _chatRepository.createNewChat(title);
                  if (newChat != null) {
                    // Опционально: сразу перейти в новый чат
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (_) => ChatScreen(
                    //       chat: newChat,
                    //       chatRepository: _chatRepository,
                    //     ),
                    //   ),
                    // );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Чат '${newChat.title}' создан!")),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Не удалось создать чат.")),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Чаты"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder<List<Chat>>(
        valueListenable: _chatRepository.chatsStream,
        builder: (context, chats, child) {
          if (chats.isEmpty) {
            return const Center(
              child: Text("Нет доступных чатов. Создайте новый!"),
            );
          }
          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              String displayTitle;
              // Если у чата есть название, используем его.
              if (chat.title != null && chat.title!.isNotEmpty) {
                displayTitle = chat.title!;
              } else {
                // Иначе, это личный чат. Ищем собеседников.
                final otherParticipants = chat.participants.where((p) => p.id != _currentUserId);
                if (otherParticipants.isNotEmpty) {
                  // Отображаем имена всех других участников через запятую.
                  displayTitle = otherParticipants.map((p) => p.username).join(', ');
                } else {
                  // Запасной вариант, если в чате нет других участников.
                  displayTitle = "Чат";
                }
              }
              // <<< КОНЕЦ ИЗМЕНЕНИЙ

              return ListTile(
                title: Text(displayTitle), // ИСПРАВЛЕНО
                subtitle: Text("ID: ${chat.id.substring(0,8)}..."), // Показываем часть ID
                onTap: () {
                  // Перед переходом в ChatScreen, убеждаемся, что chat.id есть
                  // и передаем его для подключения к WebSocket
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        chat: chat, // Передаем весь объект Chat
                        chatRepository: _chatRepository,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateChatDialog,
        tooltip: 'Создать чат',
        child: const Icon(Icons.add),
      ),
    );
  }
}
