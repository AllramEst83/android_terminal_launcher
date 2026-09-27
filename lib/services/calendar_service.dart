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
    this.description,
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

  /// The longer note under the title, for `event edit` to show and keep
  /// unless it is changed. Null when there is none.
  final String? description;
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

/// A calendar an event can be written to: one Android will actually accept an
/// insert for (`CALENDAR_ACCESS_LEVEL` at least contributor), which is why a
/// calendar someone only shared read-only with the user never appears here.
class CalendarInfo {
  const CalendarInfo({
    required this.id,
    required this.name,
    required this.accountName,
    required this.primary,
  });

  /// Android's id for the calendar; what an event is filed under.
  final int id;

  /// `Family`, or the account's own address when it has no separate name.
  final String name;

  /// The Google (or other) account it syncs under.
  final String accountName;

  /// Whether this is the account's own default calendar, for picking a
  /// sensible one when nothing has been used before.
  final bool primary;
}

/// A timed event to create or replace: no all-day events yet.
class NewCalendarEvent {
  const NewCalendarEvent({
    required this.calendarId,
    required this.title,
    this.description,
    required this.start,
    required this.end,
  });

  final int calendarId;
  final String title;
  final String? description;
  final DateTime start;
  final DateTime end;
}

sealed class CalendarListResult {
  const CalendarListResult();
}

class CalendarList extends CalendarListResult {
  const CalendarList(this.calendars);

  final List<CalendarInfo> calendars;
}

class CalendarListDenied extends CalendarListResult {
  const CalendarListDenied({required this.permanent});

  final bool permanent;
}

class CalendarListUnavailable extends CalendarListResult {
  const CalendarListUnavailable(this.reason);

  final String reason;
}

sealed class CalendarWriteResult {
  const CalendarWriteResult();
}

/// The event now exists (an add) or was changed (an edit); [id] is its
/// Android id either way.
class CalendarEventSaved extends CalendarWriteResult {
  const CalendarEventSaved(this.id);

  final int id;
}

class CalendarWriteDenied extends CalendarWriteResult {
  const CalendarWriteDenied({required this.permanent});

  final bool permanent;
}

class CalendarWriteFailed extends CalendarWriteResult {
  const CalendarWriteFailed(this.reason);

  final String reason;
}

sealed class CalendarDeleteResult {
  const CalendarDeleteResult();
}

class CalendarEventDeleted extends CalendarDeleteResult {
  const CalendarEventDeleted();
}

/// It was gone already (deleted elsewhere, or twice from this phone): not a
/// failure, since the end state is what was wanted.
class CalendarEventAlreadyGone extends CalendarDeleteResult {
  const CalendarEventAlreadyGone();
}

class CalendarDeleteDenied extends CalendarDeleteResult {
  const CalendarDeleteDenied({required this.permanent});

  final bool permanent;
}

class CalendarDeleteFailed extends CalendarDeleteResult {
  const CalendarDeleteFailed(this.reason);

  final String reason;
}

/// The phone's calendars (every account Android syncs), read through
/// Android's calendar provider. Asks for permission itself the first time.
abstract class CalendarService {
  /// Events overlapping the half-open range [from, to). Never throws; every
  /// failure is a [CalendarDenied] or [CalendarUnavailable].
  Future<CalendarResult> events({required DateTime from, required DateTime to});

  /// The calendars an event could be added to. Only needs read permission:
  /// which calendars are writable is itself a readable fact.
  Future<CalendarListResult> writableCalendars();

  /// Adds [event] as a new event. Never throws.
  Future<CalendarWriteResult> createEvent(NewCalendarEvent event);

  /// Replaces the event [id]'s fields with [event]'s. Never throws; a
  /// [CalendarWriteFailed] covers an event that no longer exists.
  Future<CalendarWriteResult> updateEvent(int id, NewCalendarEvent event);

  /// Removes the event [id]. Never throws.
  Future<CalendarDeleteResult> deleteEvent(int id);
}
