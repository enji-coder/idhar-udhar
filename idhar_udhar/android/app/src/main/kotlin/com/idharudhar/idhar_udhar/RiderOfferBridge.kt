package com.idharudhar.idhar_udhar

import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Full-screen intent check, the user-opened notification-channel screen,
 * and the offer id from a background activity launch.
 */
object RiderOfferBridge {
    private const val CHANNEL = "com.idharudhar.rider/offer_alerts"
    private const val OFFER_CHANNEL_ID = "rider_incoming_offers_v1"
    const val OFFER_ID_EXTRA = "iu_offer_id"

    @JvmStatic
    fun register(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canUseFullScreenIntent" -> result.success(canUse(context))
                    "consumeLaunchOfferId" ->
                        result.success((context as? Activity)?.let(::consumeLaunchOfferId))
                    "openOfferChannelSettings" -> {
                        openChannelSettings(context)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun consumeLaunchOfferId(activity: Activity): String? {
        val id = activity.intent?.getStringExtra(OFFER_ID_EXTRA)?.trim().orEmpty()
        if (id.isEmpty()) {
            return null
        }
        activity.intent?.removeExtra(OFFER_ID_EXTRA)
        return id
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
