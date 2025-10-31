// lib/widgets/message_bubble.dart
import 'package:flutter/material.dart';
import 'package:LangBridge/models/message.dart';
import 'package:LangBridge/repositories/chat_repository.dart';
import 'media_transcription_widget.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final String currentUserId;
  final ChatRepository chatRepository;
  final Map<String, String> nicknamesCache;
  final Future<String> Function(String userId) getNickname;
  final void Function(Message message) onReply;
  final void Function(String messageId) onTapRepliedMessage;
  final void Function(Message message) onTranslate;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.currentUserId,
    required this.chatRepository,
    required this.nicknamesCache,
    required this.getNickname,
    required this.onReply,
    required this.onTapRepliedMessage,
    required this.onTranslate,
  }) : super(key: key);

  Widget _buildRepliedMessage(BuildContext context) {
    if (message.repliedTo == null) return const SizedBox.shrink();

    final replied = message.repliedTo!;
    final isReplyToSelf = replied.senderId == currentUserId;

    String getPlaceholderText(RepliedMessageInfo message) {
      switch (message.type) {
        case MessageType.audio: return "Голосовое сообщение";
        case MessageType.video: return "Видео";
        case MessageType.image: return "Изображение";
        default: return message.content;
      }
    }

    return GestureDetector(
      onTap: () => onTapRepliedMessage(replied.id),
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 3, color: isReplyToSelf ? Colors.green : Colors.purple),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isReplyToSelf ? "Вы" : (nicknamesCache[replied.senderId] ?? replied.senderId),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isReplyToSelf ? Colors.green : Colors.purple
                      ),
                    ),
                    Text(
                      getPlaceholderText(replied),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == currentUserId;
    final isSystem = message.sender == "system";
    final bool canBeTranslated = (message.type == MessageType.text && message.content.isNotEmpty) || (message.transcription != null);


    // 1. Собираем "внутренности" пузыря в Column.
    final contentColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Показываем рамку ответа
        _buildRepliedMessage(context),

        // Показываем основной контент
        if (message.isTranslating)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else if (message.translatedContent != null)
          _buildTranslatedContent(isUser)
        else
          _buildOriginalContent(isUser),
      ],
    );

    // Создаем сам пузырь
    final bubble = GestureDetector(
        onDoubleTap: canBeTranslated ? () => onTranslate(message) : null,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Уменьшаем вертикальный padding
          decoration: BoxDecoration(
            color: isSystem ? Colors.amber.shade100 : (isUser ? Colors.blue.shade100 : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: contentColumn,
        )
    );

    // Собираем финальный виджет с Dismissible и выравниванием
    return Dismissible(
      key: ValueKey('dismiss_${message.id}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.2},
      confirmDismiss: (direction) async {
        onReply(message);
        return false;
      },
      background: Container(
        color: Colors.blue.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.reply, color: Colors.blue),
      ),
      child: Align(
        alignment: isSystem ? Alignment.center : (isUser ? Alignment.centerRight : Alignment.centerLeft),
        child: bubble,
      ),
    );
  }

  // Виджет для отображения времени и статуса отправки
  Widget _buildTimestampAndStatus() {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, top: 4.0), // Отступ слева от текста и сверху
      child: Row(
        mainAxisSize: MainAxisSize.min, // Уменьшаем размер до содержимого
        children: [
          Text(
            "${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}",
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          if (message.sender == currentUserId) ...[
            const SizedBox(width: 3),
            Icon(
              message.status == MessageStatus.sending
                  ? Icons.schedule // Часики для статуса "отправляется"
                  : Icons.done, // Галочка для "отправлено"
              size: 14,
              color: Colors.black54,
            ),
          ]
        ],
      ),
    );
  }

  // Строит контент для текстового сообщения (оригинал или перевод)
  Widget _buildTextContent(String text, {TextStyle? style}) {
    return Wrap(
      alignment: WrapAlignment.end, // Главное выравнивание - в конец строки
      crossAxisAlignment: WrapCrossAlignment.end, // Выравниваем элементы по нижнему краю
      children: [
        // Текст сообщения. Добавляем небольшой невидимый отступ справа, чтобы время не "прилипало"
        Padding(
          padding: const EdgeInsets.only(right: 4.0),
          child: Text(text, style: style),
        ),
        // Виджет времени, который встанет либо рядом, либо перенесется на новую строку
        _buildTimestampAndStatus(),
      ],
    );
  }

  // Виджет для отображения переведенного контента
  Widget _buildTranslatedContent(bool isUser) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Перевод всегда является текстом
        _buildTextContent(
          message.translatedContent!,
          style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87),
        ),
        const Divider(height: 8, thickness: 0.5),
        // Оригинал может быть текстом или медиа
        _buildOriginalContent(isUser, withTimestamp: false), // Показываем оригинал без времени
      ],
    );
  }

  // Виджет для отображения оригинального контента (текст или медиа)
  Widget _buildOriginalContent(bool isUser, {bool withTimestamp = true}) {
    if (message.type == MessageType.text) {
      // Если это текст, используем новый метод с Wrap
      return _buildTextContent(message.content);
    } else {
      // Если это медиа, время добавляется под виджетом
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          MediaTranscriptionWidget(
            message: message,
            chatRepository: chatRepository,
            isUser: isUser,
            key: ValueKey('${message.id}_transcription'),
          ),
          if (withTimestamp) // Показываем время только если это не часть перевода
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: _buildTimestampAndStatus(),
            ),
        ],
      );
    }
  }
}
