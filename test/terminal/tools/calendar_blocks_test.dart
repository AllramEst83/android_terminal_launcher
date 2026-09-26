import 'package:android_terminal_launcher/services/calendar_service.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/tools/calendar_blocks.dart';
import 'package:android_terminal_launcher/terminal/tools/calendar_text.dart';
import 'package:flutter_test/flutter_test.dart';

// Saturday 26 September 2026.
final _now = DateTime(2026, 9, 26, 15, 30);
final _today = DateTime(2026, 9, 26);

CalendarEvent _event(
  String title,
  DateTime start,
  DateTime end, {
  bool allDay = false,
  String? location,
  String? calendar,
  int? color,
}) => CalendarEvent(
  id: title.hashCode,
  title: title,
  start: start,
  end: end,
  allDay: allDay,
  location: location,
  calendar: calendar,
  color: color,
);

CalendarEvent _at(String title, int startHour, int endHour, {int day = 26}) =>
    _event(
      title,
      DateTime(2026, 9, day, startHour),
      DateTime(2026, 9, day, endHour),
    );

void main() {
  group('monthBlock', () {
    final month = DateTime(2026, 9);

    test('is September 2026, Monday first, in rows of seven', () {
      final block = monthBlock(const [], month, _today);

      expect(block.title, 'September 2026');
      expect(block.weekdays, ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']);
      expect(block.weeks, hasLength(5));
      expect(block.weeks.every((week) => week.length == 7), isTrue);
    });

    test('blank cells pad the first and last weeks', () {
      final weeks = monthBlock(const [], month, _today).weeks;

      // 1 September 2026 is a Tuesday.
      expect(weeks.first.take(2).map((d) => d?.day), [null, 1]);
      // The 30th is a Wednesday.
      expect(weeks.last.map((d) => d?.day), [
        28,
        29,
        30,
        null,
        null,
        null,
        null,
      ]);
    });

    test('a month that fills its weeks exactly has no blanks', () {
      final weeks = monthBlock(const [], DateTime(2027, 2), _today).weeks;

      expect(weeks, hasLength(4));
      expect(weeks.expand((week) => week).every((d) => d != null), isTrue);
    });

    test('every day of the month appears once, in order', () {
      final days = monthBlock(
        const [],
        month,
        _today,
      ).weeks.expand((week) => week).whereType<MonthDay>().map((d) => d.day);

      expect(days, [for (var d = 1; d <= 30; d++) d]);
    });

    test('only today is marked, and only in its own month', () {
      final today = monthBlock(const [], month, _today).weeks
          .expand((week) => week)
          .whereType<MonthDay>()
          .where((d) => d.today);
      expect(today.map((d) => d.day), [26]);

      final elsewhere = monthBlock(
        const [],
        DateTime(2026, 10),
        _today,
      ).weeks.expand((week) => week).whereType<MonthDay>();
      expect(elsewhere.any((d) => d.today), isFalse);
    });

    test(
      'counts the events on each day, a long one on every day it covers',
      () {
        final block = monthBlock(
          [
            _at('a', 9, 10),
            _at('b', 11, 12),
            _event(
              'trip',
              DateTime(2026, 9, 10),
              DateTime(2026, 9, 13),
              allDay: true,
            ),
          ],
          month,
          _today,
        );
        final byDay = {
          for (final d in block.weeks.expand((w) => w).whereType<MonthDay>())
            d.day: d.events,
        };

        expect(byDay[26], 2);
        expect(
          [byDay[9], byDay[10], byDay[11], byDay[12], byDay[13]],
          [0, 1, 1, 1, 0],
        );
      },
    );

    test('a day runs cal day with an ISO date', () {
      final days = monthBlock(
        const [],
        month,
        _today,
      ).weeks.expand((week) => week).whereType<MonthDay>();

      expect(days.first.command, 'cal day 2026-09-01');
      expect(days.last.command, 'cal day 2026-09-30');
    });

    test('the arrows run the neighbouring months, across year ends too', () {
      final september = monthBlock(const [], month, _today);
      expect(september.previousCommand, 'cal 2026-08');
      expect(september.nextCommand, 'cal 2026-10');

      expect(
        monthBlock(const [], DateTime(2026, 12), _today).nextCommand,
        'cal 2027-01',
      );
      expect(
        monthBlock(const [], DateTime(2026, 1), _today).previousCommand,
        'cal 2025-12',
      );
    });
  });

  group('agendaBlock', () {
    AgendaBlock agenda(
      Iterable<CalendarEvent> events, [
      List<DateTime>? days,
    ]) => agendaBlock(events, days ?? [_today], _now);

    test('one section per day, labelled, with today marked', () {
      final block = agenda(const [], [
        DateTime(2026, 9, 25),
        _today,
        DateTime(2026, 9, 27),
      ]);

      expect(block.days.map((d) => d.label), [
        'Fri 25 Sep',
        'Sat 26 Sep',
        'Sun 27 Sep',
      ]);
      expect(block.days.map((d) => d.today), [false, true, false]);
      expect(block.days.map((d) => d.command), [
        'cal day 2026-09-25',
        'cal day 2026-09-26',
        'cal day 2026-09-27',
      ]);
    });

    test('a quiet day has no entries', () {
      expect(agenda(const []).days.single.entries, isEmpty);
    });

    test('an entry carries times, title, place and colour', () {
      final entry = agenda([
        _event(
          'Standup',
          DateTime(2026, 9, 26, 9),
          DateTime(2026, 9, 26, 9, 30),
          location: 'Room 4',
          color: 0xFF336699,
        ),
      ]).days.single.entries.single;

      expect(entry.start, '09:00');
      expect(entry.end, '09:30');
      expect(entry.title, 'Standup');
      expect(entry.place, 'Room 4');
      expect(entry.color, 0xFF336699);
      expect(entry.allDay, isFalse);
    });

    test('an event without a title says so', () {
      final entry = agenda([_at('', 9, 10)]).days.single.entries.single;

      expect(entry.title, '(no title)');
    });

    test('all-day events come first, then by start time', () {
      final entries = agenda([
        _at('late', 17, 18),
        _at('early', 8, 9),
        _event('holiday', _today, DateTime(2026, 9, 27), allDay: true),
      ]).days.single.entries;

      expect(entries.map((e) => e.title), ['holiday', 'early', 'late']);
      expect(entries.first.allDay, isTrue);
      expect(entries.first.start, 'all day');
      expect(entries.first.end, isNull);
    });

    test('an event on several days is on each of them', () {
      final block = agenda(
        [_event('Fair', DateTime(2026, 9, 25, 20), DateTime(2026, 9, 27, 6))],
        [DateTime(2026, 9, 25), _today, DateTime(2026, 9, 27)],
      );

      final ends = [
        for (final day in block.days)
          (day.entries.single.start, day.entries.single.end),
      ];
      // The day in the middle has the event on it the whole day.
      expect(ends, [('20:00', '→'), ('all day', null), ('→', '06:00')]);
    });

    group('phase', () {
      List<EntryPhase> phases(List<CalendarEvent> events) => [
        for (final entry in agenda(events).days.single.entries) entry.phase,
      ];

      test('earlier today is past, under way is now, later is later', () {
        expect(
          phases([_at('over', 12, 13), _at('on', 15, 16), _at('next', 17, 18)]),
          [EntryPhase.past, EntryPhase.now, EntryPhase.later],
        );
      });

      test('an event ending exactly now is over, one starting now is on', () {
        expect(
          phases([
            _event('ends', DateTime(2026, 9, 26, 14), _now),
            _event('starts', _now, DateTime(2026, 9, 26, 16)),
          ]),
          [EntryPhase.past, EntryPhase.now],
        );
      });

      test('a moment is past once it has gone by', () {
        expect(
          phases([
            _event('gone', DateTime(2026, 9, 26, 9), DateTime(2026, 9, 26, 9)),
            _event(
              'coming',
              DateTime(2026, 9, 26, 18),
              DateTime(2026, 9, 26, 18),
            ),
          ]),
          [EntryPhase.past, EntryPhase.later],
        );
      });

      test(
        'an all-day event is never "now": today it is later, before today past',
        () {
          final holiday = _event(
            'h',
            _today,
            DateTime(2026, 9, 27),
            allDay: true,
          );
          expect(phases([holiday]), [EntryPhase.later]);

          final yesterday = agendaBlock(
            [_event('h', DateTime(2026, 9, 25), _today, allDay: true)],
            [DateTime(2026, 9, 25)],
            _now,
          );
          expect(yesterday.days.single.entries.single.phase, EntryPhase.past);
        },
      );

      test('everything on an earlier day is past, on a later day later', () {
        final block = agendaBlock(
          [_at('yesterday', 9, 10, day: 25), _at('tomorrow', 9, 10, day: 27)],
          [DateTime(2026, 9, 25), DateTime(2026, 9, 27)],
          _now,
        );

        expect(block.days.first.entries.single.phase, EntryPhase.past);
        expect(block.days.last.entries.single.phase, EntryPhase.later);
      });
    });

    group('legend', () {
      test('names each calendar once, with its colour, when there are two', () {
        final block = agenda([
          _event(
            'a',
            DateTime(2026, 9, 26, 9),
            DateTime(2026, 9, 26, 10),
            calendar: 'Work',
            color: 0xFF112233,
          ),
          _event(
            'b',
            DateTime(2026, 9, 26, 11),
            DateTime(2026, 9, 26, 12),
            calendar: 'Family',
            color: 0xFF445566,
          ),
          _event(
            'c',
            DateTime(2026, 9, 26, 13),
            DateTime(2026, 9, 26, 14),
            calendar: 'Work',
            color: 0xFF112233,
          ),
        ]);

        expect(block.legend.map((c) => c.name), ['Work', 'Family']);
        expect(block.legend.map((c) => c.color), [0xFF112233, 0xFF445566]);
      });

      test('is empty for one calendar, none, or events without a name', () {
        expect(
          agenda([
            _event(
              'a',
              DateTime(2026, 9, 26, 9),
              DateTime(2026, 9, 26, 10),
              calendar: 'Work',
            ),
          ]).legend,
          isEmpty,
        );
        expect(agenda(const []).legend, isEmpty);
        expect(agenda([_at('a', 9, 10), _at('b', 11, 12)]).legend, isEmpty);
      });

      test('only counts events that are shown', () {
        final block = agendaBlock(
          [
            _event(
              'a',
              DateTime(2026, 9, 26, 9),
              DateTime(2026, 9, 26, 10),
              calendar: 'Work',
            ),
            _event(
              'b',
              DateTime(2026, 9, 28, 9),
              DateTime(2026, 9, 28, 10),
              calendar: 'Family',
            ),
          ],
          [_today],
          _now,
        );

        expect(block.legend, isEmpty);
      });
    });
  });

  group('text helpers behind the block', () {
    test('dayLabel is the heading without the year', () {
      expect(dayLabel(_today), 'Sat 26 Sep');
      expect(dayHeading(_today), 'Sat 26 Sep 2026');
    });

    test('shortWeekdays starts on Monday', () {
      expect(shortWeekdays(), ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']);
    });

    test('eventTimes matches timeLabel for the same event', () {
      final cases = [
        _at('inside', 9, 10),
        _event('moment', DateTime(2026, 9, 26, 9), DateTime(2026, 9, 26, 9)),
        _event(
          'until midnight',
          DateTime(2026, 9, 26, 22),
          DateTime(2026, 9, 27),
        ),
        _event('starts', DateTime(2026, 9, 26, 20), DateTime(2026, 9, 27, 6)),
        _event('ends', DateTime(2026, 9, 25, 20), DateTime(2026, 9, 26, 6)),
        _event('spans', DateTime(2026, 9, 25, 20), DateTime(2026, 9, 27, 6)),
        _event('all day', _today, DateTime(2026, 9, 27), allDay: true),
      ];

      for (final event in cases) {
        final times = eventTimes(event, _today);
        final label = timeLabel(event, _today);
        expect(
          times.end == null ? times.start : '${times.start}-${times.end}',
          label.replaceAll('…', '→'),
          reason: event.title,
        );
      }
    });
  });
}
