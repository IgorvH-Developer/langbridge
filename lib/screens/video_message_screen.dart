import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../l10n/app_localizations.dart';

class VideoMessageScreen extends StatefulWidget {
  const VideoMessageScreen({super.key});

  @override
  State<VideoMessageScreen> createState() => _VideoMessageScreenState();
}

class _VideoMessageScreenState extends State<VideoMessageScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isRecording = false;
  String? _videoPath;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    _cameraController =
        CameraController(_cameras!.first, ResolutionPreset.medium);
    await _cameraController!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || _isRecording) return;
    final dir = await getTemporaryDirectory();
    final filePath =
        path.join(dir.path, "${DateTime.now().millisecondsSinceEpoch}.mp4");
    await _cameraController!.startVideoRecording();
    setState(() {
      _isRecording = true;
      _videoPath = filePath;
    });
  }

  Future<void> _stopRecording() async {
    if (_cameraController == null || !_isRecording) return;
    final file = await _cameraController!.stopVideoRecording();
    setState(() {
      _isRecording = false;
      _videoPath = file.path;
    });
  }

  void _sendVideo() {
    if (_videoPath != null) {
      Navigator.pop(context, _videoPath);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.recordVideo)),
      body: Column(
        children: [
          Expanded(child: CameraPreview(_cameraController!)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon:
                    Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record),
                color: _isRecording ? Colors.red : Colors.black,
                iconSize: 40,
                onPressed: _isRecording ? _stopRecording : _startRecording,
              ),
              if (_videoPath != null)
                ElevatedButton(
                  onPressed: _sendVideo,
                  child: Text(l10n.send),
                ),
            ],
          )
        ],
      ),
    );
  }
}
