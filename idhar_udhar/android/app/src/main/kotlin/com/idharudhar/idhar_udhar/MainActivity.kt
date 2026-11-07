package com.idharudhar.idhar_udhar

import android.app.Activity
import android.app.Application
import android.content.Intent
import android.os.Bundle
import android.os.SystemClock
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (checkoutTracing.compareAndSet(false, true)) {
            application.registerActivityLifecycleCallbacks(cashfreeCheckoutCallbacks)
        }
        RiderOfferBridge.prepareIncomingOfferWindow(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        RiderOfferBridge.prepareIncomingOfferWindow(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MapsBridge.register(flutterEngine, this)
        RiderOfferBridge.register(flutterEngine, this)
        RiderPresenceBridge.register(flutterEngine, this)
        RiderNavOverlay.register(flutterEngine, this)
        registerCustomerOtp(flutterEngine)
    }

    @Deprecated("The SMS User Consent sheet still returns through this callback.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (handleCustomerOtpResult(requestCode, resultCode, data)) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun registerCustomerOtp(flutterEngine: FlutterEngine) {
        try {
            val installer = Class.forName(
                "com.idharudhar.idhar_udhar.OtpAutofillInstaller",
            )
            installer.getDeclaredMethod(
                "register",
                FlutterEngine::class.java,
                FlutterActivity::class.java,
            ).invoke(null, flutterEngine, this)
        } catch (_: ClassNotFoundException) {
            // Customer flavor only.
        }
    }

    private fun handleCustomerOtpResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ): Boolean {
        return try {
            val installer = Class.forName(
                "com.idharudhar.idhar_udhar.OtpAutofillInstaller",
            )
            installer.getDeclaredMethod(
                "handleActivityResult",
                Int::class.javaPrimitiveType,
                Int::class.javaPrimitiveType,
                Intent::class.java,
            ).invoke(null, requestCode, resultCode, data) as Boolean
        } catch (_: ClassNotFoundException) {
            false
        }
    }

    private val cashfreeCheckoutCallbacks = object : Application.ActivityLifecycleCallbacks {
        private val openedAt = HashMap<Int, Long>()

        override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
            if (!isCashfreeCheckout(activity)) {
                return
            }
            openedAt[System.identityHashCode(activity)] = SystemClock.elapsedRealtime()
            Log.i(CHECKOUT_LOG, "activity_created")
        }

        override fun onActivityStarted(activity: Activity) {}

        override fun onActivityResumed(activity: Activity) {
            if (!isCashfreeCheckout(activity)) {
                return
            }
            val started = openedAt[System.identityHashCode(activity)]
            val sinceCreate = if (started == null) -1 else SystemClock.elapsedRealtime() - started
            activity.window.decorView.post {
                val layer = firstWebViewLayer(activity.window.decorView)
                Log.i(
                    CHECKOUT_LOG,
                    "activity_resumed since_create_ms=$sinceCreate webview_layer=$layer",
                )
            }
        }

        override fun onActivityPaused(activity: Activity) {
            if (isCashfreeCheckout(activity)) {
                Log.i(CHECKOUT_LOG, "activity_paused")
            }
        }

        override fun onActivityStopped(activity: Activity) {}

        override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}

        override fun onActivityDestroyed(activity: Activity) {
            if (!isCashfreeCheckout(activity)) {
                return
            }
            val started = openedAt.remove(System.identityHashCode(activity))
            val visibleMs = if (started == null) -1 else SystemClock.elapsedRealtime() - started
            Log.i(CHECKOUT_LOG, "activity_destroyed visible_ms=$visibleMs")
        }
    }

    companion object {
        private const val CHECKOUT_LOG = "cashfree_checkout"
        private const val CASHFREE_CHECKOUT =
            "com.cashfree.pg.core.api.ui.CashfreeWebCheckoutActivity"
        private val checkoutTracing = AtomicBoolean(false)

        private fun isCashfreeCheckout(activity: Activity): Boolean {
            return activity.javaClass.name == CASHFREE_CHECKOUT
        }

        private fun firstWebViewLayer(view: View): String {
            if (view is WebView) {
                return layerName(view.layerType)
            }
            if (view is ViewGroup) {
                for (index in 0 until view.childCount) {
                    val found = firstWebViewLayer(view.getChildAt(index))
                    if (found != "absent") {
                        return found
                    }
                }
            }
            return "absent"
        }

        private fun layerName(type: Int): String {
            return when (type) {
                View.LAYER_TYPE_NONE -> "none"
                View.LAYER_TYPE_SOFTWARE -> "software"
                View.LAYER_TYPE_HARDWARE -> "hardware"
                else -> type.toString()
            }
        }
    }
}
