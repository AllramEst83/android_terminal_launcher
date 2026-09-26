package com.codedbykay.android_terminal_launcher

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Asks for runtime permissions for the Dart `AndroidPermissionService`.
 *
 * Dart names a capability (`location`), never an Android permission; the table
 * below is the only place the two meet. Replies `granted`, `denied` or
 * `permanentlyDenied` (Android no longer shows the dialog). Never throws into
 * Flutter.
 *
 * [MainActivity] must forward `onRequestPermissionsResult` to
 * [onRequestPermissionsResult]; the answer only arrives through the activity.
 */
class PermissionsChannelHandler(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL)

    // Only one dialog can be up at a time, so one pending request is enough.
    private var pending: MethodChannel.Result? = null
    private var pendingPermissions: Array<String> = emptyArray()

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "request" -> request(call.argument<String>("permission"), result)
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        pending?.success(DENIED)
        pending = null
    }

    private fun request(name: String?, result: MethodChannel.Result) {
        val permissions = PERMISSIONS[name]
        if (permissions == null) {
            result.error("UNKNOWN_PERMISSION", "no such permission: $name", null)
            return
        }
        if (isGranted(permissions)) {
            result.success(GRANTED)
            return
        }
        if (pending != null) {
            result.error("BUSY", "another permission request is open", null)
            return
        }
        pending = result
        pendingPermissions = permissions
        try {
            activity.requestPermissions(permissions, REQUEST_CODE)
        } catch (e: Exception) {
            pending = null
            result.success(DENIED)
        }
    }

    /** Returns true when the result was ours. */
    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pending ?: return true
        val asked = pendingPermissions
        pending = null
        pendingPermissions = emptyArray()
        result.success(
            when {
                // An interrupted request arrives with empty results: not a "no".
                grantResults.isEmpty() -> DENIED
                isGranted(asked) -> GRANTED
                // After a refusal Android only says "show your reasoning" while
                // the dialog can still appear, so no rationale means it won't.
                asked.none { activity.shouldShowRequestPermissionRationale(it) } ->
                    PERMANENTLY_DENIED
                else -> DENIED
            },
        )
        return true
    }

    // Any one of the listed permissions is enough, so a capability can later
    // list alternatives.
    private fun isGranted(permissions: Array<String>) = permissions.any {
        activity.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
    }

    companion object {
        const val CHANNEL = "com.codedbykay.android_terminal_launcher/permissions"
        private const val REQUEST_CODE = 9001
        private const val GRANTED = "granted"
        private const val DENIED = "denied"
        private const val PERMANENTLY_DENIED = "permanentlyDenied"

        // Coarse is all a forecast needs, so precise location is never asked for
        // (and is not declared in the manifest).
        private val PERMISSIONS = mapOf(
            "location" to arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION),
            // Read-only for now; creating events adds WRITE_CALENDAR.
            "calendar" to arrayOf(Manifest.permission.READ_CALENDAR),
            "contacts" to arrayOf(Manifest.permission.READ_CONTACTS),
            // Placing a call directly; without it the dialer is opened instead.
            "phone" to arrayOf(Manifest.permission.CALL_PHONE),
            "sms" to arrayOf(Manifest.permission.SEND_SMS),
        )
    }
}
