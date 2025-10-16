import 'dart:io';
import 'dart:async';
import 'package:LangBridge/screens/video_message_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

import '../models/chat.dart';
import '../models/message.dart';
import '../repositories/auth_repository.dart';
import '../repositories/chat_repository.dart';
import '../widgets/message_bubble.dart';

enum MediaRecordMode { audio, video }

class ChatScreen extends StatefulWidget {
  final Chat chat;
  final ChatRepository chatRepository;

  const ChatScreen({
    super.key,
    required this.chat,
    required this.chatRepository,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _soundRecorder = AudioRecorder();
  // final FlutterSoundRecorder _soundRecorder = FlutterSoundRecorder();

  String _currentUserId = '';

  MediaRecordMode _mediaRecordMode = MediaRecordMode.audio;
  bool _isRecording = false;
  bool _isRecordingLocked = false;
  Timer? _recordingTimer;
  int _recordingDurationSeconds = 0;
  bool _isActionCancelled = false;
  String? _recordingPath;

  bool _isPaused = false; // Состояние паузы
  double _dragOffset = 0.0; // Смещение пальца по вертикали
  bool _showCancelUI = false; // Показать UI "свайп для отмены"

  @override
  void initState() {
    super.initState();
    _initSoundRecorder();
    _loadCurrentUserAndConnect();
    _loadDraft();
    _textController.addListener(() => mounted ? setState(() {}) : null);
  }

  Future<void> _initSoundRecorder() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission not granted');
    }
    // await _soundRecorder.openRecorder();
  }

  @override
  void dispose() {
    _soundRecorder.dispose();
    _saveDraft(_textController.text);
    widget.chatRepository.disconnectFromChat();
    _textController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _startRecording() {
    // Сбрасываем все состояния перед началом
    setState(() {
      _isPaused = false;
      _isRecordingLocked = false;
      _isActionCancelled = false;
      _showCancelUI = false;
      _dragOffset = 0;
    });

    _performStartRecording().then((success) {
      if (success && mounted) {
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          // Таймер не тикает, если на паузе
          if (mounted && !_isPaused) setState(() => _recordingDurationSeconds++);
        });
      }
    });
  }

  Future<void> _togglePauseResume() async {
    if (_isPaused) {
      await _soundRecorder.resume();
    } else {
      await _soundRecorder.pause();
    }
    setState(() {
      _isPaused = !_isPaused;
    });
  }


  Future<bool> _performStartRecording() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _recordingPath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _soundRecorder.start(const RecordConfig(), path: _recordingPath!);
      // await _soundRecorder.start(
      //   toFile: _recordingPath,
      //   codec: Codec.aacMP4,
      // );

      if (mounted) {
        setState(() {
          _isRecording = true;
          _recordingDurationSeconds = 0;
        });
      }
      return true;
    } catch (e) {
      print("КРИТИЧЕСКАЯ ОШИБКА при старте записи: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка записи: ${e.toString()}")),
        );
      }
      return false;
    }
  }

  Future<void> _stopRecordingAndSend() async {
    // if (!_soundRecorder.isRecording) return;
    _recordingTimer?.cancel();
    final path = await _soundRecorder.stop();

    // Сбрасываем все состояния
    setState(() {
      _isRecording = false;
      _isRecordingLocked = false;
      _isPaused = false;
      _dragOffset = 0;
    });

    if (path != null && File(path).existsSync()) {
      await _sendMedia(path, MessageType.audio);
    }
  }


  Future<void> _cancelRecording() async {
    // if (!_soundRecorder.isRecording) return;
    _recordingTimer?.cancel();
    try {
      await _soundRecorder.stop();
    } catch (e) {
      print("Error stopping recorder on cancel: $e");
    }


    if (_recordingPath != null && File(_recordingPath!).existsSync()) {
      try {
        await File(_recordingPath!).delete();
      } catch (e) { print("Ошибка при удалении отмененного файла: $e"); }
    }

    // Сбрасываем все состояния
    setState(() {
      _isRecording = false;
      _isRecordingLocked = false;
      _isPaused = false;
      _dragOffset = 0;
    });
    print("Запись отменена.");
  }

  // --- ОСНОВНАЯ СТРУКТУРА ЭКРАНА ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.chat.title ?? "Чат")),
      body: Column(
        children: [
          Expanded(
            child: ValueListenableBuilder<List<Message>>(
              valueListenable: widget.chatRepository.messagesStream,
              builder: (context, messages, child) {
                if (messages.isEmpty) {
                  return const Center(child: Text("Нет сообщений."));
                }
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[messages.length - 1 - index];
                    return MessageBubble(
                      message: msg,
                      currentUserId: _currentUserId,
                      chatRepository: widget.chatRepository,
                    );
                  },
                );
              },
            ),
          ),
          // --- КЛЮЧЕВОЕ ИЗМЕНЕНИЕ: ВЫНОСИМ ВСЮ ПАНЕЛЬ ВВОДА ---
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final bool showSendButton = _textController.text.trim().isNotEmpty;
    // Максимальная дистанция свайпа вверх для блокировки
    const double lockThreshold = 80.0;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(8.0),
      child: Stack(
        clipBehavior: Clip.none, // Позволяет виджетам выходить за границы Stack
        children: [
          // --- Анимированный замок, который движется вверх ---
          if (_isRecording && !_isRecordingLocked)
            Positioned(
              right: 0,
              bottom: 48 + _dragOffset, // 48 - высота панели, _dragOffset - смещение пальца
              child: Opacity(
                opacity: (_dragOffset / lockThreshold).clamp(0.0, 1.0),
                child: Icon(
                  Icons.lock,
                  size: 24,
                  color: Colors.grey.shade600,
                ),
              ),
            ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file),
                onPressed: () { /* Логика вложений */ },
              ),

              // Основная область: поле ввода или UI записи
              Expanded(
                child: _isRecording
                    ? _buildRecordingUI()
                    : _buildTextComposer(),
              ),

              // --- "Умная" кнопка справа ---
              if (showSendButton && !_isRecording)
              // 1. Кнопка "Отправить" для текста
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  iconSize: 28,
                )
              else if (_isRecordingLocked)
              // 2. Если запись заблокирована, показываем кнопки паузы/отправки
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Кнопка Пауза/Продолжить
                    IconButton(
                      icon: Icon(_isPaused ? Icons.mic : Icons.pause),
                      color: Colors.blue,
                      onPressed: _togglePauseResume,
                      iconSize: 28,
                    ),
                    // Кнопка Отправить
                    IconButton(
                      icon: const Icon(Icons.send),
                      color: Colors.blue,
                      onPressed: _stopRecordingAndSend,
                      iconSize: 28,
                    ),
                  ],
                )
              else
              // 3. Главная кнопка для начала записи
                GestureDetector(
                  onTap: () => !_isRecording ? _toggleMediaRecordMode() : null,
                  onLongPressStart: (details) {
                    if (_isRecording) return;
                    print("Long press detected!");
                    if (_mediaRecordMode == MediaRecordMode.audio) {
                      _startRecording();
                    }
                  },
                  onLongPressEnd: (details) {
                    if (!_isRecording || _isRecordingLocked) return;
                    print("Long press up detected!");
                    if (_dragOffset >= lockThreshold) {
                      // Палец отпущен выше порога - блокируем
                      setState(() {
                        _isRecordingLocked = true;
                        _dragOffset = 0;
                      });
                    } else if (_showCancelUI) {
                      // Палец был в зоне отмены
                      _cancelRecording();
                    } else {
                      // Обычное отпускание - отправляем
                      _stopRecordingAndSend();
                    }
                    // Сбрасываем UI свайпа в любом случае
                    setState(() { _showCancelUI = false; });
                  },
                  onLongPressMoveUpdate: (details) {
                    if (!_isRecording || _isRecordingLocked) return;
                    final verticalOffset = details.localOffsetFromOrigin.dy;
                    final horizontalOffset = details.localOffsetFromOrigin.dx;

                    setState(() {
                      // Смещение вверх (отрицательное)
                      _dragOffset = -verticalOffset.clamp(-lockThreshold, 0.0);
                      // Показываем UI отмены при свайпе влево
                      _showCancelUI = horizontalOffset < -50;
                    });
                  },
                  behavior: HitTestBehavior.translucent,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Transform.scale(
                      scale: _isRecording ? 1.2 : 1.0, // Увеличиваем иконку во время записи
                      child: Icon(
                        _isRecording
                            ? Icons.mic
                            : (_mediaRecordMode == MediaRecordMode.audio ? Icons.mic : Icons.videocam),
                        color: _isRecording ? Colors.red : Theme.of(context).primaryColor,
                        size: 28,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // Виджет для поля ввода текста
  Widget _buildTextComposer() {
    return Container(
      key: const ValueKey('text-composer'),
      child: TextField(
        controller: _textController,
        decoration: const InputDecoration(
          hintText: "Сообщение",
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(20.0)),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Color.fromARGB(255, 236, 236, 236),
          contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        ),
        onSubmitted: (_) => _sendMessage(),
      ),
    );
  }


  Widget _buildRecordingUI() {
    final minutes = (_recordingDurationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordingDurationSeconds % 60).toString().padLeft(2, '0');

    // Анимация прозрачности для UI отмены
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _showCancelUI ? 0.0 : 1.0,
      child: Container(
        key: const ValueKey('recording-ui'),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            // "Мигающая" иконка или иконка паузы
            Icon(
              _isPaused ? Icons.pause : Icons.mic,
              color: Colors.red.withOpacity((_recordingDurationSeconds % 2) * 0.5 + 0.5),
            ),
            const SizedBox(width: 8),
            Text("$minutes:$seconds", style: const TextStyle(fontSize: 16)),
            const Spacer(),
            if (!_isRecordingLocked) // Показываем подсказку, только если запись не заблокирована
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, size: 18, color: Colors.grey),
                  Text(" Отмена | ", style: TextStyle(color: Colors.grey)),
                  Text("Вверх ", style: TextStyle(color: Colors.grey)),
                  Icon(Icons.lock, size: 16, color: Colors.grey),
                ],
              ),
            // Если запись заблокирована, показываем кнопку удаления
            if (_isRecordingLocked)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: _cancelRecording,
              ),
          ],
        ),
      ),
    );
  }

  void _toggleMediaRecordMode() {
    if (_isRecording) return;
    setState(() {
      _mediaRecordMode = _mediaRecordMode == MediaRecordMode.audio
          ? MediaRecordMode.video
          : MediaRecordMode.audio;
    });
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draft = prefs.getString('draft_${widget.chat.id}');
    if (draft != null) {
      _textController.text = draft;
    }
  }

  Future<void> _saveDraft(String text) async {
    final prefs = await SharedPreferences.getInstance();
    if (text.trim().isEmpty) {
      await prefs.remove('draft_${widget.chat.id}');
    } else {
      await prefs.setString('draft_${widget.chat.id}', text);
    }
  }

  Future<void> _sendMedia(String filePath, MessageType type) async {
    if (type == MessageType.audio) {
      await widget.chatRepository.sendAudioMessage(
        filePath: filePath,
        chatId: widget.chat.id,
        senderId: _currentUserId,
      );
    } else {
      await widget.chatRepository.sendVideoMessage(
        filePath: filePath,
        chatId: widget.chat.id,
        senderId: _currentUserId,
      );
    }
  }

  Future<void> _loadCurrentUserAndConnect() async {
    final userId = await AuthRepository.getCurrentUserId();
    if (userId != null) {
      setState(() {
        _currentUserId = userId;
      });
      widget.chatRepository.connectToChat(widget.chat);
    }
  }

  void _sendMessage() {
    if (_textController.text.trim().isEmpty) return;
    widget.chatRepository.sendChatMessage(
      sender: _currentUserId,
      content: _textController.text.trim(),
      type: MessageType.text,
    );
    _textController.clear();
    _saveDraft('');
  }
}
