package com.codedbykay.android_terminal_launcher

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Address
import android.location.Geocoder
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Gives the Dart `AndroidLocationService` a rough position (coarse location,
 * from the network provider: enough for a forecast, and it needs no GPS fix).
 *
 * Replies `{latitude, longitude}` plus `name`, `region` and `country` when
 * Android's own geocoder could name the spot (it is on-device or Google's, so
 * no new third party sees the position; it fails offline and on phones without
 * the service, and the extras are then simply left out), or an error with one of the codes
 * `NO_PERMISSION`, `LOCATION_OFF` or `UNAVAILABLE`. Permission is asked for on
 * the Dart side first; this only checks it. Never throws into Flutter.
 */
class LocationChannelHandler(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())

    // Older Androids have only a blocking geocoder call.
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "current" -> current(result)
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        executor.shutdown()
    }

    @SuppressLint("MissingPermission") // checked just below
    private fun current(result: MethodChannel.Result) {
        if (context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.error("NO_PERMISSION", "location permission not granted", null)
            return
        }
        val manager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        if (manager == null || !manager.isProviderEnabled(PROVIDER)) {
            result.error("LOCATION_OFF", "location is switched off", null)
            return
        }
        val reply = OnceReply(result)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                currentModern(manager, reply)
            } else {
                currentLegacy(manager, reply)
            }
        } catch (e: SecurityException) {
            reply.error("NO_PERMISSION", "location permission not granted")
        } catch (e: Exception) {
            reply.error("UNAVAILABLE", e.message)
        }
    }

    @SuppressLint("MissingPermission")
    private fun currentModern(manager: LocationManager, reply: OnceReply) {
        val cancel = CancellationSignal()
        val timeout = Runnable {
            cancel.cancel()
            reply.location(manager.getLastKnownLocation(PROVIDER))
        }
        mainHandler.postDelayed(timeout, TIMEOUT_MS)
        manager.getCurrentLocation(PROVIDER, cancel, context.mainExecutor) { location ->
            mainHandler.removeCallbacks(timeout)
            reply.location(location ?: manager.getLastKnownLocation(PROVIDER))
        }
    }

    // Before Android 11 there is no one-shot API besides the deprecated
    // requestSingleUpdate; a saved position is used when there is one.
    @Suppress("DEPRECATION")
    @SuppressLint("MissingPermission")
    private fun currentLegacy(manager: LocationManager, reply: OnceReply) {
        val last = manager.getLastKnownLocation(PROVIDER)
        if (last != null) {
            reply.location(last)
            return
        }
        // All four methods are written out: the ones that are `default` on
        // newer Android do not exist on older versions.
        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                reply.location(location)
            }

            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}

            override fun onProviderEnabled(provider: String) {}

            override fun onProviderDisabled(provider: String) {}
        }
        val timeout = Runnable {
            manager.removeUpdates(listener)
            reply.location(null)
        }
        mainHandler.postDelayed(timeout, TIMEOUT_MS)
        manager.requestSingleUpdate(PROVIDER, listener, Looper.getMainLooper())
    }

    /** Everything runs on the main thread, so a plain flag is enough. */
    private inner class OnceReply(private val result: MethodChannel.Result) {
        private var done = false

        fun location(location: Location?) {
            if (done) return
            done = true
            if (location == null) {
                result.error("UNAVAILABLE", "no location fix", null)
                return
            }
            lookUpPlace(location) { place ->
                result.success(
                    mapOf(
                        "latitude" to location.latitude,
                        "longitude" to location.longitude,
                    ) + place,
                )
            }
        }

        fun error(code: String, message: String?) {
            if (done) return
            done = true
            result.error(code, message, null)
        }
    }

    /**
     * Names the spot with [done] called exactly once on the main thread: with
     * `name`/`region`/`country` when known, with nothing when not. Never fails
     * the position itself.
     */
    private fun lookUpPlace(location: Location, done: (Map<String, String>) -> Unit) {
        var answered = false
        fun answer(place: Map<String, String>) {
            if (answered) return
            answered = true
            done(place)
        }
        if (!Geocoder.isPresent()) {
            answer(emptyMap())
            return
        }
        mainHandler.postDelayed({ answer(emptyMap()) }, GEOCODE_TIMEOUT_MS)
        try {
            val geocoder = Geocoder(context, Locale.getDefault())
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                geocoder.getFromLocation(
                    location.latitude,
                    location.longitude,
                    1,
                    object : Geocoder.GeocodeListener {
                        override fun onGeocode(addresses: MutableList<Address>) {
                            mainHandler.post { answer(describe(addresses.firstOrNull())) }
                        }

                        override fun onError(errorMessage: String?) {
                            mainHandler.post { answer(emptyMap()) }
                        }
                    },
                )
            } else {
                executor.execute {
                    @Suppress("DEPRECATION")
                    val addresses = try {
                        geocoder.getFromLocation(location.latitude, location.longitude, 1)
                    } catch (e: Exception) {
                        null
                    }
                    mainHandler.post { answer(describe(addresses?.firstOrNull())) }
                }
            }
        } catch (e: Exception) {
            answer(emptyMap())
        }
    }

    private fun describe(address: Address?): Map<String, String> {
        if (address == null) return emptyMap()
        // A village has no `locality` on some phones; fall back to wider areas
        // rather than showing nothing.
        val name = listOf(address.locality, address.subAdminArea, address.adminArea)
            .firstOrNull { !it.isNullOrBlank() } ?: return emptyMap()
        val region = address.adminArea?.takeIf { it.isNotBlank() && it != name }
        return listOfNotNull(
            "name" to name,
            region?.let { "region" to it },
            address.countryName?.takeIf { it.isNotBlank() }?.let { "country" to it },
        ).toMap()
    }

    companion object {
        const val CHANNEL = "com.codedbykay.android_terminal_launcher/location"
        private const val PROVIDER = LocationManager.NETWORK_PROVIDER
        private const val TIMEOUT_MS = 15_000L
        private const val GEOCODE_TIMEOUT_MS = 5_000L
    }
}
