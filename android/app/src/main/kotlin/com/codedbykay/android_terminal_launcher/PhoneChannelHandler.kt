package com.codedbykay.android_terminal_launcher

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Places calls for the Dart `AndroidPhoneService`.
 *
 * `call` dials at once (`ACTION_CALL`, needs `CALL_PHONE`); `dial` only opens
 * the dialer with the number filled in (`ACTION_DIAL`, needs nothing). Both
 * reply `true` when the screen was launched. `call` replies `NO_PERMISSION`
 * when it may not, which includes emergency numbers: Android refuses those to
 * ordinary apps, and Dart then falls back to `dial`. Never throws into
 * Flutter.
 */
class PhoneChannelHandler(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val number = call.argument<String>("number")
        if (number.isNullOrBlank() && (call.method == "call" || call.method == "dial")) {
            result.error("UNAVAILABLE", "no number", null)
            return
        }
        when (call.method) {
            "call" -> start(Intent.ACTION_CALL, number!!, result)
            "dial" -> start(Intent.ACTION_DIAL, number!!, result)
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    private fun start(action: String, number: String, result: MethodChannel.Result) {
        if (action == Intent.ACTION_CALL &&
            context.checkSelfPermission(Manifest.permission.CALL_PHONE) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.error("NO_PERMISSION", "call permission not granted", null)
            return
        }
        try {
            // `fromParts` encodes characters such as `#` that would otherwise
            // cut the number short.
            val intent = Intent(action, Uri.fromParts("tel", number, null))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            result.success(true)
        } catch (e: SecurityException) {
            result.error("NO_PERMISSION", e.message, null)
        } catch (e: ActivityNotFoundException) {
            result.error("UNAVAILABLE", "no phone app", null)
        } catch (e: Exception) {
            result.error("UNAVAILABLE", e.message, null)
        }
    }

    companion object {
        const val CHANNEL = "com.codedbykay.android_terminal_launcher/phone"
    }
}
