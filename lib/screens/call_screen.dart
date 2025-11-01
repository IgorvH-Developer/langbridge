import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../l10n/app_localizations.dart';
import '../services/webrtc_manager.dart';

class CallScreen extends StatefulWidget {
  final WebRTCManager manager;
  final bool isVideoCall;
  final String peerName;
  final bool isInitiator;
  final Map<String, dynamic>? offerSdp; // Для получателя звонка

  const CallScreen({
    super.key,
    required this.manager,
    required this.isVideoCall,
    required this.peerName,
    required this.isInitiator,
    this.offerSdp,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  String _status = "Соединение...";

  bool _isMicrophoneEnabled = true;
  bool _isCameraEnabled = true;
  bool _isSpeakerEnabled = true;

  @override
  void initState() {
    super.initState();
    _isCameraEnabled = widget.isVideoCall;

    _localRenderer.initialize();
    _remoteRenderer.initialize();

    widget.manager.onLocalStream = (stream) {
      if (mounted) {
        setState(() => _localRenderer.srcObject = stream);
      }
    };
    widget.manager.onRemoteStream = (stream) {
      if (mounted) {
        setState(() {
          _remoteRenderer.srcObject = stream;
          _status = "Соединено";
        });
      }
    };
    widget.manager.onCallEnded = () {
      if (mounted) Navigator.of(context).pop();
    };

    _initializeCall();
  }

  Future<void> _initializeCall() async {
    final l10n = AppLocalizations.of(context)!;

    // Запрашиваем разрешения
    var cameraStatus = await Permission.camera.request();
    var microphoneStatus = await Permission.microphone.request();

    if (!mounted) return;

    if ((widget.isVideoCall && !cameraStatus.isGranted) || !microphoneStatus.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.noPermissionToCall)));
      widget.manager.endCall(); // Завершаем звонок, если нет разрешений
      return;
    }

    if (widget.isInitiator) {
      // Инициатор: захватываем поток и создаем offer
      await widget.manager.startLocalStream(widget.isVideoCall);
      await widget.manager.createOffer();
    } else {
      // Получатель: захватываем поток и обрабатываем offer
      await widget.manager.startLocalStream(widget.isVideoCall);
      if (widget.offerSdp != null) {
        await widget.manager.handleOffer(widget.offerSdp!);
      }
    }
  }

  @override
  void dispose() {
    // Важно вызывать endCall ПЕРЕД dispose рендереров.
    widget.manager.endCall();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    widget.manager.onLocalStream = null;
    widget.manager.onRemoteStream = null;
    widget.manager.onCallEnded = null;
    super.dispose();
  }

  void _endCall() {
    widget.manager.endCall();
    if (mounted) Navigator.of(context).pop();
  }

  // Методы для переключения микрофона, камеры и т.д.
  void _toggleMicrophone() => setState(() {
    _isMicrophoneEnabled = !_isMicrophoneEnabled;
    widget.manager.toggleMicrophone();
  });

  void _toggleCamera() => setState(() {
    _isCameraEnabled = !_isCameraEnabled;
    widget.manager.toggleCamera();
  });

  void _switchCamera() => widget.manager.switchCamera();

  void _toggleSpeaker() => setState(() {
    _isSpeakerEnabled = !_isSpeakerEnabled;
    // TODO: Добавить логику переключения на динамик/наушники
  });


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Stack(
          children: [
            // Удаленное видео (на весь экран)
            if (widget.isVideoCall && _remoteRenderer.srcObject != null)
              RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),

            // Локальное видео (в углу)
            if (widget.isVideoCall)
              Positioned(
                top: 20,
                right: 20,
                child: SizedBox(
                  width: 100,
                  height: 150,
                  child: RTCVideoView(_localRenderer, mirror: true),
                ),
              ),

            // UI звонка
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHeader(),
                // Если не видеозвонок, показываем аватар в центре
                if (!widget.isVideoCall)
                  Expanded(
                      child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
                              const SizedBox(height: 16),
                              Text(widget.peerName, style: const TextStyle(color: Colors.white, fontSize: 24)),
                            ],
                          )
                      )
                  ),
                _buildControls(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Text(
            widget.peerName,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _status,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildControlButton(
            onPressed: _toggleMicrophone,
            icon: _isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
            color: _isMicrophoneEnabled ? Colors.white : Colors.red,
          ),
          if (widget.isVideoCall)
            _buildControlButton(
              onPressed: _toggleCamera,
              icon: _isCameraEnabled ? Icons.videocam : Icons.videocam_off,
              color: _isCameraEnabled ? Colors.white : Colors.red,
            ),
          if (widget.isVideoCall)
            _buildControlButton(
              onPressed: _switchCamera,
              icon: Icons.switch_camera,
            ),
          _buildControlButton(
            onPressed: _toggleSpeaker,
            icon: _isSpeakerEnabled ? Icons.volume_up : Icons.volume_down,
          ),
          _buildControlButton(
            onPressed: _endCall,
            icon: Icons.call_end,
            color: Colors.white,
            backgroundColor: Colors.red,
            size: 35,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required VoidCallback onPressed,
    required IconData icon,
    Color color = Colors.white,
    Color backgroundColor = Colors.white24,
    double size = 30,
  }) {
    return FloatingActionButton(
      heroTag: icon.toString(), // Уникальный heroTag для каждой кнопки
      onPressed: onPressed,
      backgroundColor: backgroundColor,
      mini: true,
      child: Icon(icon, color: color, size: size * 0.7),
    );
  }
}
