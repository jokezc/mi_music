package cn.jokeo.mi_music

import android.content.Context
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.InputStream
import java.util.Properties

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "cn.jokeo.mi_music/umeng_config"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getUmengConfig" -> {
                    val config = getUmengConfig(this)
                    if (config != null) {
                        val appKey = config.getProperty("umeng.appkey", "")
                        val channel = config.getProperty("umeng.channel", "")
                        // 即使配置文件存在，如果 AppKey 为空，也返回空值（表示未配置）
                        result.success(mapOf("appKey" to appKey, "channel" to channel))
                    } else {
                        // 配置文件不存在时，返回空值而不是错误（这是可选功能）
                        result.success(mapOf("appKey" to "", "channel" to ""))
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 友盟SDK初始化将在Flutter层完成
        // 这里不需要额外操作，因为Flutter插件会自动处理原生初始化
    }

    companion object {
        /**
         * 从assets读取友盟配置
         */
        fun getUmengConfig(context: Context): Properties? {
            return try {
                val inputStream: InputStream = context.assets.open("umeng_config.properties")
                val properties = Properties()
                properties.load(inputStream)
                inputStream.close()
                properties
            } catch (e: Exception) {
                null
            }
        }
    }
}
