import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'chat_socket_service.dart';

// Типы для callback'ов
typedef OnLocalStreamCallback = void Function(MediaStream stream);
typedef OnRemoteStreamCallback = void Function(MediaStream stream);
typedef OnCallEndCallback = void Function();

class WebRTCManager {
  final ChatSocketService socketService;
  final String selfId;
  final String chatId;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final List<RTCIceCandidate> _iceCandidateBuffer = [];

  bool isVideoEnabled = false;
  OnLocalStreamCallback? onLocalStream;
  OnRemoteStreamCallback? onRemoteStream;
  OnCallEndCallback? onCallEnded;
  bool isAudioEnabled = true;

  WebRTCManager({required this.socketService, required this.selfId, required this.chatId}) {
    if (kDebugMode) {
      print('[WebRTCManager][${TimeOfDay.now()}] Инициализирован для пользователя $selfId в чате $chatId');
    }
  }

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun.services.mozilla.com'},
      {'urls': 'stun:stun.xten.com'},
    ]
  };

  Future<void> initializeConnection() async {
    if (_peerConnection != null) {
        print('[WebRTCManager][${TimeOfDay.now()}] _peerConnection уже существует. Пропускаем инициализацию.');
      return;
    }
      print('[WebRTCManager][${TimeOfDay.now()}] -> initializeConnection: Создание RTCPeerConnection...');
    _peerConnection = await createPeerConnection(_iceServers);
    _registerPeerConnectionListeners();

      print('[WebRTCManager][${TimeOfDay.now()}] <- initializeConnection: RTCPeerConnection создан.');

    if (_iceCandidateBuffer.isNotEmpty) {
        print('[WebRTCManager][${TimeOfDay.now()}] Обнаружено ${_iceCandidateBuffer.length} ICE-кандидатов в буфере. Добавляем их...');
      for (final candidate in _iceCandidateBuffer) {
        await _peerConnection!.addCandidate(candidate);
      }
      _iceCandidateBuffer.clear();
    }
  }

  void _registerPeerConnectionListeners() {
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        print('[WebRTCManager][${TimeOfDay.now()}] !!! Найден локальный ICE-кандидат. Отправляем на сервер...');
      socketService.sendSignalingMessage({
        'type': 'ice_candidate',
        'sender_id': selfId,
        'candidate': candidate.toMap(),
      });
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
        print('[WebRTCManager][${TimeOfDay.now()}] !!! ПОЛУЧЕН УДАЛЕННЫЙ МЕДИА-ТРЕК (kind: ${event.track.kind})');
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        onRemoteStream?.call(_remoteStream!);
      }
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        print('[WebRTCManager][${TimeOfDay.now()}] Состояние соединения изменилось на: $state');
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        print('[WebRTCManager][${TimeOfDay.now()}] Состояние ICE соединения изменилось на: $state');
    };
  }

  Future<void> startLocalStream(bool isVideo) async {
    print('[WebRTCManager][${TimeOfDay.now()}] -> startLocalStream: Запрашиваем доступ к медиа (video: $isVideo)');
    isVideoEnabled = isVideo;
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': isVideo ? {'facingMode': 'user'} : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    print('[WebRTCManager][${TimeOfDay.now()}] <- startLocalStream: Локальный медиапоток получен. Добавляем треки в PeerConnection.');


    for (var track in _localStream!.getTracks()) {
      _peerConnection?.addTrack(track, _localStream!);
    }

    onLocalStream?.call(_localStream!);
  }

  Future<void> createOffer() async {
    if (_peerConnection == null) return;
    print('[WebRTCManager][${TimeOfDay.now()}] -> createOffer: Создаем SDP Offer...');
    RTCSessionDescription description = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': isVideoEnabled,
    });
    await _peerConnection!.setLocalDescription(description);

    print('[WebRTCManager][${TimeOfDay.now()}] <- createOffer: Offer создан и установлен как LocalDescription. Отправляем на сервер...');
    socketService.sendSignalingMessage({
      'type': 'call_offer',
      'sender_id': selfId,
      'sdp': description.toMap(),
    });
  }

  Future<void> handleOffer(Map<String, dynamic> sdpData) async {
    if (_peerConnection == null) return;
    print('[WebRTCManager][${TimeOfDay.now()}] -> handleOffer: Получен Offer. Устанавливаем как RemoteDescription...');
    RTCSessionDescription description = RTCSessionDescription(sdpData['sdp'], sdpData['type']);
    await _peerConnection!.setRemoteDescription(description);

    print('[WebRTCManager][${TimeOfDay.now()}] -> handleOffer: Создаем SDP Answer...');
    RTCSessionDescription answer = await _peerConnection!.createAnswer({});
    await _peerConnection!.setLocalDescription(answer);

    print('[WebRTCManager][${TimeOfDay.now()}] <- handleOffer: Answer создан и установлен как LocalDescription. Отправляем на сервер...');
    socketService.sendSignalingMessage({
      'type': 'call_answer',
      'sender_id': selfId,
      'sdp': answer.toMap(),
    });
  }

  Future<void> handleAnswer(Map<String, dynamic> sdpData) async {
    if (_peerConnection == null) return;
    print('[WebRTCManager][${TimeOfDay.now()}] -> handleAnswer: Получен Answer. Устанавливаем как RemoteDescription...');
    RTCSessionDescription description = RTCSessionDescription(sdpData['sdp'], sdpData['type']);
    await _peerConnection!.setRemoteDescription(description);
    print('[WebRTCManager][${TimeOfDay.now()}] <- handleAnswer: RemoteDescription установлен. Соединение должно установиться.');
  }

  Future<void> handleCandidate(Map<String, dynamic> candidateData) async {
    final candidate = RTCIceCandidate(
      candidateData['candidate'],
      candidateData['sdpMid'],
      candidateData['sdpMLineIndex'],
    );

    if (_peerConnection != null) {
      print('[WebRTCManager][${TimeOfDay.now()}] !!! Получен и добавлен удаленный ICE-кандидат.');
      await _peerConnection!.addCandidate(candidate);
    } else {
      print('[WebRTCManager][${TimeOfDay.now()}] !!! Получен удаленный ICE-кандидат, но PeerConnection еще не готов. БУФЕРИЗАЦИЯ.');
      _iceCandidateBuffer.add(candidate);
    }
  }

  void endCall() {
    print('[WebRTCManager][${TimeOfDay.now()}] -> endCall: Инициируем завершение звонка.');
    socketService.sendSignalingMessage({'type': 'call_end', 'sender_id': selfId});
    dispose();
  }

  void handleCallEnd() {
      print('[WebRTCManager][${TimeOfDay.now()}] -> handleCallEnd: Получен сигнал о завершении звонка от собеседника.');
    onCallEnded?.call();
    dispose();
  }

  void dispose() {
    print('[WebRTCManager][${TimeOfDay.now()}] XXX DISPOSE: Начинаем очистку ресурсов...');
    _iceCandidateBuffer.clear();

    _localStream?.getTracks().forEach((track) {
      track.stop();
      print('[WebRTCManager][${TimeOfDay.now()}] XXX DISPOSE: Локальный трек остановлен.');
    });
    _localStream?.dispose();
    _localStream = null;

    _remoteStream?.getTracks().forEach((track) {
      track.stop();
      print('[WebRTCManager][${TimeOfDay.now()}] XXX DISPOSE: Удаленный трек остановлен.');
    });
    _remoteStream?.dispose();
    _remoteStream = null;

    _peerConnection?.close();
    _peerConnection = null;
    print('[WebRTCManager][${TimeOfDay.now()}] XXX DISPOSE: Ресурсы WebRTC очищены.');
  }

  // Функции переключения камеры/микрофона без изменений
  void toggleMicrophone() { isAudioEnabled = !isAudioEnabled; _localStream?.getAudioTracks().forEach((track) { track.enabled = isAudioEnabled; }); }
  void toggleCamera() { isVideoEnabled = !isVideoEnabled; _localStream?.getVideoTracks().forEach((track) { track.enabled = isVideoEnabled; }); }
  void switchCamera() { if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) { Helper.switchCamera(_localStream!.getVideoTracks()[0]); } }
}
