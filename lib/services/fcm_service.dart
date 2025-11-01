// lib/services/fcm_service.dart
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';

// Глобальный ключ для навигации без BuildContext
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Обработчик фоновых сообщений (должен быть функцией верхнего уровня)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
  // Здесь можно обработать данные, если нужно, но основная логика
  // будет при запуске приложения из уведомления.
}

class FcmService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final ApiService _apiService = ApiService();

  Future<void> init() async {
    // 1. Запрос разрешений
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    print('User granted permission: ${settings.authorizationStatus}');

    // 2. Получение FCM токена
    final fcmToken = await _fcm.getToken();
    print("FCM Token: $fcmToken");
    if (fcmToken != null) {
      // Мы пока не можем отправить токен, т.к. пользователь не авторизован.
      // Это нужно будет сделать после логина.
    }

    // 3. Настройка обработчиков
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Обработчик для сообщений, когда приложение в Foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        // Здесь можно показать локальное уведомление (In-App) или диалог
        // Например, для входящего звонка
        if (message.data['type'] == 'incoming_call') {
          // TODO: Показать диалог входящего звонка
        }
      }
    });

    // Обработчик для нажатия на уведомление, когда приложение было закрыто
    _fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleNotificationClick(message.data);
      }
    });

    // Обработчик для нажатия на уведомление, когда приложение в фоне
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message.data);
    });
  }

  void _handleNotificationClick(Map<String, dynamic> data) {
    print("Notification clicked with data: $data");
    final String? type = data['type'];

    if (type == 'new_message') {
      final String? chatId = data['chat_id'];
      if (chatId != null) {
        // TODO: Реализовать навигацию в чат с chatId
        // navigatorKey.currentState?.push(...);
        print("Navigate to chat: $chatId");
      }
    } else if (type == 'incoming_call') {
      final String? chatId = data['chat_id'];
      if (chatId != null) {
        // TODO: Навигация в чат, где будет показан диалог входящего звонка
        print("Navigate to chat $chatId to show incoming call UI");
      }
    }
  }

  // Метод для отправки токена на сервер
  Future<void> sendTokenToServer() async {
    final token = await _fcm.getToken();
    if (token != null) {
      try {
        await _apiService.updateFcmToken(token);
        print("FCM token successfully sent to server.");
      } catch (e) {
        print("Failed to send FCM token to server: $e");
      }
    }
  }
}
