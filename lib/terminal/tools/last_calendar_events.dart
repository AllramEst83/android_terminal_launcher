import 'package:android_terminal_launcher/services/calendar_service.dart';

/// The events `cal day`/`cal week` last showed, in the order they were shown
/// (day by day, all-day first then by start time) — this is what a number
/// from `event edit`/`event rm` refers to, and what `#<id>` falls back to when
/// the list has moved on. `cal month` never touches this: it shows no
/// individual events. Shared by `cal` (which fills it) and `event` (which
/// reads it), built once in `CalendarProvider`.
class LastCalendarEvents {
  List<CalendarEvent> _events = const [];

  void show(List<CalendarEvent> events) => _events = events;

  bool get isEmpty => _events.isEmpty;

  /// The event [target] names: `2` is the second of the last list, `#482` is
  /// the event with that real id (what a card's button fills, so it still
  /// means the same event however the list has changed since). Null when it
  /// names nothing shown.
  CalendarEvent? find(String target) {
    if (target.startsWith('#')) {
      final id = int.tryParse(target.substring(1));
      if (id == null) return null;
      return _events.where((event) => event.id == id).firstOrNull;
    }
    final number = int.tryParse(target);
    if (number == null || number < 1 || number > _events.length) return null;
    return _events[number - 1];
  }
}
