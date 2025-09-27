import 'package:flutter/material.dart';
import 'screens/chat_screen.dart';
import 'screens/video_message_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Language Exchange App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const ChatScreen(),
        '/video': (context) => const VideoMessageScreen(),
      },
    );
  }
}
