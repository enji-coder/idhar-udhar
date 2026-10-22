package com.idharudhar.idhar_udhar

import android.app.Activity
import android.app.Application
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.os.Bundle
import java.lang.ref.WeakReference
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs

/**
 * Bubble drawn over other apps only while the Rider process has no started
 * activity. [onActivityPaused] does not hide or show it: opening Google Maps
 * pauses the activity before the app is actually in the background.
 */
internal object RiderNavOverlay {
    private const val CHANNEL = "idhar_udhar/nav_overlay"

    private var channel: MethodChannel? = null
    private var appContext: Context? = null
    private var activityRef: WeakReference<Activity>? = null
    private var windowManager: WindowManager? = null
    private var bubbleRoot: View? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var optionsRoot: View? = null
    private var optionsParams: WindowManager.LayoutParams? = null
    private var pendingAction: String? = null
    private var armed = false
    private var appInBackground = false
    private var startedActivities = 0
    private var tracking = false

    fun register(engine: FlutterEngine, host: Context) {
        val app = host.applicationContext
        appContext = app
        if (host is Activity) {
            activityRef = WeakReference(host)
        }
        ensureTracking(app)
        val messenger = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        channel = messenger
        messenger.setMethodCallHandler { call, result ->
            when (call.method) {
                "canDrawOverlays" -> result.success(canDraw(app))
                "openOverlaySettings" -> {
                    openSettings(app)
                    result.success(true)
                }
                "launch" -> result.success(launch(app, call))
                "arm" -> {
                    armed = true
                    render()
                    result.success(true)
                }
                "moveToBack" -> {
                    val activity = activityRef?.get()
                    if (activity == null) {
                        result.success(false)
                    } else {
                        activity.runOnUiThread { activity.moveTaskToBack(true) }
                        result.success(true)
                    }
                }
                "background" -> {
                    appInBackground = true
                    render()
                    result.success(true)
                }
                "foreground" -> {
                    appInBackground = false
                    render()
                    result.success(true)
                }
                "disarm", "hide" -> {
                    disarm()
                    result.success(true)
                }
                "consumeAction" -> {
                    val action = pendingAction
                    pendingAction = null
                    result.success(action)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun ensureTracking(context: Context) {
        if (tracking) {
            return
        }
        val app = context.applicationContext as Application
        app.registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
            override fun onActivityStarted(activity: Activity) {
                if (activity is MainActivity) {
                    activityRef = WeakReference(activity)
                }
                startedActivities += 1
                if (startedActivities == 1) {
                    appInBackground = false
                    render()
                }
            }

            override fun onActivityStopped(activity: Activity) {
                startedActivities = (startedActivities - 1).coerceAtLeast(0)
                if (startedActivities == 0) {
                    appInBackground = true
                    render()
                }
            }

            override fun onActivityPaused(activity: Activity) {
                // Pause is not proof the Rider app is in the background.
            }

            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}
            override fun onActivityResumed(activity: Activity) {
                if (activity is MainActivity) {
                    activityRef = WeakReference(activity)
                }
            }
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
            override fun onActivityDestroyed(activity: Activity) {}
        })
        tracking = true
    }

    private fun render() {
        val context = appContext ?: return
        val visible = armed &&
            appInBackground &&
            startedActivities == 0 &&
            canDraw(context)
        if (!visible) {
            removeViews()
            return
        }
        val manager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        if (bubbleRoot == null) {
            attachBubble(context, manager)
        }
        // Top-right Options Menu is hidden. attachOptions() stays so the
        // control can be restored without rewriting the overlay.
        // if (optionsRoot == null) {
        //     attachOptions(context, manager)
        // }
    }

    private fun disarm() {
        armed = false
        removeViews()
    }

    private fun canDraw(context: Context): Boolean {
        return Settings.canDrawOverlays(context)
    }

    private fun openSettings(context: Context) {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:${context.packageName}"),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(intent)
        } catch (_: ActivityNotFoundException) {
            // The rider can still open Google Maps without the bubble.
        }
    }

    private fun launch(context: Context, call: MethodCall): String {
        val navigation = call.argument<String>("navigationUri").orEmpty()
        val fallback = call.argument<String>("fallbackUri").orEmpty()
        if (navigation.isNotEmpty() && startView(context, navigation, mapsPackage = true)) {
            return "maps"
        }
        if (fallback.isNotEmpty() && startView(context, fallback, mapsPackage = false)) {
            return "browser"
        }
        return "unavailable"
    }

    private fun startView(context: Context, uri: String, mapsPackage: Boolean): Boolean {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uri)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (mapsPackage) {
            intent.setPackage("com.google.android.apps.maps")
        }
        return try {
            context.startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        }
    }

    private fun attachBubble(context: Context, manager: WindowManager) {
        val density = context.resources.displayMetrics.density
        val bubblePx = (56 * density).toInt()
        val margin = (16 * density).toInt()
        val bubble = ImageView(context).apply {
            val icon = context.resources.getIdentifier(
                "ic_nav_bubble_partner",
                "drawable",
                context.packageName,
            )
            if (icon != 0) {
                setImageResource(icon)
            }
            contentDescription = "IDHAR UDHAR"
            scaleType = ImageView.ScaleType.CENTER_CROP
        }
        val bubbleWrap = FrameLayout(context).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(0xFFFFFFFF.toInt())
            }
            elevation = 8 * density
            addView(bubble, FrameLayout.LayoutParams(bubblePx, bubblePx))
        }
        val close = TextView(context).apply {
            text = "Close"
            contentDescription = "Close trip controls"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setTextColor(0xFF0D47A1.toInt())
            gravity = Gravity.CENTER
            setPadding(
                (10 * density).toInt(),
                (4 * density).toInt(),
                (10 * density).toInt(),
                (4 * density).toInt(),
            )
            background = GradientDrawable().apply {
                cornerRadius = 16 * density
                setColor(0xFFFFFFFF.toInt())
            }
            setOnClickListener { dispatch(context, "dismiss") }
        }
        val column = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            addView(bubbleWrap, LinearLayout.LayoutParams(bubblePx, bubblePx))
            addView(
                close,
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ).apply { topMargin = (6 * density).toInt() },
            )
        }
        val layout = overlayLayout(manager, margin).apply {
            gravity = Gravity.TOP or Gravity.START
            val screen = screenSize(manager)
            x = (screen.first - bubblePx - margin * 3).coerceAtLeast(margin)
            y = (screen.second / 2).coerceAtLeast(margin)
        }
        bubbleWrap.setOnClickListener { bringForward(context) }
        bubbleWrap.setOnTouchListener(
            dragListener(manager, layout, column, margin),
        )
        if (addOverlay(manager, column, layout)) {
            bubbleRoot = column
            bubbleParams = layout
        }
    }

    @Suppress("unused")
    private fun attachOptions(context: Context, manager: WindowManager) {
        val density = context.resources.displayMetrics.density
        val margin = (12 * density).toInt()
        val options = TextView(context).apply {
            text = "Options Menu"
            contentDescription = "Options Menu"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            setTextColor(0xFFFFFFFF.toInt())
            gravity = Gravity.CENTER
            setPadding(
                (14 * density).toInt(),
                (10 * density).toInt(),
                (14 * density).toInt(),
                (10 * density).toInt(),
            )
            background = GradientDrawable().apply {
                cornerRadius = 20 * density
                setColor(0xFF0D47A1.toInt())
            }
            setOnClickListener { dispatch(context, "order_details") }
        }
        val layout = overlayLayout(manager, margin).apply {
            gravity = Gravity.TOP or Gravity.END
            x = margin
            y = (36 * density).toInt()
        }
        if (addOverlay(manager, options, layout)) {
            optionsRoot = options
            optionsParams = layout
        }
    }

    private fun overlayLayout(manager: WindowManager, margin: Int): WindowManager.LayoutParams {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            this.x = margin
            this.y = margin
        }
    }

    private fun addOverlay(
        manager: WindowManager,
        view: View,
        layout: WindowManager.LayoutParams,
    ): Boolean {
        return try {
            manager.addView(view, layout)
            windowManager = manager
            true
        } catch (_: RuntimeException) {
            false
        }
    }

    private fun dragListener(
        manager: WindowManager,
        layout: WindowManager.LayoutParams,
        view: View,
        margin: Int,
    ): View.OnTouchListener {
        val slop = ViewConfiguration.get(view.context).scaledTouchSlop
        var downRawX = 0f
        var downRawY = 0f
        var startX = 0
        var startY = 0
        var dragging = false
        return View.OnTouchListener { touched, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    dragging = false
                    downRawX = event.rawX
                    downRawY = event.rawY
                    startX = layout.x
                    startY = layout.y
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - downRawX
                    val dy = event.rawY - downRawY
                    if (!dragging && (abs(dx) > slop || abs(dy) > slop)) {
                        dragging = true
                    }
                    if (dragging) {
                        val screen = screenSize(manager)
                        val maxX = (screen.first - view.width - margin).coerceAtLeast(margin)
                        val maxY = (screen.second - view.height - margin).coerceAtLeast(margin)
                        layout.x = (startX + dx.toInt()).coerceIn(margin, maxX)
                        layout.y = (startY + dy.toInt()).coerceIn(margin, maxY)
                        try {
                            manager.updateViewLayout(view, layout)
                        } catch (_: RuntimeException) {
                            removeViews()
                        }
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    // A drag must not open the app. performClick runs the
                    // listener on the bubble, not on the window column.
                    if (!dragging) {
                        touched.performClick()
                    }
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    dragging = false
                    true
                }
                else -> false
            }
        }
    }

    private fun dispatch(context: Context, id: String) {
        if (id == "dismiss") {
            disarm()
        } else if (id != "order_details") {
            return
        } else {
            bringForward(context)
        }
        val messenger = channel ?: run {
            if (id == "order_details") {
                pendingAction = id
            }
            return
        }
        messenger.invokeMethod("onAction", id, object : MethodChannel.Result {
            override fun success(result: Any?) {}

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                if (id == "order_details") {
                    pendingAction = id
                }
            }

            override fun notImplemented() {
                if (id == "order_details") {
                    pendingAction = id
                }
            }
        })
    }

    private fun bringForward(context: Context) {
        val existing = activityRef?.get()
        val host = if (existing != null && !existing.isFinishing) existing else context
        val intent = Intent(host, MainActivity::class.java).addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
        )
        try {
            host.startActivity(intent)
        } catch (_: ActivityNotFoundException) {
            // The delivery screen stays where it was.
        } catch (_: RuntimeException) {
            // Background-start restrictions must not crash the overlay.
        }
    }

    private fun removeViews() {
        val manager = windowManager
        val views = listOf(bubbleRoot, optionsRoot)
        bubbleRoot = null
        bubbleParams = null
        optionsRoot = null
        optionsParams = null
        if (manager == null) {
            return
        }
        for (view in views) {
            if (view == null) {
                continue
            }
            try {
                manager.removeView(view)
            } catch (_: RuntimeException) {
                // The window token is already gone.
            }
        }
        windowManager = null
    }

    private fun screenSize(manager: WindowManager): Pair<Int, Int> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = manager.currentWindowMetrics.bounds
            bounds.width() to bounds.height()
        } else {
            val metrics = android.util.DisplayMetrics()
            @Suppress("DEPRECATION")
            manager.defaultDisplay.getMetrics(metrics)
            metrics.widthPixels to metrics.heightPixels
        }
    }

}
