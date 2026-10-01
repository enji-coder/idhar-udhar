package com.idharudhar.idhar_udhar

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MapsBridge.register(flutterEngine, this)
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
}
