package cn.jokeo.mi_music

import android.content.Intent
import com.ryanheise.audioservice.AudioService
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "cn.jokeo.mi_music/audio_service_bootstrap",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAudioService" -> {
                    try {
                        startService(Intent(this, AudioService::class.java))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("START_AUDIO_SERVICE_FAILED", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
