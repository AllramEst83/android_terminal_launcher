import 'package:android_terminal_launcher/terminal/tools/clock_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseDuration', () {
    test('reads one unit', () {
      expect(parseDuration('90s'), const Duration(seconds: 90));
      expect(parseDuration('10m'), const Duration(minutes: 10));
      expect(parseDuration('2h'), const Duration(hours: 2));
    });

    test('reads units together', () {
      expect(parseDuration('1h30m'), const Duration(minutes: 90));
      expect(
        parseDuration('1h30m15s'),
        const Duration(hours: 1, minutes: 30, seconds: 15),
      );
      expect(parseDuration('2m30s'), const Duration(seconds: 150));
    });

    test('a bare number is minutes', () {
      expect(parseDuration('25'), const Duration(minutes: 25));
      expect(parseDuration('1.5'), const Duration(seconds: 90));
    });

    test('takes decimals, with a point or a comma', () {
      expect(parseDuration('1.5h'), const Duration(minutes: 90));
      expect(parseDuration('0,5m'), const Duration(seconds: 30));
    });

    test('takes the words for units, with or without a space', () {
      expect(parseDuration('10 min'), const Duration(minutes: 10));
      expect(parseDuration('10mins'), const Duration(minutes: 10));
      expect(parseDuration('2 hours'), const Duration(hours: 2));
      expect(parseDuration('1 hour 30 minutes'), const Duration(minutes: 90));
      expect(parseDuration('45 secs'), const Duration(seconds: 45));
    });

    test('ignores case and the space around it', () {
      expect(parseDuration('  10M '), const Duration(minutes: 10));
      expect(parseDuration('1H30M'), const Duration(minutes: 90));
    });

    test('rounds to a whole second', () {
      expect(parseDuration('0.4s'), Duration.zero);
      expect(parseDuration('1.6s'), const Duration(seconds: 2));
    });

    test('is not bounded: the caller says which way it was out', () {
      expect(parseDuration('0'), Duration.zero);
      expect(parseDuration('99h'), const Duration(hours: 99));
    });

    test('is null for anything else', () {
      for (final bad in [
        '',
        '   ',
        'abc',
        '10x',
        'm10',
        '10m5',
        '5ms',
        '1e3',
        '-5m',
        '10 m extra',
        '1h-30m',
        '..',
        '10:30',
      ]) {
        expect(parseDuration(bad), isNull, reason: "'$bad'");
      }
    });
  });

  group('formatDuration', () {
    test('is as short as it can be', () {
      expect(formatDuration(const Duration(minutes: 10)), '10 min');
      expect(formatDuration(const Duration(seconds: 45)), '45 s');
      expect(formatDuration(const Duration(hours: 2)), '2 h');
      expect(formatDuration(const Duration(minutes: 90)), '1 h 30 min');
      expect(
        formatDuration(const Duration(hours: 1, minutes: 5, seconds: 9)),
        '1 h 5 min 9 s',
      );
      expect(formatDuration(const Duration(seconds: 150)), '2 min 30 s');
    });
  });

  group('parseClockTime', () {
    test('reads the usual ways to write it', () {
      for (final text in ['07:30', '7:30', '7.30', '0730', '07.30']) {
        expect(parseClockTime(text), (hour: 7, minute: 30), reason: text);
      }
    });

    test('reads the 24-hour clock', () {
      expect(parseClockTime('19:45'), (hour: 19, minute: 45));
      expect(parseClockTime('23:59'), (hour: 23, minute: 59));
      expect(parseClockTime('0:00'), (hour: 0, minute: 0));
      expect(parseClockTime('1900'), (hour: 19, minute: 0));
    });

    test('a bare hour is on the hour', () {
      expect(parseClockTime('7'), (hour: 7, minute: 0));
      expect(parseClockTime('18'), (hour: 18, minute: 0));
    });

    test('reads am and pm, with or without a space', () {
      expect(parseClockTime('7am'), (hour: 7, minute: 0));
      expect(parseClockTime('7pm'), (hour: 19, minute: 0));
      expect(parseClockTime('7:30 pm'), (hour: 19, minute: 30));
      expect(parseClockTime('7:30PM'), (hour: 19, minute: 30));
    });

    test('twelve o\'clock is the odd one', () {
      expect(parseClockTime('12am'), (hour: 0, minute: 0));
      expect(parseClockTime('12pm'), (hour: 12, minute: 0));
      expect(parseClockTime('12:30am'), (hour: 0, minute: 30));
      expect(parseClockTime('12:30pm'), (hour: 12, minute: 30));
    });

    test('is null for what is not a time of day', () {
      for (final bad in [
        '',
        'noon',
        '24:00',
        '25',
        '7:60',
        '7:5',
        '13pm',
        '0pm',
        '0am',
        '2500',
        '1260',
        '7:30:15',
        '-1',
        '7 30',
        'am',
      ]) {
        expect(parseClockTime(bad), isNull, reason: "'$bad'");
      }
    });
  });

  group('nextOccurrence', () {
    final now = DateTime(2026, 9, 26, 15, 30);

    test('is today if the time is still to come', () {
      expect(
        nextOccurrence(now, (hour: 18, minute: 0)),
        DateTime(2026, 9, 26, 18),
      );
    });

    test('is tomorrow if it has passed', () {
      expect(
        nextOccurrence(now, (hour: 7, minute: 30)),
        DateTime(2026, 9, 27, 7, 30),
      );
    });

    test('this very minute has passed', () {
      expect(
        nextOccurrence(now, (hour: 15, minute: 30)),
        DateTime(2026, 9, 27, 15, 30),
      );
    });

    test('goes over the end of a month and a year', () {
      expect(
        nextOccurrence(DateTime(2026, 12, 31, 23, 0), (hour: 6, minute: 0)),
        DateTime(2027, 1, 1, 6),
      );
    });
  });

  test('clockText pads', () {
    expect(clockText(7, 5), '07:05');
    expect(clockText(19, 45), '19:45');
    expect(clockText(0, 0), '00:00');
  });

  group('parseDays', () {
    test('reads a day by its short or full name', () {
      expect(parseDays('mon'), [1]);
      expect(parseDays('Monday'), [1]);
      expect(parseDays('tues'), [2]);
      expect(parseDays('WED'), [3]);
      expect(parseDays('thurs'), [4]);
      expect(parseDays('fri'), [5]);
      expect(parseDays('saturday'), [6]);
      expect(parseDays('sun'), [7]);
    });

    test('reads the groups', () {
      expect(parseDays('weekdays'), [1, 2, 3, 4, 5]);
      expect(parseDays('weekend'), [6, 7]);
      expect(parseDays('daily'), [1, 2, 3, 4, 5, 6, 7]);
    });

    test('is null for other words', () {
      for (final bad in ['gym', 'mo', 'monkey', 'm', '', 'tomorrow', 'sunny']) {
        expect(parseDays(bad), isNull, reason: "'$bad'");
      }
    });
  });

  group('describeDays', () {
    test('a run of days is a range', () {
      expect(describeDays([1, 2, 3, 4, 5]), 'Mon-Fri');
      expect(describeDays([2, 3, 4]), 'Tue-Thu');
    });

    test('days apart are listed', () {
      expect(describeDays([1, 3, 5]), 'Mon Wed Fri');
      expect(describeDays([6, 7]), 'Sat Sun');
      expect(describeDays([4]), 'Thu');
    });

    test('every day is daily', () {
      expect(describeDays([1, 2, 3, 4, 5, 6, 7]), 'daily');
    });

    test('order and repeats do not matter', () {
      expect(describeDays([5, 1, 3, 1]), 'Mon Wed Fri');
    });
  });
}
