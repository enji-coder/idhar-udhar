package com.idharudhar.idhar_udhar

import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Full-screen intent check, the user-opened notification-channel screen,
 * and the offer id from a background activity launch.
 */
object RiderOfferBridge {
    private const val CHANNEL = "com.idharudhar.rider/offer_alerts"
    private const val OFFER_CHANNEL_ID = "rider_incoming_offers_v1"
    private const val RIDER_PACKAGE = "com.idharudhar.rider"
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
                    "setOfferScreenAwake" -> {
                        val awake = call.argument<Boolean>("awake") == true
                        setOfferScreenAwake(context, awake)
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

    /**
     * Lock-screen presentation for the Rider activity.
     *
     * API 27+ already declares showWhenLocked and turnScreenOn on the Rider
     * manifest. Older APIs ignore those attributes, so the same flags are
     * applied here. This does not grant full-screen-intent access: Android 14+
     * still requires the user to allow that special access, and a denied
     * full-screen intent stays a heads-up notification.
     */
    fun prepareIncomingOfferWindow(activity: Activity) {
        if (activity.packageName != RIDER_PACKAGE) {
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            activity.setShowWhenLocked(true)
            activity.setTurnScreenOn(true)
            return
        }
        @Suppress("DEPRECATION")
        activity.window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
        )
    }

    private fun setOfferScreenAwake(context: Context, awake: Boolean) {
        val activity = context as? Activity ?: return
        if (activity.packageName != RIDER_PACKAGE) {
            return
        }
        if (awake) {
            activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
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
