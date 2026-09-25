package com.codedbykay.android_terminal_launcher

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Lists and launches apps for the Dart `AndroidAppRepository`.
 *
 * Returns plain data only; filtering out this app and sorting happen in Dart so
 * they are unit-tested there. Never throws into Flutter: a launch that cannot
 * happen replies `false`.
 */
class AppsChannelHandler(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "listApps" -> listApps(result)
            "launch" -> launch(call.argument<String>("packageName"), result)
            "uninstall" -> uninstall(call.argument<String>("packageName"), result)
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        executor.shutdown()
    }

    // The query can be slow with many apps, so it runs off the main thread and
    // replies back on it.
    private fun listApps(result: MethodChannel.Result) {
        executor.execute {
            try {
                val apps = queryLaunchableApps()
                mainHandler.post { result.success(apps) }
            } catch (e: Exception) {
                mainHandler.post { result.error("LIST_FAILED", e.message, null) }
            }
        }
    }

    private fun queryLaunchableApps(): List<Map<String, String>> {
        val pm = context.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolved: List<ResolveInfo> =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(0L))
            } else {
                @Suppress("DEPRECATION")
                pm.queryIntentActivities(intent, 0)
            }
        return resolved
            .map {
                mapOf(
                    "label" to it.loadLabel(pm).toString(),
                    "packageName" to it.activityInfo.packageName,
                )
            }
            .distinctBy { it["packageName"] }
    }

    private fun launch(packageName: String?, result: MethodChannel.Result) {
        val intent = packageName?.let { context.packageManager.getLaunchIntentForPackage(it) }
        if (intent == null) {
            result.success(false)
            return
        }
        try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    // Android only allows uninstalling through its own confirmation dialog, so
    // `true` means the dialog was shown, not that anything was removed. Needs
    // REQUEST_DELETE_PACKAGES in the manifest.
    private fun uninstall(packageName: String?, result: MethodChannel.Result) {
        if (packageName == null) {
            result.success(false)
            return
        }
        try {
            val intent = Intent(Intent.ACTION_DELETE, Uri.fromParts("package", packageName, null))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    companion object {
        const val CHANNEL = "com.codedbykay.android_terminal_launcher/apps"
    }
}
