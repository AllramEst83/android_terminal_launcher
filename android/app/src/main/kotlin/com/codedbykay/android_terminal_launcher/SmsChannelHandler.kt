package com.codedbykay.android_terminal_launcher

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.SmsManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Sends text messages for the Dart `AndroidSmsService` (`SEND_SMS`, ordinary
 * SMS through the default SIM).
 *
 * `send` takes `number` and `text`, and replies `true` only once the network
 * has accepted **every part** of the message (Android reports that through a
 * "sent" broadcast per part), so a failure such as no signal or flight mode is
 * an error instead of a message that silently went nowhere. Error codes:
 * `NO_PERMISSION`, `NO_SERVICE`, `RADIO_OFF`, `SEND_FAILED`, `NOT_CONFIRMED`
 * (no answer within 30 s: it may still go out) and `UNAVAILABLE`. Permission is
 * asked for in Dart first; this only checks it. Never throws into Flutter.
 */
class SmsChannelHandler(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())

    // Receivers still waiting for the network, so `dispose` can release them.
    private val waiting = mutableSetOf<BroadcastReceiver>()

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "send" -> send(call.argument<String>("number"), call.argument<String>("text"), result)
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        waiting.toList().forEach { release(it) }
    }

    private fun send(number: String?, text: String?, result: MethodChannel.Result) {
        if (number.isNullOrBlank() || text.isNullOrEmpty()) {
            result.error("UNAVAILABLE", "no number or text", null)
            return
        }
        if (context.checkSelfPermission(Manifest.permission.SEND_SMS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.error("NO_PERMISSION", "sms permission not granted", null)
            return
        }
        val manager = smsManager()
        if (manager == null) {
            result.error("UNAVAILABLE", "no sms service", null)
            return
        }

        var receiver: BroadcastReceiver? = null
        try {
            val parts = manager.divideMessage(text)
            // Unique per send, so two messages in flight cannot mix answers.
            val action = "${context.packageName}.SMS_SENT.${System.nanoTime()}"
            var remaining = parts.size
            var finished = false
            lateinit var timeout: Runnable

            fun finish(code: String?) {
                if (finished) return
                finished = true
                mainHandler.removeCallbacks(timeout)
                receiver?.let { release(it) }
                if (code == null) result.success(true) else result.error(code, null, null)
            }

            receiver = object : BroadcastReceiver() {
                override fun onReceive(c: Context, intent: Intent) {
                    if (resultCode != Activity.RESULT_OK) {
                        finish(errorCode(resultCode))
                    } else if (--remaining == 0) {
                        finish(null)
                    }
                }
            }
            timeout = Runnable { finish("NOT_CONFIRMED") }

            register(receiver, IntentFilter(action))
            waiting.add(receiver)
            mainHandler.postDelayed(timeout, CONFIRM_TIMEOUT_MS)

            val sent = ArrayList<PendingIntent>(
                parts.indices.map {
                    PendingIntent.getBroadcast(
                        context,
                        it,
                        Intent(action).setPackage(context.packageName),
                        PendingIntent.FLAG_IMMUTABLE,
                    )
                },
            )
            if (parts.size == 1) {
                manager.sendTextMessage(number, null, parts[0], sent[0], null)
            } else {
                manager.sendMultipartTextMessage(number, null, parts, sent, null)
            }
        } catch (e: SecurityException) {
            receiver?.let { release(it) }
            result.error("NO_PERMISSION", e.message, null)
        } catch (e: Exception) {
            receiver?.let { release(it) }
            result.error("UNAVAILABLE", e.message, null)
        }
    }

    private fun smsManager(): SmsManager? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }

    private fun register(receiver: BroadcastReceiver, filter: IntentFilter) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter)
        }
    }

    private fun release(receiver: BroadcastReceiver) {
        if (waiting.remove(receiver)) {
            try {
                context.unregisterReceiver(receiver)
            } catch (e: IllegalArgumentException) {
                // Already gone; nothing to release.
            }
        }
    }

    private fun errorCode(resultCode: Int) = when (resultCode) {
        SmsManager.RESULT_ERROR_NO_SERVICE -> "NO_SERVICE"
        SmsManager.RESULT_ERROR_RADIO_OFF -> "RADIO_OFF"
        else -> "SEND_FAILED"
    }

    companion object {
        const val CHANNEL = "com.codedbykay.android_terminal_launcher/sms"
        private const val CONFIRM_TIMEOUT_MS = 30_000L
    }
}
