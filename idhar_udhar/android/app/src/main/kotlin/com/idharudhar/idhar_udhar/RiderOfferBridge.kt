package com.idharudhar.idhar_udhar

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Full-screen intent check and a user-opened notification-channel screen.
 * Nothing here runs unless the rider taps a settings action.
 */
object RiderOfferBridge {
    private const val CHANNEL = "com.idharudhar.rider/offer_alerts"
    private const val OFFER_CHANNEL_ID = "rider_incoming_offers_v1"

    @JvmStatic
    fun register(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canUseFullScreenIntent" -> result.success(canUse(context))
                    "openOfferChannelSettings" -> {
                        openChannelSettings(context)
                        result.success(true)
                    }
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

    private fun openChannelSettings(context: Context) {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                putExtra(Settings.EXTRA_CHANNEL_ID, OFFER_CHANNEL_ID)
            }
        } else {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            }
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }
}
