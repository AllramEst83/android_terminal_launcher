import 'package:android_terminal_launcher/services/calendar_service.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Width of the month grid: seven cells of [_cell] characters.
const monthGridColumns = 28;
const _cell = 4;

/// Midnight at the start of [day]'s date, whatever time it carries.
DateTime startOfDay(DateTime day) => DateTime(day.year, day.month, day.day);

/// `startOfDay` plus [days] calendar days. Calendar days, not 24 hours, so a
/// daylight-saving change never lands it on 23:00 or 01:00.
DateTime addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

/// The Monday on or before [day].
DateTime startOfWeek(DateTime day) => addDays(day, 1 - day.weekday);

/// `Sep`.
String shortMonth(DateTime day) => _months[day.month - 1].substring(0, 3);

/// `Mon`.
String shortWeekday(DateTime day) => _weekdays[day.weekday - 1];

/// `Sat 26 Sep`.
String dayLabel(DateTime day) =>
    '${shortWeekday(day)} ${day.day} ${shortMonth(day)}';

/// `Sat 26 Sep 2026`.
String dayHeading(DateTime day) => '${dayLabel(day)} ${day.year}';

/// The two-letter weekday names, Monday first: `Mo`, `Tu`, ...
List<String> shortWeekdays() => [
  for (final name in _weekdays) name.substring(0, 2),
];

/// `September 2026`.
String monthHeading(DateTime month) =>
    '${_months[month.month - 1]} ${month.year}';

/// Whether [event] takes place on any part of [day].
bool happensOn(CalendarEvent event, DateTime day) {
  final from = startOfDay(day);
  final to = addDays(from, 1);
  if (event.end == event.start) {
    return !event.start.isBefore(from) && event.start.isBefore(to);
  }
  return event.start.isBefore(to) && event.end.isAfter(from);
}

/// The events on [day]: all-day ones first, then by start time.
List<CalendarEvent> eventsOn(Iterable<CalendarEvent> events, DateTime day) {
  return [
    for (final event in events)
      if (happensOn(event, day)) event,
  ]..sort((a, b) {
    if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
    return a.start.compareTo(b.start);
  });
}

String _hhmm(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// When [event] is on [day], in 11 characters: `09:00-10:00`, or `all day`.
/// An event that crosses midnight shows only the part on this day's side.
String timeLabel(CalendarEvent event, DateTime day) {
  if (event.allDay) return 'all day';
  final from = startOfDay(day);
  final to = addDays(from, 1);
  final startsToday = !event.start.isBefore(from);
  final endsToday = !event.end.isAfter(to);
  if (startsToday && event.end == event.start) return _hhmm(event.start);
  if (startsToday && endsToday) {
    // Ending exactly at midnight is the end of this day, not 00:00 tomorrow.
    final end = event.end == to ? '24:00' : _hhmm(event.end);
    return '${_hhmm(event.start)}-$end';
  }
  if (startsToday) return '${_hhmm(event.start)}-…';
  if (endsToday) return '…-${event.end == to ? '24:00' : _hhmm(event.end)}';
  return 'all day';
}

/// The same as [timeLabel] but as the two ends of a column: `('09:00',
/// '10:00')`, `('all day', null)`, a moment as `('09:00', null)`. `→` stands
/// for an end (or a start) on another day.
({String start, String? end}) eventTimes(CalendarEvent event, DateTime day) {
  if (event.allDay) return (start: 'all day', end: null);
  final from = startOfDay(day);
  final to = addDays(from, 1);
  final startsToday = !event.start.isBefore(from);
  final endsToday = !event.end.isAfter(to);
  String endTime() => event.end == to ? '24:00' : _hhmm(event.end);
  if (startsToday && event.end == event.start) {
    return (start: _hhmm(event.start), end: null);
  }
  if (startsToday && endsToday) {
    return (start: _hhmm(event.start), end: endTime());
  }
  if (startsToday) return (start: _hhmm(event.start), end: '→');
  if (endsToday) return (start: '→', end: endTime());
  return (start: 'all day', end: null);
}

/// One line for [event] on [day]: `09:00-10:00 Standup @ Room 4`.
String eventLine(CalendarEvent event, DateTime day) {
  final title = event.title.isEmpty ? '(no title)' : event.title;
  final place = event.location == null ? '' : ' @ ${event.location}';
  return '${timeLabel(event, day).padRight(11)} $title$place';
}

/// The day's heading, then its events, or a line saying there are none.
List<String> dayView(Iterable<CalendarEvent> events, DateTime day) {
  final today = eventsOn(events, day);
  return [
    dayHeading(day),
    if (today.isEmpty) 'no events',
    for (final event in today) eventLine(event, day),
  ];
}

/// Seven days from the Monday of [day]'s week. A day with nothing on it is one
/// line, so a quiet week stays short.
List<String> weekView(
  Iterable<CalendarEvent> events,
  DateTime day,
  DateTime today,
) {
  final monday = startOfWeek(day);
  final lines = <String>[];
  for (var i = 0; i < 7; i++) {
    final date = addDays(monday, i);
    final mark = startOfDay(date) == startOfDay(today) ? ' (today)' : '';
    final onDate = eventsOn(events, date);
    lines.add('${dayHeading(date)}$mark${onDate.isEmpty ? '  -' : ''}');
    for (final event in onDate) {
      lines.add('  ${eventLine(event, date)}');
    }
  }
  return lines;
}

/// A month laid out Monday to Sunday, [monthGridColumns] wide: `>` before
/// today's number, `*` after the number of a day with events. Every line is
/// at most that wide, so the UI can treat it as a fixed-width grid.
List<String> monthGrid(
  Iterable<CalendarEvent> events,
  DateTime month,
  DateTime today,
) {
  final first = DateTime(month.year, month.month);
  final days = DateTime(month.year, month.month + 1, 0).day;
  final title = monthHeading(first);
  final cells = <String>[
    for (var i = 0; i < first.weekday - 1; i++) ' ' * _cell,
    for (var day = 1; day <= days; day++)
      _dayCell(
        day,
        isToday: startOfDay(today) == DateTime(month.year, month.month, day),
        busy: events.any(
          (event) => happensOn(event, DateTime(month.year, month.month, day)),
        ),
      ),
  ];
  final header = [for (final name in _weekdays) ' ${name.substring(0, 2)} '];
  return [
    title.padLeft((monthGridColumns + title.length) ~/ 2),
    header.join().trimRight(),
    for (var i = 0; i < cells.length; i += 7)
      cells.skip(i).take(7).join().trimRight(),
    '> today  * has events',
  ];
}

String _dayCell(int day, {required bool isToday, required bool busy}) =>
    '${isToday ? '>' : ' '}${day.toString().padLeft(2)}${busy ? '*' : ' '}';
