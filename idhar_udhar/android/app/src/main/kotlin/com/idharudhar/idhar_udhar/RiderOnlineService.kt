package com.idharudhar.idhar_udhar

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import com.google.android.gms.tasks.Tasks
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Keeps Online riders present for Admin + dispatch while the app is backgrounded.
 * Dart timers freeze on Android; this FGS posts GPS (or a heartbeat) on a cadence
 * under RIDER_PRESENCE_STALE_MS. Requires a persistent notification while Online.
 */
class RiderOnlineService : Service() {
    private val fused by lazy { LocationServices.getFusedLocationProviderClient(this) }
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val running = AtomicBoolean(false)
    private var lastLat: Double? = null
    private var lastLng: Double? = null

    private val tickRunnable = object : Runnable {
        override fun run() {
            if (!running.get()) {
                return
            }
            executor.execute { tickOnce() }
            main.postDelayed(this, INTERVAL_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelfSafely()
                return START_NOT_STICKY
            }
            ACTION_UPDATE_AUTH -> {
                intent.getStringExtra(EXTRA_ACCESS_TOKEN)?.let(::saveToken)
                intent.getStringExtra(EXTRA_BASE_URL)?.let(::saveBaseUrl)
                return START_STICKY
            }
            else -> {
                intent?.getStringExtra(EXTRA_ACCESS_TOKEN)?.let(::saveToken)
                intent?.getStringExtra(EXTRA_BASE_URL)?.let(::saveBaseUrl)
                if (!hasLocationPermission(this)) {
                    Log.w(TAG, "presence_fgs_aborted reason=location_permission_missing")
                    stopSelf()
                    return START_NOT_STICKY
                }
                try {
                    startAsForeground()
                } catch (error: SecurityException) {
                    Log.e(TAG, "presence_fgs_security_exception", error)
                    stopSelf()
                    return START_NOT_STICKY
                }
                if (running.compareAndSet(false, true)) {
                    main.post(tickRunnable)
                }
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        running.set(false)
        main.removeCallbacks(tickRunnable)
        super.onDestroy()
    }

    private fun startAsForeground() {
        ensureChannel()
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun stopSelfSafely() {
        running.set(false)
        main.removeCallbacks(tickRunnable)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun tickOnce() {
        val token = prefs().getString(PREF_TOKEN, null).orEmpty()
        val baseUrl = prefs().getString(PREF_BASE_URL, null).orEmpty().trimEnd('/')
        if (token.isEmpty() || baseUrl.isEmpty()) {
            Log.w(TAG, "presence_tick_skipped_missing_auth")
            return
        }
        val fix = readLocationOrNull()
        if (fix != null) {
            lastLat = fix.first
            lastLng = fix.second
            if (postLocation(baseUrl, token, fix.first, fix.second)) {
                Log.i(TAG, "presence_location_posted")
                return
            }
        } else if (lastLat != null && lastLng != null) {
            // Transient GPS gap: refresh the last known fix so dispatch stays eligible.
            if (postLocation(baseUrl, token, lastLat!!, lastLng!!)) {
                Log.i(TAG, "presence_last_known_posted")
                return
            }
        }
        if (postHeartbeat(baseUrl, token)) {
            Log.i(TAG, "presence_heartbeat_posted")
        } else {
            Log.w(TAG, "presence_tick_failed")
        }
    }

    private fun readLocationOrNull(): Pair<Double, Double>? {
        if (!hasLocationPermission(this)) {
            return null
        }
        return try {
            val tokenSource = CancellationTokenSource()
            val loc = Tasks.await(
                fused.getCurrentLocation(
                    Priority.PRIORITY_BALANCED_POWER_ACCURACY,
                    tokenSource.token,
                ),
                10,
                TimeUnit.SECONDS,
            )
            if (loc != null && loc.latitude.isFinite() && loc.longitude.isFinite()) {
                loc.latitude to loc.longitude
            } else {
                null
            }
        } catch (error: Exception) {
            Log.w(TAG, "presence_gps_unavailable", error)
            null
        }
    }

    private fun postLocation(
        baseUrl: String,
        token: String,
        latitude: Double,
        longitude: Double,
    ): Boolean {
        val body = JSONObject()
            .put("latitude", latitude)
            .put("longitude", longitude)
            .put("timestamp", utcTimestamp())
            .toString()
        return httpPost("$baseUrl/v1/rider/location", token, body)
    }

    private fun utcTimestamp(): String {
        val fmt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        fmt.timeZone = TimeZone.getTimeZone("UTC")
        return fmt.format(Date())
    }

    private fun postHeartbeat(baseUrl: String, token: String): Boolean {
        return httpPost("$baseUrl/v1/rider/presence/heartbeat", token, "{}")
    }

    private fun httpPost(url: String, token: String, body: String): Boolean {
        var connection: HttpURLConnection? = null
        return try {
            connection = (URL(url).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 12_000
                readTimeout = 12_000
                doOutput = true
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("Accept", "application/json")
                setRequestProperty("Content-Type", "application/json")
            }
            OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use { it.write(body) }
            val code = connection.responseCode
            code in 200..299
        } catch (error: Exception) {
            Log.w(TAG, "presence_http_failed type=${error.javaClass.simpleName}")
            false
        } finally {
            connection?.disconnect()
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Online for deliveries",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Keeps you available for new delivery requests while Online."
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val pending = PendingIntent.getActivity(
            this,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("You're online")
            .setContentText("IDHAR UDHAR Partner is available for new deliveries.")
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setContentIntent(pending)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun prefs() = getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun saveToken(token: String) {
        prefs().edit().putString(PREF_TOKEN, token.trim()).apply()
    }

    private fun saveBaseUrl(baseUrl: String) {
        prefs().edit().putString(PREF_BASE_URL, baseUrl.trim().trimEnd('/')).apply()
    }

    companion object {
        private const val TAG = "RiderOnlineService"
        private const val CHANNEL_ID = "rider_online_presence_v1"
        private const val NOTIFICATION_ID = 44001
        private const val INTERVAL_MS = 30_000L
        private const val PREFS = "rider_online_presence"
        private const val PREF_TOKEN = "access_token"
        private const val PREF_BASE_URL = "base_url"

        const val ACTION_START = "com.idharudhar.rider.ONLINE_START"
        const val ACTION_STOP = "com.idharudhar.rider.ONLINE_STOP"
        const val ACTION_UPDATE_AUTH = "com.idharudhar.rider.ONLINE_UPDATE_AUTH"
        const val EXTRA_ACCESS_TOKEN = "access_token"
        const val EXTRA_BASE_URL = "base_url"

        fun hasLocationPermission(context: Context): Boolean {
            val fine = ContextCompat.checkSelfPermission(
                context,
                android.Manifest.permission.ACCESS_FINE_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED
            val coarse = ContextCompat.checkSelfPermission(
                context,
                android.Manifest.permission.ACCESS_COARSE_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED
            return fine || coarse
        }

        fun start(context: Context, accessToken: String, baseUrl: String): Boolean {
            if (!hasLocationPermission(context)) {
                Log.w(TAG, "presence_fgs_not_started reason=location_permission_missing")
                return false
            }
            val intent = Intent(context, RiderOnlineService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_ACCESS_TOKEN, accessToken)
                putExtra(EXTRA_BASE_URL, baseUrl)
            }
            return try {
                ContextCompat.startForegroundService(context, intent)
                true
            } catch (error: SecurityException) {
                Log.e(TAG, "presence_fgs_security_exception", error)
                false
            }
        }

        fun updateAuth(context: Context, accessToken: String, baseUrl: String) {
            val intent = Intent(context, RiderOnlineService::class.java).apply {
                action = ACTION_UPDATE_AUTH
                putExtra(EXTRA_ACCESS_TOKEN, accessToken)
                putExtra(EXTRA_BASE_URL, baseUrl)
            }
            context.startService(intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, RiderOnlineService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }
}
