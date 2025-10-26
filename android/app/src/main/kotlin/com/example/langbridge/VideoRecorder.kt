package com.example.langbridge

import android.annotation.SuppressLint
import android.content.Context
import android.hardware.camera2.*
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.util.Size
import android.view.Surface
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit

class VideoRecorder(private val context: Context, private val channel: MethodChannel) {
    private val TAG = "VideoRecorder"

    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private lateinit var previewSize: Size
    private var mediaRecorder: MediaRecorder? = null

    private val cameraThread = HandlerThread("CameraThread").apply { start() }
    private val cameraHandler = Handler(cameraThread.looper)
    private val cameraOpenCloseLock = Semaphore(1)

    private var isRecording = false
    private var currentCameraId: String = "1"
    private var isFlashOn = false

    private val videoSegments = mutableListOf<Map<String, Any>>()

    private val cameraManager by lazy { context.getSystemService(Context.CAMERA_SERVICE) as CameraManager }

    @SuppressLint("MissingPermission")
    fun startRecording() {
        if (isRecording) return
        Log.d(TAG, "startRecording called")
        videoSegments.clear()
        openCamera()
    }

    private fun openCamera() {
        try {
            if (!cameraOpenCloseLock.tryAcquire(2500, TimeUnit.MILLISECONDS)) {
                throw RuntimeException("Time out waiting to lock camera opening.")
            }
            cameraManager.openCamera(currentCameraId, deviceStateCallback, cameraHandler)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open camera", e)
            cameraOpenCloseLock.release()
        }
    }

    fun toggleCamera() {
        if (!isRecording) return
        Log.d(TAG, "Toggling camera...")

        // 1. Полностью останавливаем текущую сессию и закрываем камеру
        stopAndReleaseCurrentSession()

        // 2. Меняем ID камеры
        currentCameraId = if (currentCameraId == "1") "0" else "1"

        // 3. Открываем новую камеру. Это автоматически запустит новую сессию и запись.
        openCamera()
    }

    fun toggleFlash() {
        if (!isRecording || captureSession == null) return
        try {
            val characteristics = cameraManager.getCameraCharacteristics(currentCameraId)
            val hasFlash = characteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE)
            if (hasFlash == false) {
                Log.w(TAG, "Flash not available for this camera.")
                return
            }

            isFlashOn = !isFlashOn
            val builder = cameraDevice!!.createCaptureRequest(CameraDevice.TEMPLATE_RECORD)

            // Важно: нужно добавить все активные поверхности заново
            builder.addTarget(Surface(NativeVideoView.currentTextureView?.surfaceTexture))
            builder.addTarget(mediaRecorder!!.surface)

            if (isFlashOn) {
                builder.set(CaptureRequest.FLASH_MODE, CaptureRequest.FLASH_MODE_TORCH)
            } else {
                builder.set(CaptureRequest.FLASH_MODE, CaptureRequest.FLASH_MODE_OFF)
            }
            // Применяем обновленный запрос к текущей сессии
            captureSession?.setRepeatingRequest(builder.build(), null, cameraHandler)
            Log.d(TAG, "Flash toggled: ${if (isFlashOn) "ON" else "OFF"}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to toggle flash", e)
        }
    }

    fun stopRecordingAndSend() {
        if (!isRecording) return
        Log.d(TAG, "stopRecordingAndSend called")
        isRecording = false
        stopAndReleaseCurrentSession()

        if (videoSegments.isNotEmpty()) {
            Log.d(TAG, "Recording finished, sending segments: $videoSegments")
            channel.invokeMethod("onRecordingFinished", videoSegments)
        } else {
            Log.e(TAG, "No segments were recorded.")
            channel.invokeMethod("onRecordingFinished", null)
        }
    }

    fun cancelRecording() {
        if (!isRecording) return
        Log.d(TAG, "cancelRecording called")
        isRecording = false
        stopAndReleaseCurrentSession()

        // Очищаем временные файлы
        videoSegments.forEach { segment ->
            val path = segment["path"] as? String
            if (path != null) {
                val file = File(path)
                if (file.exists()) file.delete()
            }
        }
        videoSegments.clear()
        Log.d(TAG, "All segments deleted.")
    }

    private fun stopAndReleaseCurrentSession() {
        try {
            // Завершаем сессию и рекордер
            captureSession?.close() // Сначала закрываем сессию
            captureSession = null

            mediaRecorder?.stop()
            mediaRecorder?.reset()
            mediaRecorder?.release()
            mediaRecorder = null

            cameraDevice?.close() // <<< ГЛАВНОЕ: ВСЕГДА ЗАКРЫВАЕМ УСТРОЙСТВО КАМЕРЫ
            cameraDevice = null
        } catch (e: Exception) {
            Log.e(TAG, "Error during stopAndReleaseCurrentSession", e)
        }
    }

    private val deviceStateCallback = object : CameraDevice.StateCallback() {
        override fun onOpened(camera: CameraDevice) {
            Log.d(TAG, "Camera ${camera.id} opened")
            cameraDevice = camera
            createCaptureSession()
            cameraOpenCloseLock.release()
        }

        override fun onDisconnected(camera: CameraDevice) {
            Log.w(TAG, "Camera disconnected")
            cameraOpenCloseLock.release()
            camera.close()
            cameraDevice = null
        }

        override fun onError(camera: CameraDevice, error: Int) {
            Log.e(TAG, "Camera error: $error")
            cameraOpenCloseLock.release()
            camera.close()
            cameraDevice = null
        }
    }

    private fun createCaptureSession() {
        val textureView = NativeVideoView.currentTextureView
        if (textureView == null || !textureView.isAvailable) {
            Log.e(TAG, "TextureView is not available, aborting.")
            return
        }

        try {
            // 1. Настраиваем MediaRecorder
            val videoFile = File(context.cacheDir, "VID_SEGMENT_${System.currentTimeMillis()}.mp4")
            val rotation = getCorrectOrientationHint()

            mediaRecorder = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(context)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }).apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setVideoSource(MediaRecorder.VideoSource.SURFACE)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setOutputFile(videoFile.absolutePath)
                setVideoEncodingBitRate(1_500_000)
                setVideoFrameRate(30)
                setVideoSize(640, 480)
                setVideoEncoder(MediaRecorder.VideoEncoder.H264)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setOrientationHint(rotation) // <<-- КЛЮЧЕВОЕ ИСПРАВЛЕНИЕ
                prepare()
            }

            // Сохраняем информацию о сегменте
            val segmentInfo = mapOf("path" to videoFile.absolutePath, "rotation" to rotation)
            videoSegments.add(segmentInfo)

            // 2. Настраиваем поверхности
            val previewSurface = Surface(textureView.surfaceTexture)
            val recorderSurface = mediaRecorder!!.surface
            val surfaces = listOf(previewSurface, recorderSurface)

            // 3. Создаем сессию
            cameraDevice?.createCaptureSession(surfaces, object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(session: CameraCaptureSession) {
                    captureSession = session
                    val builder = cameraDevice!!.createCaptureRequest(CameraDevice.TEMPLATE_RECORD)
                    surfaces.forEach { builder.addTarget(it) }
                    session.setRepeatingRequest(builder.build(), null, cameraHandler)

                    // Начинаем запись
                    mediaRecorder?.start()
                    isRecording = true
                    Log.d(TAG, "Capture session configured and recording started.")
                }

                override fun onConfigureFailed(session: CameraCaptureSession) {
                    Log.e(TAG, "Capture session configuration failed.")
                }
            }, cameraHandler)

        } catch (e: Exception) {
            Log.e(TAG, "Error creating capture session", e)
        }
    }

    private fun getCorrectOrientationHint(): Int {
        val characteristics = cameraManager.getCameraCharacteristics(currentCameraId)
        val sensorOrientation = characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 0

        // Эта логика учитывает, что setOrientationHint просто записывает тег в EXIF,
        // который интерпретируется плеером.
        // Для задней камеры (сенсор 90), нам нужно повернуть на 90.
        // Для фронтальной (сенсор 270), нам нужно повернуть на 270.
        Log.d(TAG, "Camera $currentCameraId sensor orientation: $sensorOrientation. Setting hint.")
        return sensorOrientation
    }

    private fun getFrontCameraId(): String? {
        for (cameraId in cameraManager.cameraIdList) {
            val characteristics = cameraManager.getCameraCharacteristics(cameraId)
            if (characteristics.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_FRONT) {
                return cameraId
            }
        }
        return null
    }
}
