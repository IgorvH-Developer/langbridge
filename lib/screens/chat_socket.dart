import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatSocket {
  late WebSocketChannel channel;

  void connect(String chatId) {
    channel = WebSocketChannel.connect(
      Uri.parse("ws://localhost:8000/ws/$chatId"),
    );

    channel.stream.listen((event) {
      final message = jsonDecode(event);
      print("Новое сообщение: $message");
      // Тут можно обновить UI или сохранить в Hive
    });
  }

  void sendMessage(String senderId, String content, {String type = "text"}) {
    final msg = {
      "sender_id": senderId,
      "content": content,
      "type": type,
    };
    channel.sink.add(jsonEncode(msg));
  }

  void disconnect() {
    channel.sink.close();
  }
}
