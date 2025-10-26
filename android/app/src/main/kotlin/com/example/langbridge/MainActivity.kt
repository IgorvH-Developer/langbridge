package com.example.langbridge

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val VIDEO_RECORDER_CHANNEL = "com.langbridge.app/video_recorder"
    private val VIDEO_PREVIEW_VIEW = "com.langbridge.app/video_preview"

    private var videoRecorder: VideoRecorder? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Создаем MethodChannel
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VIDEO_RECORDER_CHANNEL)

        // 2. Создаем VideoRecorder, передав ему канал
        videoRecorder = VideoRecorder(context, channel)

        // 3. Создаем фабрику, передав ей созданный VideoRecorder
        val videoPreviewFactory = VideoPreviewFactory(videoRecorder)

        // 4. Регистрируем фабрику
        flutterEngine.platformViewsController.registry.registerViewFactory(VIDEO_PREVIEW_VIEW, videoPreviewFactory)

        // 5. Настраиваем обработчик вызовов из Flutter
        channel.setMethodCallHandler { call, result ->
            // метод startRecording НЕ ВЫЗЫВАЕТ videoRecorder.startRecording() напрямую.
            // Он просто подтверждает получение команды. Фактический старт произойдет,
            // когда NativeVideoView будет готов.
            when (call.method) {
                "startRecording" -> {
                    result.success(null) // Просто подтверждаем, что команда принята
                }
                "stopRecording" -> {
                    videoRecorder?.stopRecordingAndSend()
                    result.success(null)
                }
                "cancelRecording" -> {
                    videoRecorder?.cancelRecording()
                    result.success(null)
                }
                "toggleCamera" -> {
                    videoRecorder?.toggleCamera()
                    result.success(null)
                }
                "toggleFlash" -> {
                    videoRecorder?.toggleFlash()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
