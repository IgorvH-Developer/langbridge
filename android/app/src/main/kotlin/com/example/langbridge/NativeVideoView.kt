package com.example.langbridge

import android.content.Context
import android.graphics.SurfaceTexture
import android.util.Log
import android.view.TextureView
import android.view.View
import io.flutter.plugin.platform.PlatformView

internal class NativeVideoView(context: Context, private val videoRecorder: VideoRecorder?) : PlatformView {
    private val textureView: TextureView = TextureView(context)
    private val TAG = "NativeVideoView"

    override fun getView(): View {
        return textureView
    }

    override fun dispose() {
        Log.d(TAG, "Disposing TextureView and cleaning up reference.")
        // Очищаем ссылку при уничтожении
        if (currentTextureView === textureView) {
            currentTextureView = null
        }
    }

    init {
        // Устанавливаем статическую ссылку, чтобы VideoRecorder мог ее найти
        currentTextureView = textureView

        // --- ГЛАВНОЕ ИЗМЕНЕНИЕ ---
        // Добавляем слушатель, чтобы знать, когда поверхность готова к использованию
        textureView.surfaceTextureListener = object : TextureView.SurfaceTextureListener {
            override fun onSurfaceTextureAvailable(surface: SurfaceTexture, width: Int, height: Int) {
                Log.d(TAG, "SurfaceTexture is available. Triggering recording start.")
                // Теперь, когда View готово, мы даем команду VideoRecorder начать запись.
                videoRecorder?.startRecording()
            }

            override fun onSurfaceTextureSizeChanged(surface: SurfaceTexture, width: Int, height: Int) {
                // Пока не используется
            }

            override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean {
                Log.d(TAG, "SurfaceTexture is destroyed.")
                return true
            }

            override fun onSurfaceTextureUpdated(surface: SurfaceTexture) {
                // Вызывается на каждый новый кадр
            }
        }
    }

    companion object {
        // Статическая ссылка на текущий активный TextureView
        var currentTextureView: TextureView? = null
    }
}
