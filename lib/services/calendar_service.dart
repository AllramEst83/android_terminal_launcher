/// One occurrence of an event (a repeating event gives one of these per
/// repeat). All times are local.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.allDay = false,
    this.location,
    this.calendar,
    this.color,
  });

  /// The event's id in Android's calendar provider; shared by all repeats.
  final int id;
  final String title;

  /// For an all-day event, local midnight of its first day.
  final DateTime start;

  /// When it ends. For an all-day event, local midnight of the day *after* its
  /// last day, so every event is a half-open range whatever its kind.
  final DateTime end;
  final bool allDay;
  final String? location;

  /// The name of the calendar it belongs to (an account or "Birthdays").
  final String? calendar;

  /// The colour Android shows it in (the event's own, else its calendar's) as
  /// 0xAARRGGBB, or null if none was given.
  final int? color;
}

sealed class CalendarResult {
  const CalendarResult();
}

/// [events] is every occurrence that overlaps the range asked for, all-day
/// events first and then by start time.
class CalendarEvents extends CalendarResult {
  const CalendarEvents(this.events);

  final List<CalendarEvent> events;
}

/// The user said no. [permanent] means Android will no longer ask, so the
/// caller should say where the setting is instead of asking again.
class CalendarDenied extends CalendarResult {
  const CalendarDenied({required this.permanent});

  final bool permanent;
}

/// Permission is fine but the calendar could not be read; [reason] is short
/// and printable.
class CalendarUnavailable extends CalendarResult {
  const CalendarUnavailable(this.reason);

  final String reason;
}

/// The phone's calendars (every account Android syncs), read through
/// Android's calendar provider. Asks for permission itself the first time.
abstract class CalendarService {
  /// Events overlapping the half-open range [from, to). Never throws; every
  /// failure is a [CalendarDenied] or [CalendarUnavailable].
  Future<CalendarResult> events({required DateTime from, required DateTime to});
}
