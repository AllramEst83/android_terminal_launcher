import 'package:android_terminal_launcher/services/calendar_service.dart';

/// Serves [result] (or, when it is [CalendarEvents], only the events that
/// overlap the range asked for, like the real service) and records each range.
/// [listResult], [writeResult] and [deleteResult] script the write side the
/// same way; each call is recorded so a test can check what was sent.
class FakeCalendarService implements CalendarService {
  FakeCalendarService([this.result = const CalendarEvents([])]);

  CalendarResult result;
  CalendarListResult listResult = const CalendarList([]);
  CalendarWriteResult writeResult = const CalendarEventSaved(1);
  CalendarDeleteResult deleteResult = const CalendarEventDeleted();

  /// Every `(from, to)` asked for, in order.
  final List<(DateTime, DateTime)> asked = [];

  /// Every event created, in order.
  final List<NewCalendarEvent> created = [];

  /// Every `(id, event)` given to [updateEvent], in order.
  final List<(int, NewCalendarEvent)> updated = [];

  /// Every id given to [deleteEvent], in order.
  final List<int> deleted = [];

  @override
  Future<CalendarResult> events({
    required DateTime from,
    required DateTime to,
  }) async {
    asked.add((from, to));
    final answer = result;
    if (answer is! CalendarEvents) return answer;
    return CalendarEvents([
      for (final event in answer.events)
        if (event.start.isBefore(to) &&
            (event.end.isAfter(from) ||
                (event.end == event.start && !event.start.isBefore(from))))
          event,
    ]);
  }

  @override
  Future<CalendarListResult> writableCalendars() async => listResult;

  @override
  Future<CalendarWriteResult> createEvent(NewCalendarEvent event) async {
    created.add(event);
    return writeResult;
  }

  @override
  Future<CalendarWriteResult> updateEvent(
    int id,
    NewCalendarEvent event,
  ) async {
    updated.add((id, event));
    return writeResult;
  }

  @override
  Future<CalendarDeleteResult> deleteEvent(int id) async {
    deleted.add(id);
    return deleteResult;
  }
}
