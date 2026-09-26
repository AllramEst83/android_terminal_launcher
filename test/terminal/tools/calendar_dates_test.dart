import 'package:android_terminal_launcher/terminal/tools/calendar_dates.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 9, 26, 15, 30);

void main() {
  group('parseDay', () {
    test('words are relative to today, at midnight', () {
      expect(parseDay('today', _now), DateTime(2026, 9, 26));
      expect(parseDay('tomorrow', _now), DateTime(2026, 9, 27));
      expect(parseDay('yesterday', _now), DateTime(2026, 9, 25));
    });

    test('words ignore case', () {
      expect(parseDay('TODAY', _now), DateTime(2026, 9, 26));
    });

    test('tomorrow crosses a month end', () {
      expect(
        parseDay('tomorrow', DateTime(2026, 9, 30)),
        DateTime(2026, 10, 1),
      );
    });

    test('an ISO date', () {
      expect(parseDay('2026-10-03', _now), DateTime(2026, 10, 3));
      expect(parseDay('2026-1-3', _now), DateTime(2026, 1, 3));
    });

    test('a date that does not exist is not a date', () {
      expect(parseDay('2026-02-31', _now), isNull);
      expect(parseDay('2026-13-01', _now), isNull);
      expect(parseDay('2026-00-10', _now), isNull);
    });

    test('a leap day exists only in a leap year', () {
      expect(parseDay('2028-02-29', _now), DateTime(2028, 2, 29));
      expect(parseDay('2027-02-29', _now), isNull);
    });

    test('anything else is null', () {
      expect(parseDay('friday', _now), isNull);
      expect(parseDay('2026-09', _now), isNull);
      expect(parseDay('', _now), isNull);
    });
  });

  group('parseMonth', () {
    test('an ISO month is its first day', () {
      expect(parseMonth('2026-10', _now), DateTime(2026, 10));
      expect(parseMonth('2027-1', _now), DateTime(2027, 1));
    });

    test('this, next and last are relative to now', () {
      expect(parseMonth('this', _now), DateTime(2026, 9));
      expect(parseMonth('next', _now), DateTime(2026, 10));
      expect(parseMonth('last', _now), DateTime(2026, 8));
      expect(parseMonth('prev', _now), DateTime(2026, 8));
    });

    test('next and last cross a year end', () {
      expect(parseMonth('next', DateTime(2026, 12, 5)), DateTime(2027, 1));
      expect(parseMonth('last', DateTime(2026, 1, 5)), DateTime(2025, 12));
    });

    test('a month that does not exist is null', () {
      expect(parseMonth('2026-13', _now), isNull);
      expect(parseMonth('2026-00', _now), isNull);
      expect(parseMonth('october', _now), isNull);
    });
  });
}
