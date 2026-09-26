import 'package:android_terminal_launcher/services/calendar_service.dart';
import 'package:android_terminal_launcher/terminal/tools/calendar_text.dart';
import 'package:flutter_test/flutter_test.dart';

// 26 September 2026 is a Saturday; 1 September is a Tuesday.
final _saturday = DateTime(2026, 9, 26);

CalendarEvent _timed(
  String title,
  DateTime start,
  DateTime end, {
  String? location,
}) => CalendarEvent(
  id: 1,
  title: title,
  start: start,
  end: end,
  location: location,
);

CalendarEvent _allDay(String title, DateTime first, {int days = 1}) =>
    CalendarEvent(
      id: 2,
      title: title,
      start: first,
      end: addDays(first, days),
      allDay: true,
    );

void main() {
  group('dates', () {
    test('a heading names the weekday, day, month and year', () {
      expect(dayHeading(_saturday), 'Sat 26 Sep 2026');
      expect(monthHeading(_saturday), 'September 2026');
    });

    test('the week starts on Monday, also from a Sunday', () {
      expect(startOfWeek(_saturday), DateTime(2026, 9, 21));
      expect(startOfWeek(DateTime(2026, 9, 27)), DateTime(2026, 9, 21));
      expect(startOfWeek(DateTime(2026, 9, 21)), DateTime(2026, 9, 21));
    });

    test('adding days crosses month and year ends', () {
      expect(addDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
      expect(addDays(DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
    });

    test('start of day drops the time', () {
      expect(startOfDay(DateTime(2026, 9, 26, 15, 30)), _saturday);
    });
  });

  group('timeLabel', () {
    test('a timed event inside the day shows start and end', () {
      final event = _timed(
        'x',
        DateTime(2026, 9, 26, 9),
        DateTime(2026, 9, 26, 10, 30),
      );

      expect(timeLabel(event, _saturday), '09:00-10:30');
    });

    test('an event with no length shows just its time', () {
      final at = DateTime(2026, 9, 26, 7, 5);

      expect(timeLabel(_timed('x', at, at), _saturday), '07:05');
    });

    test('all-day events say so', () {
      expect(timeLabel(_allDay('x', _saturday), _saturday), 'all day');
    });

    test("an event running past midnight shows only each day's side", () {
      final event = _timed(
        'x',
        DateTime(2026, 9, 26, 22),
        DateTime(2026, 9, 27, 2),
      );

      expect(timeLabel(event, _saturday), '22:00-…');
      expect(timeLabel(event, DateTime(2026, 9, 27)), '…-02:00');
    });

    test('an event ending at midnight ends at 24:00, not 00:00', () {
      final event = _timed(
        'x',
        DateTime(2026, 9, 26, 20),
        DateTime(2026, 9, 27),
      );

      expect(timeLabel(event, _saturday), '20:00-24:00');
    });

    test('a middle day of a long timed event is all day', () {
      final event = _timed(
        'x',
        DateTime(2026, 9, 25, 12),
        DateTime(2026, 9, 28, 12),
      );

      expect(timeLabel(event, _saturday), 'all day');
    });

    test('every label fits its 11-character column', () {
      final event = _timed(
        'x',
        DateTime(2026, 9, 26, 22),
        DateTime(2026, 9, 27, 2),
      );

      for (final day in [_saturday, DateTime(2026, 9, 27)]) {
        expect(timeLabel(event, day).length, lessThanOrEqualTo(11));
      }
    });
  });

  group('eventLine', () {
    test('pads the time, then the title', () {
      final event = _timed(
        'Standup',
        DateTime(2026, 9, 26, 9),
        DateTime(2026, 9, 26, 9, 15),
      );

      expect(eventLine(event, _saturday), '09:00-09:15 Standup');
    });

    test('adds the place, and names an untitled event', () {
      final event = _timed(
        '',
        DateTime(2026, 9, 26, 9),
        DateTime(2026, 9, 26, 10),
        location: 'Room 4',
      );

      expect(eventLine(event, _saturday), '09:00-10:00 (no title) @ Room 4');
    });

    test('all-day lines align with timed ones', () {
      expect(
        eventLine(_allDay('Holiday', _saturday), _saturday),
        'all day     Holiday',
      );
    });
  });

  group('eventsOn', () {
    test('all-day first, then by start time', () {
      final late = _timed(
        'late',
        DateTime(2026, 9, 26, 15),
        DateTime(2026, 9, 26, 16),
      );
      final early = _timed(
        'early',
        DateTime(2026, 9, 26, 8),
        DateTime(2026, 9, 26, 9),
      );
      final holiday = _allDay('holiday', _saturday);

      expect(eventsOn([late, early, holiday], _saturday), [
        holiday,
        early,
        late,
      ]);
    });

    test('a multi-day all-day event is on each of its days but not after', () {
      final trip = _allDay('trip', DateTime(2026, 9, 25), days: 2);

      expect(happensOn(trip, DateTime(2026, 9, 25)), isTrue);
      expect(happensOn(trip, DateTime(2026, 9, 26)), isTrue);
      expect(happensOn(trip, DateTime(2026, 9, 27)), isFalse);
      expect(happensOn(trip, DateTime(2026, 9, 24)), isFalse);
    });

    test('an event ending at midnight is not on the next day', () {
      final event = _timed(
        'x',
        DateTime(2026, 9, 26, 20),
        DateTime(2026, 9, 27),
      );

      expect(happensOn(event, DateTime(2026, 9, 27)), isFalse);
    });

    test('a moment is on the day it happens', () {
      final at = DateTime(2026, 9, 26, 12);
      final moment = _timed('x', at, at);

      expect(happensOn(moment, _saturday), isTrue);
      expect(happensOn(moment, DateTime(2026, 9, 27)), isFalse);
    });
  });

  group('dayView', () {
    test('a heading, then the events', () {
      final event = _timed(
        'Lunch',
        DateTime(2026, 9, 26, 12),
        DateTime(2026, 9, 26, 13),
      );

      expect(dayView([event], _saturday), [
        'Sat 26 Sep 2026',
        '12:00-13:00 Lunch',
      ]);
    });

    test('an empty day says so', () {
      expect(dayView(const [], _saturday), ['Sat 26 Sep 2026', 'no events']);
    });
  });

  group('weekView', () {
    test('seven days from Monday, today marked, quiet days on one line', () {
      final event = _timed(
        'Lunch',
        DateTime(2026, 9, 23, 12),
        DateTime(2026, 9, 23, 13),
      );

      expect(weekView([event], _saturday, _saturday), [
        'Mon 21 Sep 2026  -',
        'Tue 22 Sep 2026  -',
        'Wed 23 Sep 2026',
        '  12:00-13:00 Lunch',
        'Thu 24 Sep 2026  -',
        'Fri 25 Sep 2026  -',
        'Sat 26 Sep 2026 (today)  -',
        'Sun 27 Sep 2026  -',
      ]);
    });
  });

  group('monthGrid', () {
    test('lays September 2026 out Monday to Sunday', () {
      final events = [
        _timed('a', DateTime(2026, 9, 3, 9), DateTime(2026, 9, 3, 10)),
        _timed('b', DateTime(2026, 9, 26, 9), DateTime(2026, 9, 26, 10)),
      ];

      expect(monthGrid(events, DateTime(2026, 9), _saturday), [
        '       September 2026',
        ' Mo  Tu  We  Th  Fr  Sa  Su',
        '      1   2   3*  4   5   6',
        '  7   8   9  10  11  12  13',
        ' 14  15  16  17  18  19  20',
        ' 21  22  23  24  25 >26* 27',
        ' 28  29  30',
        '> today  * has events',
      ]);
    });

    test('a month that starts on a Sunday has six blank cells first', () {
      final lines = monthGrid(const [], DateTime(2026, 2), _saturday);

      expect(lines[2], '                          1');
    });

    test('a month starting on a Sunday takes five rows', () {
      final lines = monthGrid(const [], DateTime(2026, 2), _saturday);

      // title, header, 5 rows (a lone Sunday, then four full weeks), legend.
      expect(lines, hasLength(2 + 5 + 1));
    });

    test('a month can need six rows', () {
      // 1 Aug 2026 is a Saturday, so 31 days spill into a sixth week.
      final lines = monthGrid(const [], DateTime(2026, 8), _saturday);

      expect(lines, hasLength(2 + 6 + 1));
    });

    test('no line is wider than the grid', () {
      for (var month = 1; month <= 12; month++) {
        final lines = monthGrid(const [], DateTime(2026, month), _saturday);
        for (final line in lines) {
          expect(
            line.length,
            lessThanOrEqualTo(monthGridColumns),
            reason: line,
          );
        }
      }
    });

    test('an all-day event marks every day it covers', () {
      final trip = _allDay('trip', DateTime(2026, 9, 10), days: 2);
      final lines = monthGrid([trip], DateTime(2026, 9), _saturday);

      expect(lines[3], '  7   8   9  10* 11* 12  13');
    });

    test('an event from another month marks nothing', () {
      final other = _allDay('x', DateTime(2026, 10, 3));
      final lines = monthGrid([other], DateTime(2026, 9), _saturday);

      expect(lines.skip(2).take(5).join(), isNot(contains('*')));
    });

    test('today is only marked in its own month', () {
      final lines = monthGrid(const [], DateTime(2026, 10), _saturday);

      expect(lines.skip(1).take(6).join(), isNot(contains('>')));
    });
  });
}
