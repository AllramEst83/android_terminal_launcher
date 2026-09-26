import 'package:android_terminal_launcher/terminal/tools/weather_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('describeWeather', () {
    test('names the common codes', () {
      expect(describeWeather(0), 'Clear sky');
      expect(describeWeather(3), 'Overcast');
      expect(describeWeather(63), 'Rain');
      expect(describeWeather(73), 'Snow');
      expect(describeWeather(95), 'Thunderstorm');
    });

    test('a code it does not know is named rather than hidden', () {
      expect(describeWeather(7), 'Weather 7');
    });

    test('covers every code Open-Meteo documents', () {
      const documented = [
        0, 1, 2, 3, 45, 48, 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, //
        71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99,
      ];
      for (final code in documented) {
        expect(describeWeather(code), isNot('Weather $code'), reason: '$code');
      }
    });

    test('descriptions are short enough for a forecast line', () {
      for (var code = 0; code <= 99; code++) {
        final text = describeWeather(code);
        if (text.startsWith('Weather ')) continue;
        expect(text.length, lessThanOrEqualTo(18), reason: text);
      }
    });
  });

  group('compassPoint', () {
    test('the eight points', () {
      expect([0, 45, 90, 135, 180, 225, 270, 315].map(compassPoint), [
        'N',
        'NE',
        'E',
        'SE',
        'S',
        'SW',
        'W',
        'NW',
      ]);
    });

    test('rounds to the nearest point', () {
      expect(compassPoint(231), 'SW');
      expect(compassPoint(22), 'N');
      expect(compassPoint(23), 'NE');
      expect(compassPoint(337), 'NW');
      expect(compassPoint(338), 'N');
    });

    test('360 is north again, and negative or large angles wrap', () {
      expect(compassPoint(360), 'N');
      expect(compassPoint(-45), 'NW');
      expect(compassPoint(720 + 90), 'E');
    });
  });
}
