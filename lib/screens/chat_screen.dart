import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:LangBridge/models/chat.dart';
import 'package:LangBridge/models/message.dart';
import 'package:LangBridge/repositories/auth_repository.dart';
import 'package:LangBridge/repositories/chat_repository.dart';
import 'package:LangBridge/screens/call_screen.dart';
import 'package:LangBridge/services/native_video_recorder.dart';
import 'package:LangBridge/services/webrtc_manager.dart';
import 'package:LangBridge/widgets/message_bubble.dart';
import 'package:LangBridge/widgets/recording_overlay.dart';

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
  String _currentUserId = '';
  MediaRecordMode _mediaRecordMode = MediaRecordMode.audio;
  bool _isRecording = false;
  bool _isRecordingLocked = false;
  Timer? _recordingTimer;
  int _recordingDurationSeconds = 0;
  bool _isActionCancelled = false;
  String? _recordingPath;
  bool _isPaused = false;
  double _dragOffset = 0.0;
  bool _showCancelUI = false;
  late WebRTCManager _webRTCManager;
  String _peerName = '';
  final Map<String, String> _userNicknamesCache = {};
  Message? _replyingToMessage;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _messageKeys = {};
  StreamSubscription? _recordingResultSubscription;

  @override
  void initState() {
    super.initState();
    NativeVideoRecorder.initialize();
    _recordingResultSubscription = NativeVideoRecorder.onRecordingResult.listen((segments) {
      if (segments != null && segments.isNotEmpty) {
        widget.chatRepository.sendVideoMessage(
          segments: segments,
          chatId: widget.chat.id,
          senderId: _currentUserId,
          replyToMessageId: _replyingToMessage?.id,
        );
        if (_replyingToMessage != null) {
          _cancelReply();
        }
      } else {
        print("Нативная запись (слушатель) не вернула сегментов.");
      }
    });
    _initScreen();
    _loadCurrentUserAndConnect();
    _textController.addListener(() => _saveDraft(_textController.text));
    widget.chatRepository.messagesStream.addListener(_generateMessageKeys);
  }

  Future<bool> _performStartVideoRecording() async {
    try {
      await NativeVideoRecorder.startRecording();
      print("Нативная запись видео начата.");
      if (mounted) {
        setState(() {
          _isRecording = true;
          _recordingDurationSeconds = 0;
        });
      }
      return true;
    } catch (e) {
      print("Ошибка старта нативной записи видео: $e");
      return false;
    }
  }

  void _onSignalingMessage() {
    final message = widget.chatRepository.chatSocketService.signalingMessageNotifier.value;
    _handleSignalingMessage(message);
  }

  Future<void> _initSoundRecorder() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission not granted');
    }
  }

  Future<void> _initScreen() async {
    await _loadCurrentUserAndConnect();

    if ((widget.chat.title == null || widget.chat.title!.isEmpty) && _currentUserId.isNotEmpty) {
      final otherParticipant = widget.chat.participants.firstWhere((p) => p.id != _currentUserId, orElse: () => widget.chat.participants.first);
      _peerName = otherParticipant.username;
    } else {
      _peerName = widget.chat.title ?? "Чат";
    }

    // Создаем WebRTCManager
    _webRTCManager = WebRTCManager(
      socketService: widget.chatRepository.chatSocketService,
      selfId: _currentUserId,
      chatId: widget.chat.id,
    );

    // Подписываемся на сигнальные сообщения
    widget.chatRepository.chatSocketService.signalingMessageNotifier.addListener(_onSignalingMessage);

    // Загружаем черновик и добавляем слушатель
    _loadDraft();
    _textController.addListener(() => mounted ? setState(() {}) : null);

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    print('[ChatScreen][${TimeOfDay.now()}] dispose: отписываемся от сигналов и очищаем ресурсы.');
    _recordingResultSubscription?.cancel();
    widget.chatRepository.messagesStream.removeListener(_generateMessageKeys);
    _scrollController.dispose();
    widget.chatRepository.chatSocketService.signalingMessageNotifier.removeListener(_onSignalingMessage);
    _webRTCManager.dispose();
    _soundRecorder.dispose();
    _saveDraft(_textController.text);
    widget.chatRepository.disconnectFromChat();
    _textController.dispose();
    super.dispose();
  }

  void _generateMessageKeys() {
    final messages = widget.chatRepository.messagesStream.value;
    for (final message in messages) {
      if (!_messageKeys.containsKey(message.id)) {
        _messageKeys[message.id] = GlobalKey();
      }
    }
    // Этот setState нужен, если ключи используются для чего-то, что требует перерисовки
    // В данном случае, для прокрутки, он не обязателен, но оставим для надежности
    if (mounted) setState(() {});
  }

  void _setReplyTo(Message message) {
    setState(() {
      _replyingToMessage = message;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingToMessage = null;
    });
  }

  void _scrollToMessage(String messageId) {
    final key = _messageKeys[messageId];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<String> _getNicknameForUser(String userId) async {
    // Если никнейм уже в кэше, возвращаем его немедленно
    if (_userNicknamesCache.containsKey(userId)) {
      return _userNicknamesCache[userId]!;
    }

    // Если в кэше нет, делаем запрос
    try {
      final userProfile = await widget.chatRepository.getUserProfile(userId);
      if (userProfile != null && userProfile.username.isNotEmpty) {
        // Сохраняем в кэш и возвращаем
        if (mounted) {
          setState(() {
            _userNicknamesCache[userId] = userProfile.username;
          });
        }
        return userProfile.username;
      }
    } catch (e) {
      print("Ошибка получения профиля для $userId: $e");
    }

    // В случае ошибки или если профиль не найден, возвращаем ID
    return userId;
  }

  void _handleSignalingMessage(Map<String, dynamic>? data) async {
    if (!mounted || data == null) return;

    final type = data['type'];
    print('[ChatScreen][${TimeOfDay.now()}] Получено сигнальное сообщение: type=$type');

    switch (type) {
      case 'call_offer':
        await _webRTCManager.initializeConnection();
        if (mounted) _showIncomingCallDialog(data);
        break;
      case 'call_answer':
        await _webRTCManager.handleAnswer(data['sdp']);
        break;
      case 'ice_candidate':
        await _webRTCManager.handleCandidate(data['candidate']);
        break;
      case 'call_end':
        _webRTCManager.handleCallEnd();
        break;
    }
  }

  void _startCall(bool isVideo) async {
    print('[ChatScreen][${TimeOfDay.now()}] -> _startCall: Начинаем ${isVideo ? "видео" : "аудио"}звонок...');
    var cameraStatus = await Permission.camera.request();
    var microphoneStatus = await Permission.microphone.request();

    if ((isVideo && !cameraStatus.isGranted) || !microphoneStatus.isGranted) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Для звонков необходим доступ к камере и микрофону.")));
      return;
    }

    print('[ChatScreen][${TimeOfDay.now()}] _startCall: Разрешения получены. Инициализируем PeerConnection...');
    await _webRTCManager.initializeConnection();
    _webRTCManager.isVideoEnabled = isVideo;

    print('[ChatScreen][${TimeOfDay.now()}] _startCall: Переход на CallScreen...');
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CallScreen(
        manager: _webRTCManager,
        isVideoCall: isVideo,
        peerName: _peerName,
        isInitiator: true,
      ),
    ));
  }

  void _showIncomingCallDialog(Map<String, dynamic> offerData) {
    print('[ChatScreen][${TimeOfDay.now()}] -> _showIncomingCallDialog: Показываем диалог входящего звонка.');
    final sdp = offerData['sdp']['sdp'] as String;
    final isVideoCall = sdp.contains("m=video");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text("Входящий ${isVideoCall ? 'видео' : 'аудио'}звонок от $_peerName"),
          actions: [
            TextButton(
              child: const Text("Отклонить"),
              onPressed: () {
                print('[ChatScreen][${TimeOfDay.now()}] Диалог: Пользователь отклонил звонок.');
                widget.chatRepository.chatSocketService.sendSignalingMessage({
                  'type': 'call_end',
                  'sender_id': _currentUserId,
                });
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text("Принять"),
              onPressed: () {
                print('[ChatScreen][${TimeOfDay.now()}] Диалог: Пользователь принял звонок. Переходим на CallScreen...');
                Navigator.of(context).pop(); // Закрываем диалог

                // Немедленно переходим на экран звонка, передавая ему все необходимое
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CallScreen(
                    manager: _webRTCManager,
                    isVideoCall: isVideoCall,
                    peerName: _peerName,
                    isInitiator: false, // Важно: это принимающая сторона
                    offerSdp: offerData['sdp'], // Передаем offer для обработки на экране звонка
                  ),
                ));
              },
            ),
          ],
        );
      },
    );
  }


  void _startRecording() {
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

  Future<void> _toggleMediaMode() async {
    // Если текущий режим - аудио, то мы хотим переключиться на видео
    if (_mediaRecordMode == MediaRecordMode.audio) {
      // Проверяем и запрашиваем разрешения
      final cameraStatus = await Permission.camera.request();
      final microphoneStatus = await Permission.microphone.request();

      if (cameraStatus.isGranted && microphoneStatus.isGranted) {
        // Если разрешения есть, меняем режим
        if (mounted) {
          setState(() {
            _mediaRecordMode = MediaRecordMode.video;
          });
        }
      } else {
        // Если разрешений нет, показываем сообщение и не меняем режим
        print("Разрешения для записи видео не предоставлены.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Для записи видео нужен доступ к камере и микрофону.")),
          );
        }
      }
    } else {
      // Если текущий режим - видео, просто переключаемся обратно на аудио
      if (mounted) {
        setState(() {
          _mediaRecordMode = MediaRecordMode.audio;
        });
      }
    }
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
    if (_mediaRecordMode == MediaRecordMode.audio) {
      return await _performStartAudioRecording();
    }
    else if (_mediaRecordMode == MediaRecordMode.video) {
      return await _performStartVideoRecording();
    }
    return false;
  }

  Future<bool> _performStartAudioRecording() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _recordingPath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _soundRecorder.start(const RecordConfig(), path: _recordingPath!);

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
    print("Stopping recording and sending for media type: $_mediaRecordMode");
    _recordingTimer?.cancel();

    if (_mediaRecordMode == MediaRecordMode.video) {
      // Для видео просто отправляем команду. Результат обработает StreamSubscription.
      await NativeVideoRecorder.stopRecording();
    } else if (_mediaRecordMode == MediaRecordMode.audio) {
      final path = await _soundRecorder.stop();
      if (path != null && File(path).existsSync()) {
        await _sendAudioMedia(path);
      }
    }

    // Общий сброс UI состояния в самом конце
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isRecordingLocked = false;
        _isPaused = false;
        _dragOffset = 0;
        _recordingPath = null;
      });
    }
  }

  Future<void> _cancelRecording() async {
    print("Cancelling recording for mode: $_mediaRecordMode");
    _recordingTimer?.cancel();

    if (_mediaRecordMode == MediaRecordMode.video) {
      await NativeVideoRecorder.cancelRecording();
      print("Нативная команда отмены записи видео отправлена.");
    } else {
      try {
        final path = await _soundRecorder.stop();
        final fileToDeletePath = path ?? _recordingPath;

        if (fileToDeletePath != null && File(fileToDeletePath).existsSync()) {
          try {
            await File(fileToDeletePath).delete();
            print("Отмененный аудиофайл удален: $fileToDeletePath");
          } catch (e) {
            print("Ошибка при удалении отмененного аудиофайла: $e");
          }
        }
      } catch (e) {
        print("Ошибка при остановке рекордера во время отмены: $e");
        if (_recordingPath != null && File(_recordingPath!).existsSync()) {
          try {
            await File(_recordingPath!).delete();
          } catch (delErr) {
            print("Повторная попытка удаления также не удалась: $delErr");
          }
        }
      }
    }

    // Общий сброс UI
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isRecordingLocked = false;
        _isPaused = false;
        _dragOffset = 0;
        _recordingPath = null;
      });
    }
    print("Запись отменена.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_peerName.isNotEmpty ? _peerName : (widget.chat.title ?? "Чат")),
        actions: [
          IconButton(onPressed: () => _startCall(false), icon: const Icon(Icons.call), tooltip: 'Аудиозвонок'),
          IconButton(onPressed: () => _startCall(true), icon: const Icon(Icons.videocam), tooltip: 'Видеозвонок'),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ValueListenableBuilder<List<Message>>(
                  valueListenable: widget.chatRepository.messagesStream,
                  builder: (context, messages, child) {
                    if (messages.isEmpty) {
                      return const Center(child: Text("Нет сообщений."));
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[messages.length - 1 - index];
                        return MessageBubble(
                          key: _messageKeys[msg.id]!,
                          message: msg,
                          currentUserId: _currentUserId,
                          chatRepository: widget.chatRepository,
                          nicknamesCache: _userNicknamesCache,
                          getNickname: _getNicknameForUser,
                          onReply: _setReplyTo,
                          onTapRepliedMessage: _scrollToMessage,
                        );
                      },
                    );
                  },
                ),
              ),
              if (!_isRecording && _replyingToMessage != null)
                _buildReplyPreview(),
              _buildInputArea(),
            ],
          ),
          if (_isRecording && _mediaRecordMode == MediaRecordMode.video)
            RecordingOverlay(
              recordingDurationSeconds: _recordingDurationSeconds,
              isRecordingLocked: _isRecordingLocked,
              isPaused: _isPaused,
              onCancel: _cancelRecording,
              onPauseResume: () {
                print("Пауза/возобновление видео пока не реализовано");
                // setState(() => _isPaused = !_isPaused);
              },
              onSend: _stopRecordingAndSend,
              onToggleCamera: () {
                NativeVideoRecorder.toggleCamera();
              },
              onToggleFlash: () {
                NativeVideoRecorder.toggleFlash();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview() {
    // Вспомогательная функция для получения текста-заглушки
    String getPlaceholderText(Message message) {
      switch (message.type) {
        case MessageType.audio: return "Голосовое сообщение";
        case MessageType.video: return "Видео";
        case MessageType.image: return "Изображение";
        default: return message.content;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        border: Border(left: BorderSide(color: Colors.blue, width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // Тут можно использовать getNickname, если нужен никнейм
                  _replyingToMessage!.sender == _currentUserId ? "Вы" : _peerName,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                const SizedBox(height: 2),
                Text(
                  getPlaceholderText(_replyingToMessage!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _cancelReply,
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final bool showSendButton = _textController.text.trim().isNotEmpty;
    // Максимальная дистанция свайпа вверх для блокировки
    const double lockThreshold = 80.0;

    if (_isRecordingLocked && _mediaRecordMode == MediaRecordMode.audio) {
      final durationString = '${(_recordingDurationSeconds ~/ 60).toString().padLeft(2, '0')}:${(_recordingDurationSeconds % 60).toString().padLeft(2, '0')}';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 28),
              onPressed: _cancelRecording,
            ),
            Text(durationString, style: const TextStyle(fontSize: 16)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(_isPaused ? Icons.mic : Icons.pause, color: Colors.blue, size: 28),
                  onPressed: _togglePauseResume,
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue, size: 28),
                  onPressed: _stopRecordingAndSend,
                ),
              ],
            )
          ],
        ),
      );
    }

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
                GestureDetector(
                  onTap: () => !_isRecording ? _toggleMediaMode() : null,
                  onLongPressStart: (details) {
                    if (_isRecording) return;
                    print("Long press detected for mode: $_mediaRecordMode");
                    _startRecording();
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

  Future<void> _sendAudioMedia(String path) async {
    if (_currentUserId.isEmpty || widget.chat.id.isEmpty) return;

    final replyId = _replyingToMessage?.id;

    await widget.chatRepository.sendAudioMessage(
      filePath: path,
      chatId: widget.chat.id,
      senderId: _currentUserId,
      replyToMessageId: replyId,
    );

    if (replyId != null) {
      _cancelReply();
    }
  }

  Future<void> _loadCurrentUserAndConnect() async {
    final userId = await AuthRepository.getCurrentUserId();
    if (!mounted || userId == null) return;

    setState(() {
      _currentUserId = userId;
    });

    if (widget.chat.unreadCount > 0) {
      widget.chatRepository.markChatAsRead(widget.chat.id);
    }

    await widget.chatRepository.connectToChat(widget.chat);
  }

  void _sendMessage() {
    if (_textController.text.trim().isEmpty) return;

    widget.chatRepository.sendChatMessage(
      sender: _currentUserId,
      content: _textController.text.trim(),
      type: MessageType.text,
      replyToMessageId: _replyingToMessage?.id,
    );

    _textController.clear();
    _saveDraft('');
    _cancelReply();
  }
}
