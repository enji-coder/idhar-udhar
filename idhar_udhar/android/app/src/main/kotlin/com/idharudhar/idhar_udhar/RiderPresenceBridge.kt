package com.idharudhar.idhar_udhar

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Starts/stops [RiderOnlineService] while the Rider is Online so presence and
 * GPS keep updating after the Flutter UI is backgrounded.
 */
object RiderPresenceBridge {
    private const val CHANNEL = "com.idharudhar.rider/presence"

    @JvmStatic
    fun register(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startOnlinePresence" -> {
                        val token = call.argument<String>("accessToken").orEmpty().trim()
                        val baseUrl = call.argument<String>("baseUrl").orEmpty().trim()
                        if (token.isEmpty() || baseUrl.isEmpty()) {
                            result.error("invalid_args", "accessToken and baseUrl required", null)
                            return@setMethodCallHandler
                        }
                        val started = RiderOnlineService.start(
                            context.applicationContext,
                            token,
                            baseUrl,
                        )
                        result.success(started)
                    }
                    "updateOnlinePresenceAuth" -> {
                        val token = call.argument<String>("accessToken").orEmpty().trim()
                        val baseUrl = call.argument<String>("baseUrl").orEmpty().trim()
                        if (token.isEmpty() || baseUrl.isEmpty()) {
                            result.error("invalid_args", "accessToken and baseUrl required", null)
                            return@setMethodCallHandler
                        }
                        RiderOnlineService.updateAuth(context.applicationContext, token, baseUrl)
                        result.success(true)
                    }
                    "stopOnlinePresence" -> {
                        RiderOnlineService.stop(context.applicationContext)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
