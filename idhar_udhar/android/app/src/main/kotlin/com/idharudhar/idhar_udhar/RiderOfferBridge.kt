package com.idharudhar.idhar_udhar

import android.app.NotificationManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Read-only check for Android's full-screen intent access.
 * Opening the system setting stays in flutter_local_notifications.
 */
object RiderOfferBridge {
    private const val CHANNEL = "com.idharudhar.rider/offer_alerts"

    @JvmStatic
    fun register(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canUseFullScreenIntent" -> result.success(canUse(context))
                    else -> result.notImplemented()
                }
            }
    }

    private fun canUse(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return true
        }
        val manager = context.getSystemService(NotificationManager::class.java)
        return manager?.canUseFullScreenIntent() == true
    }
}
