package com.codedbykay.android_terminal_launcher

import android.Manifest
import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.provider.CalendarContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Reads events for the Dart `AndroidCalendarService` from Android's calendar
 * provider (no library: it is one query).
 *
 * `events` takes `begin`/`end` in epoch milliseconds and replies a list of
 * `{id, title, begin, end, allDay, location, calendar, color}`, one per occurrence
 * (repeating events are already expanded by `Instances`). Times are raw: an
 * all-day event's are UTC midnights, and turning them into local dates is the
 * Dart side's job, where it is tested. Permission is asked for in Dart first;
 * this only checks it and replies `NO_PERMISSION` or `QUERY_FAILED`. Never
 * throws into Flutter.
 */
class CalendarChannelHandler(
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
            "events" -> events(
                call.argument<Number>("begin")?.toLong(),
                call.argument<Number>("end")?.toLong(),
                result,
            )
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        executor.shutdown()
    }

    private fun events(begin: Long?, end: Long?, result: MethodChannel.Result) {
        if (begin == null || end == null || end < begin) {
            result.error("QUERY_FAILED", "bad range", null)
            return
        }
        if (context.checkSelfPermission(Manifest.permission.READ_CALENDAR) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.error("NO_PERMISSION", "calendar permission not granted", null)
            return
        }
        // A content query can be slow, so it runs off the main thread.
        executor.execute {
            try {
                val events = query(begin, end)
                mainHandler.post { result.success(events) }
            } catch (e: SecurityException) {
                mainHandler.post { result.error("NO_PERMISSION", e.message, null) }
            } catch (e: Exception) {
                mainHandler.post { result.error("QUERY_FAILED", e.message, null) }
            }
        }
    }

    private fun query(begin: Long, end: Long): List<Map<String, Any?>> {
        val uri = CalendarContract.Instances.CONTENT_URI.buildUpon().also {
            ContentUris.appendId(it, begin)
            ContentUris.appendId(it, end)
        }.build()
        val projection = arrayOf(
            CalendarContract.Instances.EVENT_ID,
            CalendarContract.Instances.TITLE,
            CalendarContract.Instances.BEGIN,
            CalendarContract.Instances.END,
            CalendarContract.Instances.ALL_DAY,
            CalendarContract.Instances.EVENT_LOCATION,
            CalendarContract.Instances.CALENDAR_DISPLAY_NAME,
            CalendarContract.Instances.EVENT_COLOR,
            CalendarContract.Instances.CALENDAR_COLOR,
        )
        // Only calendars the user has switched on, and not cancelled events.
        val selection = "${CalendarContract.Instances.VISIBLE} = 1 AND " +
            "(${CalendarContract.Instances.STATUS} IS NULL OR " +
            "${CalendarContract.Instances.STATUS} != ${CalendarContract.Events.STATUS_CANCELED})"
        val events = mutableListOf<Map<String, Any?>>()
        context.contentResolver
            .query(uri, projection, selection, null, "${CalendarContract.Instances.BEGIN} ASC")
            ?.use { cursor ->
                while (cursor.moveToNext() && events.size < MAX_EVENTS) {
                    events.add(
                        mapOf(
                            "id" to cursor.getLong(0),
                            "title" to cursor.getString(1),
                            "begin" to cursor.getLong(2),
                            "end" to cursor.getLong(3),
                            "allDay" to (cursor.getInt(4) != 0),
                            "location" to cursor.getString(5),
                            "calendar" to cursor.getString(6),
                            // The event's own colour, else its calendar's.
                            "color" to when {
                                !cursor.isNull(7) -> cursor.getInt(7)
                                !cursor.isNull(8) -> cursor.getInt(8)
                                else -> null
                            },
                        ),
                    )
                }
            }
        return events
    }

    companion object {
        const val CHANNEL = "com.codedbykay.android_terminal_launcher/calendar"

        // A month of a very busy calendar; more would only slow the log down.
        private const val MAX_EVENTS = 1000
    }
}
