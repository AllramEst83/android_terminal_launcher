package com.codedbykay.android_terminal_launcher

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var appsChannel: AppsChannelHandler? = null
    private var permissionsChannel: PermissionsChannelHandler? = null
    private var locationChannel: LocationChannelHandler? = null
    private var calendarChannel: CalendarChannelHandler? = null
    private var contactsChannel: ContactsChannelHandler? = null
    private var phoneChannel: PhoneChannelHandler? = null
    private var smsChannel: SmsChannelHandler? = null
    private var clockChannel: ClockChannelHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        appsChannel = AppsChannelHandler(applicationContext, messenger)
        // Asking for a permission shows a dialog over an activity, so this one
        // needs `this`, not the application context.
        permissionsChannel = PermissionsChannelHandler(this, messenger)
        locationChannel = LocationChannelHandler(applicationContext, messenger)
        calendarChannel = CalendarChannelHandler(applicationContext, messenger)
        contactsChannel = ContactsChannelHandler(applicationContext, messenger)
        phoneChannel = PhoneChannelHandler(applicationContext, messenger)
        smsChannel = SmsChannelHandler(applicationContext, messenger)
        clockChannel = ClockChannelHandler(applicationContext, messenger)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        val handled =
            permissionsChannel?.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (handled != true) {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        appsChannel?.dispose()
        appsChannel = null
        permissionsChannel?.dispose()
        permissionsChannel = null
        locationChannel?.dispose()
        locationChannel = null
        calendarChannel?.dispose()
        calendarChannel = null
        contactsChannel?.dispose()
        contactsChannel = null
        phoneChannel?.dispose()
        phoneChannel = null
        smsChannel?.dispose()
        smsChannel = null
        clockChannel?.dispose()
        clockChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
