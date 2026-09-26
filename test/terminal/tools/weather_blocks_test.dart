import 'dart:io';

import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/weather.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/tools/weather_blocks.dart';
import 'package:android_terminal_launcher/terminal/tools/weather_text.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_http_fetcher.dart';
import '../../fakes/in_memory_local_store.dart';

const _place = Place(
  name: 'Gothenburg',
  region: 'Västra Götaland County',
  country: 'Sweden',
  latitude: 57.7,
  longitude: 11.97,
);

Forecast _forecast({
  double temperature = 15.5,
  double feelsLike = 13.9,
  int code = 3,
  List<DayForecast>? days,
}) => Forecast(
  place: _place,
  now: Conditions(
    temperature: temperature,
    feelsLike: feelsLike,
    humidity: 86,
    code: code,
    windSpeed: 4.82,
    windDirection: 231,
    precipitation: 0,
  ),
  days:
      days ??
      [
        DayForecast(
          date: DateTime(2026, 9, 25),
          code: 51,
          low: 14,
          high: 16.6,
          precipitation: 0.5,
        ),
      ],
);

DayForecast _dry(double mm) => DayForecast(
  date: DateTime(2026, 9, 25),
  code: 3,
  low: 1,
  high: 2,
  precipitation: mm,
);

void main() {
  group('weatherKind', () {
    test('groups the WMO codes by how the sky looks', () {
      const expected = {
        0: WeatherKind.clear,
        1: WeatherKind.clear,
        2: WeatherKind.partlyCloudy,
        3: WeatherKind.cloudy,
        45: WeatherKind.fog,
        48: WeatherKind.fog,
        51: WeatherKind.drizzle,
        55: WeatherKind.drizzle,
        56: WeatherKind.drizzle,
        57: WeatherKind.drizzle,
        61: WeatherKind.rain,
        65: WeatherKind.rain,
        66: WeatherKind.rain,
        67: WeatherKind.rain,
        80: WeatherKind.rain,
        82: WeatherKind.rain,
        71: WeatherKind.snow,
        75: WeatherKind.snow,
        77: WeatherKind.snow,
        85: WeatherKind.snow,
        86: WeatherKind.snow,
        95: WeatherKind.thunder,
        96: WeatherKind.thunder,
        99: WeatherKind.thunder,
      };

      expected.forEach((code, kind) {
        expect(weatherKind(code), kind, reason: 'code $code');
      });
    });

    test('a code it does not know is cloud', () {
      expect(weatherKind(1234), WeatherKind.cloudy);
      expect(weatherKind(-1), WeatherKind.cloudy);
    });

    test('every kind is used by some code', () {
      final used = {for (var code = 0; code < 100; code++) weatherKind(code)};

      expect(used, WeatherKind.values.toSet());
    });
  });

  group('number text', () {
    test('wholeNumber rounds and never shows a minus zero', () {
      expect(wholeNumber(15.5), '16');
      expect(wholeNumber(-0.4), '0');
      expect(wholeNumber(-1.6), '-2');
    });

    test('oneDecimal keeps a tenth and drops a needless .0', () {
      expect(oneDecimal(4.62), '4.6');
      expect(oneDecimal(3.0), '3');
    });
  });

  group('weatherBlock', () {
    test('carries the place, the sky and the figures, rounded', () {
      final block = weatherBlock(_forecast());

      expect(block.place, 'Gothenburg, Västra Götaland County, Sweden');
      expect(block.note, isNull);
      expect(block.now.kind, WeatherKind.cloudy);
      expect(block.now.description, 'Overcast');
      expect(block.now.temperature, 16);
      expect(block.now.feelsLike, 14);
      expect(block.now.windSpeed, '4.8');
      expect(block.now.windPoint, 'SW');
      expect(block.now.humidity, 86);
    });

    test('a temperature just below zero rounds to 0, not -0', () {
      final block = weatherBlock(_forecast(temperature: -0.4, feelsLike: -3.5));

      expect(block.now.temperature, 0);
      expect('${block.now.temperature}°C', '0°C');
      expect(block.now.feelsLike, -4);
    });

    test('a note is passed on', () {
      final block = weatherBlock(_forecast(), note: Messages.weatherUsingHome);

      expect(block.note, Messages.weatherUsingHome);
    });

    test('the first day is Today, the others by weekday', () {
      final days = [
        for (var i = 0; i < 4; i++)
          DayForecast(
            date: DateTime(2026, 9, 25 + i),
            code: 3,
            low: 10,
            high: 12,
            precipitation: 0,
          ),
      ];

      final block = weatherBlock(_forecast(days: days));

      expect(block.days.map((d) => d.label), ['Today', 'Sat', 'Sun', 'Mon']);
    });

    test('a day has its low, high, sky and rain', () {
      final day = weatherBlock(_forecast()).days.single;

      expect(day.low, 14);
      expect(day.high, 17);
      expect(day.kind, WeatherKind.drizzle);
      expect(day.description, 'Light drizzle');
      expect(day.rain, '0.5');
    });

    test('next to no rain is not mentioned', () {
      expect(weatherBlock(_forecast(days: [_dry(0)])).days.single.rain, isNull);
      expect(
        weatherBlock(_forecast(days: [_dry(0.09)])).days.single.rain,
        isNull,
      );
      expect(
        weatherBlock(_forecast(days: [_dry(0.1)])).days.single.rain,
        '0.1',
      );
    });

    test('from the real Gothenburg forecast', () async {
      final fetcher = FakeHttpFetcher()
        ..route(
          'v1/forecast',
          File('test/fixtures/forecast_goteborg.json').readAsStringSync(),
        );
      final forecast = await Weather(
        fetcher: fetcher,
        store: InMemoryLocalStore(),
      ).forecast(_place);

      final block = weatherBlock(forecast);

      expect(block.now.temperature, 16);
      expect(block.days.map((d) => (d.label, d.low, d.high, d.rain)), [
        ('Today', 14, 17, '0.5'),
        ('Sat', 14, 17, '0.1'),
        ('Sun', 13, 18, null),
        ('Mon', 13, 17, '0.2'),
      ]);
    });
  });
}
