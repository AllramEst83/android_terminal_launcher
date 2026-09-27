package com.codedbykay.android_terminal_launcher

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Opens a WhatsApp chat for the Dart `AndroidWhatsAppService`, via the public
 * `wa.me` link (no API to send silently, and none is wanted: the user must
 * still tap send). `ACTION_VIEW` on an `https` link needs no permission and
 * falls back to a browser when WhatsApp is not installed, same as `wa.me`
 * does outside this app. Never throws into Flutter.
 */
class WhatsAppChannelHandler(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "open") {
            result.notImplemented()
            return
        }
        val number = call.argument<String>("number")
        val text = call.argument<String>("text").orEmpty()
        if (number.isNullOrBlank()) {
            result.error("UNAVAILABLE", "no number", null)
            return
        }
        try {
            // wa.me wants digits only, no leading `+`.
            val digits = number.removePrefix("+")
            val url = "https://wa.me/$digits?text=${Uri.encode(text)}"
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            result.error("UNAVAILABLE", "no app to open WhatsApp with", null)
        } catch (e: Exception) {
            result.error("UNAVAILABLE", e.message, null)
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    companion object {
        const val CHANNEL = "com.codedbykay.android_terminal_launcher/whatsapp"
    }
}
