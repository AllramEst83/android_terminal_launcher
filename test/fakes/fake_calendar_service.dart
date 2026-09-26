import 'package:android_terminal_launcher/services/calendar_service.dart';

/// Serves [result] (or, when it is [CalendarEvents], only the events that
/// overlap the range asked for, like the real service) and records each range.
class FakeCalendarService implements CalendarService {
  FakeCalendarService([this.result = const CalendarEvents([])]);

  CalendarResult result;

  /// Every `(from, to)` asked for, in order.
  final List<(DateTime, DateTime)> asked = [];

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
}
