import 'package:android_terminal_launcher/terminal/tools/calendar_dates.dart';
import 'package:android_terminal_launcher/terminal/tools/clock_input.dart';

/// A start answer: a bare time (`14:00`, `9am`, `0730`), meaning today, or
/// tomorrow if that has already passed — the same rule `alarm` uses — or a
/// day word/date plus a time (`today 14:00`, `tomorrow 9am`,
/// `2026-10-02 10:00`). Null when it is neither.
DateTime? parseEventStart(String text, DateTime now) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length == 1) {
    final time = parseClockTime(parts[0]);
    return time == null ? null : nextOccurrence(now, time);
  }
  if (parts.length != 2) return null;
  final time = parseClockTime(parts[1]);
  if (time == null) return null;
  final day = parseDay(parts[0], now);
  if (day == null) return null;
  return DateTime(day.year, day.month, day.day, time.hour, time.minute);
}

/// An end answer, after [start]: a bare or explicit time for the same day as
/// [start] (the day after, if that would be before [start] — an overnight
/// event), a day word/date plus a time (exactly as [parseEventStart]), or —
/// only once neither of those fits — how long after [start] (`1h`, `30m`,
/// `1h 30m`; a bare number is minutes, as it is for `timer`). Null when it is
/// none of those.
DateTime? parseEventEnd(String text, DateTime start, DateTime now) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  if (!trimmed.contains(' ')) {
    final time = parseClockTime(trimmed);
    if (time != null) {
      final sameDay = DateTime(
        start.year,
        start.month,
        start.day,
        time.hour,
        time.minute,
      );
      return sameDay.isBefore(start)
          ? DateTime(
              start.year,
              start.month,
              start.day + 1,
              time.hour,
              time.minute,
            )
          : sameDay;
    }
  }

  final asDayAndTime = parseEventStart(trimmed, now);
  if (asDayAndTime != null) return asDayAndTime;

  final duration = parseDuration(trimmed);
  return duration == null ? null : start.add(duration);
}
