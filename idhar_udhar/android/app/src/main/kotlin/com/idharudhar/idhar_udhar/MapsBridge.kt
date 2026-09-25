package com.idharudhar.idhar_udhar

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Address
import android.location.Geocoder
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest
import java.util.Locale
import java.util.concurrent.Executors

internal class MapsBridge(private val context: Context) : MethodChannel.MethodCallHandler {
    private val fused = LocationServices.getFusedLocationProviderClient(context)
    private val geocoder = Geocoder(context, Locale.getDefault())
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getAuthHeaders" -> result.success(authHeaders())
            "isLocationServiceEnabled" -> result.success(isLocationEnabled())
            "getCurrentLocation" -> getCurrentLocation(call, result)
            "reverseGeocode" -> reverseGeocode(call, result)
            "forwardGeocode" -> forwardGeocode(call, result)
            else -> result.notImplemented()
        }
    }

    private fun authHeaders(): Map<String, String> {
        val key = try {
            val info = context.packageManager.getApplicationInfo(
                context.packageName,
                PackageManager.GET_META_DATA,
            )
            info.metaData?.getString("com.google.android.geo.API_KEY").orEmpty()
        } catch (_: Exception) {
            ""
        }
        return mapOf(
            "apiKey" to key,
            "packageName" to context.packageName,
            "sha1" to signingSha1(),
        )
    }

    private fun signingSha1(): String {
        val bytes = signingCertBytes() ?: return ""
        val digest = MessageDigest.getInstance("SHA-1").digest(bytes)
        return digest.joinToString("") { "%02X".format(it) }
    }

    @Suppress("DEPRECATION")
    private fun signingCertBytes(): ByteArray? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val info = context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES,
                )
                info.signingInfo?.apkContentsSigners?.firstOrNull()?.toByteArray()
            } else {
                val info = context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.GET_SIGNATURES,
                )
                info.signatures?.firstOrNull()?.toByteArray()
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun isLocationEnabled(): Boolean {
        val manager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
            ?: return false
        return try {
            manager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        } catch (_: Exception) {
            false
        }
    }

    private fun hasLocationPermission(): Boolean {
        val fine = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        return fine || coarse
    }

    private fun getCurrentLocation(call: MethodCall, result: MethodChannel.Result) {
        if (!hasLocationPermission()) {
            result.error("PERMISSION_DENIED", "Location permission is not granted", null)
            return
        }
        if (!isLocationEnabled()) {
            result.error("SERVICE_DISABLED", "Location services are disabled", null)
            return
        }
            val timeoutMs = (call.argument<Number>("timeoutMs")?.toLong() ?: 12_000L)
        val cancellation = CancellationTokenSource()
        main.postDelayed({ cancellation.cancel() }, timeoutMs)
        try {
            fused.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, cancellation.token)
                .addOnSuccessListener { location ->
                    if (location == null) {
                        fallbackLastLocation(result)
                    } else {
                        result.success(
                            mapOf(
                                "latitude" to location.latitude,
                                "longitude" to location.longitude,
                                "accuracy" to location.accuracy.toDouble(),
                            ),
                        )
                    }
                }
                .addOnFailureListener {
                    result.error("UNAVAILABLE", "Current location is unavailable", null)
                }
                .addOnCanceledListener {
                    result.error("TIMEOUT", "Current location timed out", null)
                }
        } catch (_: SecurityException) {
            result.error("PERMISSION_DENIED", "Location permission is not granted", null)
        } catch (_: Exception) {
            result.error("UNAVAILABLE", "Current location is unavailable", null)
        }
    }

    private fun fallbackLastLocation(result: MethodChannel.Result) {
        try {
            fused.lastLocation
                .addOnSuccessListener { location ->
                    if (location == null) {
                        result.error("UNAVAILABLE", "Current location is unavailable", null)
                    } else {
                        result.success(
                            mapOf(
                                "latitude" to location.latitude,
                                "longitude" to location.longitude,
                                "accuracy" to location.accuracy.toDouble(),
                            ),
                        )
                    }
                }
                .addOnFailureListener {
                    result.error("UNAVAILABLE", "Current location is unavailable", null)
                }
        } catch (_: Exception) {
            result.error("UNAVAILABLE", "Current location is unavailable", null)
        }
    }

    private fun reverseGeocode(call: MethodCall, result: MethodChannel.Result) {
        val lat = call.argument<Double>("latitude")
        val lng = call.argument<Double>("longitude")
        if (lat == null || lng == null) {
            result.success(null)
            return
        }
        resolveAddress(lat, lng, null, result)
    }

    private fun forwardGeocode(call: MethodCall, result: MethodChannel.Result) {
        val query = call.argument<String>("query").orEmpty().trim()
        if (query.isEmpty()) {
            result.success(null)
            return
        }
        resolveAddress(null, null, query, result)
    }

    private fun resolveAddress(
        lat: Double?,
        lng: Double?,
        query: String?,
        result: MethodChannel.Result,
    ) {
        if (!Geocoder.isPresent()) {
            result.success(null)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val listener = object : Geocoder.GeocodeListener {
                override fun onGeocode(addresses: MutableList<Address>) {
                    main.post { result.success(formatAddress(addresses.firstOrNull(), lat, lng)) }
                }

                override fun onError(errorMessage: String?) {
                    main.post { result.success(null) }
                }
            }
            if (query != null) {
                geocoder.getFromLocationName(query, 1, listener)
            } else {
                geocoder.getFromLocation(lat!!, lng!!, 1, listener)
            }
            return
        }
        executor.execute {
            val addresses = try {
                @Suppress("DEPRECATION")
                if (query != null) {
                    geocoder.getFromLocationName(query, 1)
                } else {
                    geocoder.getFromLocation(lat!!, lng!!, 1)
                }
            } catch (_: Exception) {
                null
            }
            main.post { result.success(formatAddress(addresses?.firstOrNull(), lat, lng)) }
        }
    }

    private fun formatAddress(address: Address?, lat: Double?, lng: Double?): Map<String, Any>? {
        if (address == null) {
            return null
        }
        val line = address.getAddressLine(0)?.trim().orEmpty().ifEmpty {
            listOfNotNull(
                address.subLocality,
                address.locality,
                address.adminArea,
            ).joinToString(", ")
        }
        if (line.isEmpty()) {
            return null
        }
        return mapOf(
            "address" to line,
            "city" to (address.locality ?: address.subAdminArea ?: "").trim(),
            "latitude" to (address.latitude.takeIf { it != 0.0 } ?: lat ?: 0.0),
            "longitude" to (address.longitude.takeIf { it != 0.0 } ?: lng ?: 0.0),
        )
    }

    companion object {
        private const val CHANNEL = "idhar_udhar/maps"

        fun register(engine: FlutterEngine, context: Context) {
            MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                .setMethodCallHandler(MapsBridge(context.applicationContext))
        }
    }
}
