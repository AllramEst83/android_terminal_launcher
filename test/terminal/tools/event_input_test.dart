import 'package:android_terminal_launcher/terminal/tools/event_input.dart';
import 'package:flutter_test/flutter_test.dart';

// Saturday 26 September 2026, 15:30.
final _now = DateTime(2026, 9, 26, 15, 30);

void main() {
  group('parseEventStart', () {
    test('a bare time later today is today', () {
      expect(parseEventStart('18:00', _now), DateTime(2026, 9, 26, 18));
    });

    test('a bare time already past today is tomorrow', () {
      expect(parseEventStart('09:00', _now), DateTime(2026, 9, 27, 9));
    });

    test('takes the other ways to write a time', () {
      expect(parseEventStart('7pm', _now), DateTime(2026, 9, 26, 19));
      expect(parseEventStart('0700', _now), DateTime(2026, 9, 27, 7));
    });

    test('a day word or date plus a time', () {
      expect(parseEventStart('today 20:00', _now), DateTime(2026, 9, 26, 20));
      expect(parseEventStart('tomorrow 9am', _now), DateTime(2026, 9, 27, 9));
      expect(
        parseEventStart('2026-10-02 10:00', _now),
        DateTime(2026, 10, 2, 10),
      );
    });

    test('a day word with no time is not enough', () {
      expect(parseEventStart('tomorrow', _now), isNull);
    });

    test('anything else is null', () {
      expect(parseEventStart('', _now), isNull);
      expect(parseEventStart('soon', _now), isNull);
      expect(parseEventStart('today now', _now), isNull);
      expect(parseEventStart('a b c', _now), isNull);
    });
  });

  group('parseEventEnd', () {
    final start = DateTime(2026, 9, 26, 10);

    test('a bare or explicit time later the same day', () {
      expect(parseEventEnd('11:00', start, _now), DateTime(2026, 9, 26, 11));
      expect(parseEventEnd('2300', start, _now), DateTime(2026, 9, 26, 23));
      expect(parseEventEnd('11am', start, _now), DateTime(2026, 9, 26, 11));
    });

    test('a time earlier than the start rolls to the day after', () {
      expect(parseEventEnd('09:00', start, _now), DateTime(2026, 9, 27, 9));
    });

    test('a day word or date plus a time, like a start answer', () {
      expect(
        parseEventEnd('tomorrow 09:00', start, _now),
        DateTime(2026, 9, 27, 9),
      );
    });

    test('a length of time, only once it is not a time', () {
      expect(parseEventEnd('1h', start, _now), DateTime(2026, 9, 26, 11));
      expect(parseEventEnd('30m', start, _now), DateTime(2026, 9, 26, 10, 30));
      expect(
        parseEventEnd('1h 30m', start, _now),
        DateTime(2026, 9, 26, 11, 30),
      );
    });

    test('a bare number is minutes, not a compact time', () {
      expect(parseEventEnd('30', start, _now), DateTime(2026, 9, 26, 10, 30));
    });

    test('a compact time is never mistaken for minutes', () {
      // 0730 as 730 minutes would be almost 13 hours away; it means 07:30.
      expect(parseEventEnd('0730', start, _now), DateTime(2026, 9, 27, 7, 30));
    });

    test('anything else is null', () {
      expect(parseEventEnd('', start, _now), isNull);
      expect(parseEventEnd('soon', start, _now), isNull);
    });
  });
}
