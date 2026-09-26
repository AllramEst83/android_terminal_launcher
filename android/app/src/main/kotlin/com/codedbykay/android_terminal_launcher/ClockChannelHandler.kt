package com.codedbykay.android_terminal_launcher

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.AlarmClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Sets timers and alarms for the Dart `AndroidClockService` by asking the
 * phone's own clock app, through the `AlarmClock` intents. That app is what
 * rings, vibrates and survives a reboot or doze, so nothing here schedules
 * anything itself. Setting needs the normal permission `SET_ALARM` (granted at
 * install); opening the lists needs none.
 *
 * Every method replies `true` once the intent was handed over, `NO_APP` when
 * nothing answers to it and `NO_PERMISSION` when Android refuses. Never throws
 * into Flutter.
 */
class ClockChannelHandler(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "timer" -> {
                val seconds = call.argument<Int>("seconds")
                if (seconds == null || seconds < 1 || seconds > MAX_TIMER_SECONDS) {
                    result.error("UNAVAILABLE", "a timer is 1 second to 24 hours", null)
                    return
                }
                val intent = Intent(AlarmClock.ACTION_SET_TIMER)
                    .putExtra(AlarmClock.EXTRA_LENGTH, seconds)
                    // Starts at once, without opening the clock app.
                    .putExtra(AlarmClock.EXTRA_SKIP_UI, true)
                call.argument<String>("label")?.takeIf { it.isNotBlank() }?.let {
                    intent.putExtra(AlarmClock.EXTRA_MESSAGE, it)
                }
                start(intent, result)
            }
            "alarm" -> {
                val hour = call.argument<Int>("hour")
                val minute = call.argument<Int>("minute")
                if (hour == null || minute == null || hour !in 0..23 || minute !in 0..59) {
                    result.error("UNAVAILABLE", "not a time of day", null)
                    return
                }
                val intent = Intent(AlarmClock.ACTION_SET_ALARM)
                    .putExtra(AlarmClock.EXTRA_HOUR, hour)
                    .putExtra(AlarmClock.EXTRA_MINUTES, minute)
                    .putExtra(AlarmClock.EXTRA_SKIP_UI, true)
                call.argument<String>("label")?.takeIf { it.isNotBlank() }?.let {
                    intent.putExtra(AlarmClock.EXTRA_MESSAGE, it)
                }
                val days = call.argument<List<Int>>("days").orEmpty()
                if (days.isNotEmpty()) {
                    // Dart counts Monday as 1 and Sunday as 7; `Calendar` counts
                    // Sunday as 1 and Monday as 2.
                    val calendarDays = ArrayList(days.map { (it % 7) + 1 })
                    intent.putIntegerArrayListExtra(AlarmClock.EXTRA_DAYS, calendarDays)
                }
                start(intent, result)
            }
            "showTimers" -> {
                // Timers have their own screen from Android 8; before that the
                // alarm list is all there is.
                val action = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    AlarmClock.ACTION_SHOW_TIMERS
                } else {
                    AlarmClock.ACTION_SHOW_ALARMS
                }
                start(Intent(action), result)
            }
            "showAlarms" -> start(Intent(AlarmClock.ACTION_SHOW_ALARMS), result)
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    private fun start(intent: Intent, result: MethodChannel.Result) {
        try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            result.error("NO_APP", "no clock app", null)
        } catch (e: SecurityException) {
            result.error("NO_PERMISSION", e.message, null)
        } catch (e: Exception) {
            result.error("UNAVAILABLE", e.message, null)
        }
    }

    companion object {
        const val CHANNEL = "com.codedbykay.android_terminal_launcher/clock"
        private const val MAX_TIMER_SECONDS = 24 * 60 * 60
    }
}
