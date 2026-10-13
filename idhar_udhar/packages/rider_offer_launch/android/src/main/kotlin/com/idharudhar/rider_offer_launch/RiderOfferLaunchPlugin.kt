package com.idharudhar.rider_offer_launch

import android.app.ActivityManager
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Starts the existing Rider activity after Dart has posted the offer
 * notification. This runs only when that handler calls it, so it does not
 * race FlutterFire's foreground/background decision.
 */
class RiderOfferLaunchPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var context: Context
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "canDrawOverlays" -> result.success(canDrawOverOtherApps(context))
            "presentOffer" -> result.success(presentOffer(call.argument<String>("offerId")))
            else -> result.notImplemented()
        }
    }

    private fun presentOffer(rawOfferId: String?): Boolean {
        val offerId = rawOfferId?.trim().orEmpty()
        if (offerId.isEmpty()) {
            Log.i(TAG, "offer_activity_skipped_missing_id")
            return false
        }
        if (!canDrawOverOtherApps(context)) {
            Log.i(TAG, "offer_activity_skipped_overlay_not_granted")
            return false
        }
        if (riderUiIsOpen(context)) {
            Log.i(TAG, "offer_activity_skipped_already_open")
            return false
        }
        return try {
            val launch = Intent().apply {
                setClassName(context.packageName, MAIN_ACTIVITY)
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
                )
                putExtra(OFFER_ID_EXTRA, offerId)
            }
            context.startActivity(launch)
            Log.i(TAG, "offer_activity_started")
            true
        } catch (error: RuntimeException) {
            Log.w(TAG, "offer_activity_not_started")
            false
        }
    }

    private fun canDrawOverOtherApps(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }
        return Settings.canDrawOverlays(context)
    }

    private fun riderUiIsOpen(context: Context): Boolean {
        val keyguard = context.getSystemService(KeyguardManager::class.java)
        if (keyguard?.isKeyguardLocked == true) {
            return false
        }
        val activityManager = context.getSystemService(ActivityManager::class.java)
            ?: return false
        val processes = activityManager.runningAppProcesses ?: return false
        val packageName = context.packageName
        return processes.any { process ->
            process.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND &&
                process.processName == packageName
        }
    }

    private companion object {
        const val TAG = "RiderOfferLaunch"
        const val CHANNEL = "com.idharudhar.rider/offer_launch"
        const val OFFER_ID_EXTRA = "iu_offer_id"
        const val MAIN_ACTIVITY = "com.idharudhar.idhar_udhar.MainActivity"
    }
}
