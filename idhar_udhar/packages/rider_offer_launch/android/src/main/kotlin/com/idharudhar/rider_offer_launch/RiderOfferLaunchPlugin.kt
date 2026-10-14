package com.idharudhar.rider_offer_launch

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
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
            // This plugin is registered on the FCM background isolate.
            // RiderOfferBridge is activity-scoped and is not available there.
            "startOfferAlert" -> result.success(
                OfferAlertAudio.start(
                    context,
                    call.argument<String>("offerId"),
                    call.argument<Number>("expiresAtMillis")?.toLong(),
                ),
            )
            "stopOfferAlert" -> {
                OfferAlertAudio.stop(call.argument<String>("offerId"))
                result.success(true)
            }
            "playOfferTick" -> {
                OfferAlertAudio.tick(context)
                result.success(true)
            }
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
        // Always deliver iu_offer_id via startActivity. Skipping when the
        // process looked "foreground" dropped the offer id and, with FSI off,
        // left only a heads-up — no dialog. singleTop + onNewIntent handles
        // an already-visible MainActivity.
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
            Log.w(TAG, "offer_activity_not_started", error)
            false
        }
    }

    private fun canDrawOverOtherApps(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }
        return Settings.canDrawOverlays(context)
    }

    private companion object {
        const val TAG = "RiderOfferLaunch"
        const val CHANNEL = "com.idharudhar.rider/offer_launch"
        const val OFFER_ID_EXTRA = "iu_offer_id"
        const val MAIN_ACTIVITY = "com.idharudhar.idhar_udhar.MainActivity"
    }
}

/**
 * Repeated tring for one offer, plus a short countdown tick.
 *
 * Uses the ring stream, so silent mode, vibrate mode, and Do Not Disturb
 * are honored. This does not raise the system volume and does not request
 * notification-policy access.
 */
private object OfferAlertAudio {
    private val main = Handler(Looper.getMainLooper())
    private val lock = Any()
    private var appContext: Context? = null
    private var offerId: String? = null
    private var expiresAtMillis: Long = 0L
    private var running = false
    private var pausedForFocus = false
    private var loggedSuppressed = false
    private var lastTringAt = 0L
    private var ringTone: ToneGenerator? = null
    private var tickTone: ToneGenerator? = null
    private var focusRequest: AudioFocusRequest? = null
    private var audioManager: AudioManager? = null

    private val loop = object : Runnable {
        override fun run() {
            val active = synchronized(lock) { running }
            if (!active) {
                return
            }
            val context = appContext
            if (context == null || expired()) {
                stop(null)
                return
            }
            if (!pausedForFocus) {
                tring(context)
            }
            main.postDelayed(this, 1700L)
        }
    }

    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        pausedForFocus = change == AudioManager.AUDIOFOCUS_LOSS ||
            change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT
    }

    fun start(context: Context, rawOfferId: String?, expiresAt: Long?): Boolean {
        val id = rawOfferId?.trim().orEmpty()
        if (id.isEmpty()) {
            return false
        }
        val now = System.currentTimeMillis()
        if (expiresAt != null && expiresAt <= now) {
            Log.i(TAG, "offer_sound_skipped_expired")
            return false
        }
        synchronized(lock) {
            if (running && offerId == id) {
                return true
            }
        }
        haltPlayback()
        val app = context.applicationContext
        synchronized(lock) {
            appContext = app
            offerId = id
            expiresAtMillis = expiresAt ?: (now + SAFETY_CAP_MS)
            running = true
            pausedForFocus = false
            loggedSuppressed = false
        }
        requestFocus(app)
        // Let a one-shot notification sound finish before the first tring.
        main.postDelayed(loop, 450L)
        Log.i(TAG, "offer_sound_started")
        return true
    }

    fun stop(rawOfferId: String?) {
        val requested = rawOfferId?.trim().orEmpty()
        synchronized(lock) {
            if (!running) {
                return
            }
            if (requested.isNotEmpty() && offerId != requested) {
                return
            }
        }
        haltPlayback()
        Log.i(TAG, "offer_sound_stopped")
    }

    private fun haltPlayback() {
        val context = synchronized(lock) {
            running = false
            offerId = null
            appContext
        }
        main.removeCallbacksAndMessages(null)
        releaseTones()
        abandonFocus(context)
    }

    fun tick(context: Context) {
        main.post {
            if (!soundAllowed(context.applicationContext)) {
                return@post
            }
            if (SystemClock.elapsedRealtime() - lastTringAt < 350L) {
                return@post
            }
            tone(tick = true)?.startTone(ToneGenerator.TONE_PROP_BEEP, 40)
        }
    }

    private fun tring(context: Context) {
        val allowSound = soundAllowed(context)
        val allowVibrate = vibrateAllowed(context)
        if (!allowSound && !allowVibrate) {
            if (!loggedSuppressed) {
                loggedSuppressed = true
                Log.i(TAG, "offer_sound_suppressed_ringer_or_dnd")
            }
            return
        }
        lastTringAt = SystemClock.elapsedRealtime()
        if (allowSound) {
            val generator = tone(tick = false)
            generator?.startTone(ToneGenerator.TONE_CDMA_HIGH_L, 150)
            main.postDelayed({
                if (running && soundAllowed(context)) {
                    generator?.startTone(ToneGenerator.TONE_CDMA_HIGH_L, 160)
                }
            }, 190L)
        }
        if (allowVibrate) {
            vibrate(context)
        }
    }

    private fun expired(): Boolean {
        val deadline = synchronized(lock) { expiresAtMillis }
        return deadline > 0L && System.currentTimeMillis() >= deadline
    }

    private fun soundAllowed(context: Context): Boolean {
        return ringerMode(context) == AudioManager.RINGER_MODE_NORMAL &&
            interruptionAllows(context)
    }

    private fun vibrateAllowed(context: Context): Boolean {
        return ringerMode(context) != AudioManager.RINGER_MODE_SILENT &&
            interruptionAllows(context)
    }

    private fun ringerMode(context: Context): Int {
        val manager = context.getSystemService(AudioManager::class.java) ?: return AudioManager.RINGER_MODE_SILENT
        return manager.ringerMode
    }

    private fun interruptionAllows(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }
        val manager = context.getSystemService(android.app.NotificationManager::class.java)
            ?: return true
        return manager.currentInterruptionFilter ==
            android.app.NotificationManager.INTERRUPTION_FILTER_ALL
    }

    private fun tone(tick: Boolean): ToneGenerator? {
        val existing = if (tick) tickTone else ringTone
        if (existing != null) {
            return existing
        }
        return try {
            val volume = if (tick) 60 else 100
            ToneGenerator(AudioManager.STREAM_RING, volume).also {
                if (tick) tickTone = it else ringTone = it
            }
        } catch (error: RuntimeException) {
            Log.w(TAG, "offer_tone_unavailable", error)
            null
        }
    }

    private fun releaseTones() {
        ringTone?.release()
        tickTone?.release()
        ringTone = null
        tickTone = null
    }

    private fun requestFocus(context: Context) {
        val manager = context.getSystemService(AudioManager::class.java) ?: return
        audioManager = manager
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            manager.requestAudioFocus(
                focusListener,
                AudioManager.STREAM_RING,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT,
            )
            return
        }
        val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            .setOnAudioFocusChangeListener(focusListener, main)
            .build()
        focusRequest = request
        manager.requestAudioFocus(request)
    }

    private fun abandonFocus(context: Context?) {
        val manager = audioManager ?: context?.getSystemService(AudioManager::class.java)
        if (manager == null) {
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { manager.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            manager.abandonAudioFocus(focusListener)
        }
        focusRequest = null
        audioManager = null
    }

    @Suppress("DEPRECATION")
    private fun vibrate(context: Context) {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            context.getSystemService(Vibrator::class.java)
        } ?: return
        val pattern = longArrayOf(0, 90, 70, 90)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
        } else {
            vibrator.vibrate(pattern, -1)
        }
    }

    private const val TAG = "RiderOfferLaunch"
    private const val SAFETY_CAP_MS = 90_000L
}
