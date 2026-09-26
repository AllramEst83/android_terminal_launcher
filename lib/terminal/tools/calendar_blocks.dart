import 'package:android_terminal_launcher/services/calendar_service.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/tools/calendar_text.dart';

/// `2026-09-26`, the form `cal` accepts.
String isoDate(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

String _isoMonth(DateTime month) =>
    '${month.year.toString().padLeft(4, '0')}-'
    '${month.month.toString().padLeft(2, '0')}';

/// [monthGrid] as a [MonthBlock]: the same month, with a count of events per
/// day instead of a `*`, and a command behind every day and both arrows.
MonthBlock monthBlock(
  Iterable<CalendarEvent> events,
  DateTime month,
  DateTime today,
) {
  final first = DateTime(month.year, month.month);
  final days = DateTime(month.year, month.month + 1, 0).day;
  final cells = <MonthDay?>[
    for (var i = 0; i < first.weekday - 1; i++) null,
    for (var day = 1; day <= days; day++)
      _monthDay(events, DateTime(month.year, month.month, day), today),
  ];
  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  return MonthBlock(
    title: monthHeading(first),
    weekdays: shortWeekdays(),
    weeks: [for (var i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7)],
    previousCommand: 'cal ${_isoMonth(DateTime(first.year, first.month - 1))}',
    nextCommand: 'cal ${_isoMonth(DateTime(first.year, first.month + 1))}',
  );
}

MonthDay _monthDay(
  Iterable<CalendarEvent> events,
  DateTime date,
  DateTime today,
) => MonthDay(
  day: date.day,
  events: events.where((event) => happensOn(event, date)).length,
  today: startOfDay(today) == date,
  command: 'cal day ${isoDate(date)}',
);

/// The [days] (midnights, in order) with the events on each, as an
/// [AgendaBlock]. [now] decides which of today's events are over or under way.
AgendaBlock agendaBlock(
  Iterable<CalendarEvent> events,
  List<DateTime> days,
  DateTime now,
) {
  final today = startOfDay(now);
  final shown = <CalendarEvent>[];
  final agendaDays = <AgendaDay>[];
  for (final day in days) {
    final onDay = eventsOn(events, day);
    shown.addAll(onDay);
    agendaDays.add(
      AgendaDay(
        label: dayLabel(day),
        today: day == today,
        command: 'cal day ${isoDate(day)}',
        entries: [for (final event in onDay) _entry(event, day, now)],
      ),
    );
  }
  return AgendaBlock(days: agendaDays, legend: _legend(shown));
}

AgendaEntry _entry(CalendarEvent event, DateTime day, DateTime now) {
  final times = eventTimes(event, day);
  return AgendaEntry(
    start: times.start,
    end: times.end,
    title: event.title.isEmpty ? '(no title)' : event.title,
    place: event.location,
    color: event.color,
    allDay: event.allDay,
    phase: _phase(event, day, now),
  );
}

EntryPhase _phase(CalendarEvent event, DateTime day, DateTime now) {
  if (event.allDay) {
    return day.isBefore(startOfDay(now)) ? EntryPhase.past : EntryPhase.later;
  }
  if (event.end == event.start) {
    return now.isAfter(event.start) ? EntryPhase.past : EntryPhase.later;
  }
  if (!now.isBefore(event.end)) return EntryPhase.past;
  if (!now.isBefore(event.start)) return EntryPhase.now;
  return EntryPhase.later;
}

/// One entry per calendar name, but only when there are two or more: a single
/// colour needs no key.
List<AgendaCalendar> _legend(Iterable<CalendarEvent> events) {
  final colours = <String, int?>{};
  for (final event in events) {
    final name = event.calendar;
    if (name == null) continue;
    colours[name] ??= event.color;
  }
  if (colours.length < 2) return const [];
  return [
    for (final entry in colours.entries)
      AgendaCalendar(name: entry.key, color: entry.value),
  ];
}
