package com.idharudhar.idhar_udhar

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import com.google.android.gms.auth.api.phone.SmsRetriever
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.common.api.Status
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Android SMS OTP helpers shared by Customer and Rider flavors.
 *
 * - [startRetriever]: silent SMS Retriever (no consent sheet). Requires the
 *   app hash in the SMS body.
 * - [startConsent]: SMS User Consent sheet (no inbox read). Works without hash.
 */
object OtpAutofillInstaller {
    private const val CHANNEL = "com.idharudhar.idhar_udhar/otp_autofill"
    private const val REQUEST = 4819

    private var channel: MethodChannel? = null
    private var receiver: BroadcastReceiver? = null

    @JvmStatic
    fun register(engine: FlutterEngine, host: FlutterActivity) {
        val messenger = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        channel = messenger
        messenger.setMethodCallHandler { call, result ->
            when (call.method) {
                "start", "startRetriever" -> {
                    try {
                        startRetriever(host)
                    } catch (_: Exception) {
                        stop(host)
                    }
                    result.success(null)
                }
                "startConsent" -> {
                    try {
                        startConsent(host)
                    } catch (_: Exception) {
                        stop(host)
                    }
                    result.success(null)
                }
                "stop" -> {
                    stop(host)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    @JvmStatic
    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) {
            return false
        }
        if (resultCode == Activity.RESULT_OK && data != null) {
            val message = data.getStringExtra(SmsRetriever.EXTRA_SMS_MESSAGE)
            if (message != null) {
                channel?.invokeMethod("onSms", message)
            }
        }
        return true
    }

    private fun startRetriever(host: FlutterActivity) {
        stop(host)
        val filter = IntentFilter(SmsRetriever.SMS_RETRIEVED_ACTION)
        val current = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (SmsRetriever.SMS_RETRIEVED_ACTION != intent.action) {
                    return
                }
                val extras = intent.extras ?: return
                val status = extras.get(SmsRetriever.EXTRA_STATUS) as? Status ?: return
                if (status.statusCode != CommonStatusCodes.SUCCESS) {
                    return
                }
                val message = extras.getString(SmsRetriever.EXTRA_SMS_MESSAGE) ?: return
                channel?.invokeMethod("onSms", message)
            }
        }
        receiver = current
        registerSmsReceiver(host, current, filter)
        SmsRetriever.getClient(host)
            .startSmsRetriever()
            .addOnFailureListener {
                // Play Services can reject. Manual OTP entry continues.
            }
    }

    private fun startConsent(host: FlutterActivity) {
        stop(host)
        val filter = IntentFilter(SmsRetriever.SMS_RETRIEVED_ACTION)
        val current = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (SmsRetriever.SMS_RETRIEVED_ACTION != intent.action) {
                    return
                }
                val extras = intent.extras ?: return
                val status = extras.get(SmsRetriever.EXTRA_STATUS) as? Status ?: return
                if (status.statusCode != CommonStatusCodes.SUCCESS) {
                    return
                }
                val consent = consentIntent(extras) ?: return
                host.startActivityForResult(consent, REQUEST)
            }
        }
        receiver = current
        registerSmsReceiver(host, current, filter)
        SmsRetriever.getClient(host)
            .startSmsUserConsent(null)
            .addOnFailureListener {
                // Play Services can reject consent. Manual entry still works.
            }
    }

    private fun registerSmsReceiver(
        host: FlutterActivity,
        current: BroadcastReceiver,
        filter: IntentFilter,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            host.registerReceiver(
                current,
                filter,
                SmsRetriever.SEND_PERMISSION,
                null,
                Context.RECEIVER_EXPORTED,
            )
        } else {
            host.registerReceiver(
                current,
                filter,
                SmsRetriever.SEND_PERMISSION,
                null,
            )
        }
    }

    private fun stop(host: FlutterActivity) {
        val current = receiver ?: return
        receiver = null
        try {
            host.unregisterReceiver(current)
        } catch (_: IllegalArgumentException) {
            // Already unregistered.
        }
    }

    private fun consentIntent(extras: Bundle): Intent? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            extras.getParcelable(SmsRetriever.EXTRA_CONSENT_INTENT, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            extras.getParcelable(SmsRetriever.EXTRA_CONSENT_INTENT)
        }
    }
}
