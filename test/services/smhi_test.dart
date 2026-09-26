import 'dart:io';

import 'package:android_terminal_launcher/services/network_exception.dart';
import 'package:android_terminal_launcher/services/smhi.dart';
import 'package:android_terminal_launcher/services/weather.dart';
import 'package:android_terminal_launcher/terminal/tools/weather_text.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_http_fetcher.dart';

/// Real answers from SMHI, saved as they came on 2026-09-26 at about 15:45 UTC
/// (the station lists cut down to the neighbourhood of Göteborg).
String _fixture(String name) =>
    File('test/fixtures/$name.json').readAsStringSync();

/// 17:50 in Sweden, an hour after the last measurement in the fixtures.
final _now = DateTime.utc(2026, 9, 26, 15, 50);

const _gothenburg = Place(
  name: 'Gothenburg',
  latitude: 57.70716,
  longitude: 11.96679,
);

class _Rig {
  _Rig({DateTime? now, this.days = 5}) {
    fetcher
      ..route('metfcst', _fixture('smhi_forecast_goteborg'))
      ..route('station-set/all', _fixture('smhi_obs_temperature'))
      ..route('parameter/4/station/71420', _fixture('smhi_obs_wind'))
      ..route('parameter/3/station/71420', _fixture('smhi_obs_direction'))
      ..route('parameter/6/station/71420', _fixture('smhi_obs_humidity'))
      ..route('parameter/1/station/71420', _fixture('smhi_obs_temperature_day'))
      ..route('parameter/7/station/71420', _fixture('smhi_obs_rain_day'));
    smhi = Smhi(fetcher: fetcher, days: days, clock: () => now ?? _now);
  }

  final int days;
  final fetcher = FakeHttpFetcher();
  late final Smhi smhi;

  Future<Forecast> forecast([Place place = _gothenburg]) =>
      smhi.forecast(place);

  Iterable<String> get asked => fetcher.requests.map((u) => u.toString());
}

/// A latest-day answer for one station with these `(UTC hour on the 26th,
/// value)` readings.
String _series(List<(int, String)> readings) {
  final values = [
    for (final (hour, value) in readings)
      '{"date":${DateTime.utc(2026, 9, 26, hour).millisecondsSinceEpoch},'
          '"value":"$value","quality":"G"}',
  ];
  return '{"value":[${values.join(',')}]}';
}

void main() {
  group('the request', () {
    test('asks the point forecast for the place, to four decimals', () async {
      final rig = _Rig();

      await rig.forecast();

      expect(
        rig.asked,
        contains(
          'https://opendata-download-metfcst.smhi.se/api/category/snow1g'
          '/version/1/geotype/point/lon/11.9668/lat/57.7072/data.json',
        ),
      );
    });

    test('asks the nearest station for its own figures', () async {
      final rig = _Rig();

      await rig.forecast();

      const base = 'https://opendata-download-metobs.smhi.se/api/version/1.0';
      expect(
        rig.asked,
        containsAll([
          '$base/parameter/1/station-set/all/period/latest-hour/data.json',
          '$base/parameter/4/station/71420/period/latest-hour/data.json',
          '$base/parameter/3/station/71420/period/latest-hour/data.json',
          '$base/parameter/6/station/71420/period/latest-hour/data.json',
          '$base/parameter/1/station/71420/period/latest-day/data.json',
          '$base/parameter/7/station/71420/period/latest-day/data.json',
        ]),
      );
    });
  });

  group('now, with a station near', () {
    test('is what the station measured, and says where', () async {
      final forecast = await _Rig().forecast();

      expect(forecast.source, 'SMHI');
      expect(forecast.station, 'Göteborg A, 2 km');
      expect(forecast.now.temperature, 16.3);
      expect(forecast.now.windSpeed, 3.6);
      expect(forecast.now.windDirection, 267);
      expect(forecast.now.humidity, 60);
    });

    test(
      'takes the sky and the rain from the forecast for this hour',
      () async {
        final forecast = await _Rig().forecast();

        expect(forecast.now.code, 0); // symbol 1, clear sky
        expect(forecast.now.precipitation, 0);
      },
    );

    test('has a feels-like worked out from the measurements', () async {
      final forecast = await _Rig().forecast();

      expect(forecast.now.feelsLike, closeTo(13.44, 0.01));
    });

    test('a station without a reading is passed over for one with', () async {
      // Angered, the nearest to this spot, has no temperature in the fixture.
      final rig = _Rig();
      rig.fetcher
        ..route('parameter/4/station/72420', _fixture('smhi_obs_wind'))
        ..route('parameter/3/station/72420', _fixture('smhi_obs_direction'))
        ..route('parameter/6/station/72420', _fixture('smhi_obs_humidity'))
        ..route(
          'parameter/1/station/72420',
          _fixture('smhi_obs_temperature_day'),
        )
        ..route('parameter/7/station/72420', _fixture('smhi_obs_rain_day'));

      final forecast = await rig.forecast(
        const Place(name: 'Angered', latitude: 57.8, longitude: 12.5),
      );

      expect(forecast.station, isNotNull);
      expect(forecast.station, isNot(contains('Angered')));
    });
  });

  group('now, without one', () {
    test('a place far from every station uses the forecast for the hour', () async {
      // Kiruna: the nearest station in the fixture is Abisko, about 60 km off.
      final rig = _Rig();

      final forecast = await rig.forecast(
        const Place(name: 'Kiruna', latitude: 67.85, longitude: 20.22),
      );

      expect(forecast.station, isNull);
      expect(forecast.now.temperature, 15.7);
      expect(forecast.now.windSpeed, 5.7);
      expect(forecast.now.windDirection, 272);
      expect(forecast.now.humidity, 67);
      expect(
        rig.asked.where((url) => url.contains('/station/')),
        isEmpty,
        reason: 'no station, so no questions about one',
      );
    });

    test('a measurement older than two hours is not now', () async {
      final forecast = await _Rig(now: DateTime.utc(2026, 9, 26, 17, 30))
          .forecast();

      expect(forecast.station, isNull);
    });

    test(
      'a station list that cannot be had leaves the forecast alone',
      () async {
        final rig = _Rig();
        rig.fetcher.route('station-set/all', const NetworkException('down'));

        final forecast = await rig.forecast();

        expect(forecast.station, isNull);
        expect(forecast.now.temperature, 15.7);
        expect(forecast.days, hasLength(5));
      },
    );

    test('a station list that makes no sense leaves it alone too', () async {
      final rig = _Rig();
      rig.fetcher.route('station-set/all', '{"station": 7}');

      expect((await rig.forecast()).station, isNull);
    });

    test('a figure the station lacks comes from the forecast', () async {
      final rig = _Rig();
      rig.fetcher.route(
        'parameter/4/station/71420',
        const NetworkException('no wind here'),
      );

      final forecast = await rig.forecast();

      expect(forecast.now.temperature, 16.3, reason: 'still measured');
      expect(forecast.now.windSpeed, 5.7, reason: 'forecast stands in');
      expect(forecast.now.windDirection, 267);
    });
  });

  group('the days', () {
    test('are five, today first, on Sweden\'s calendar', () async {
      final forecast = await _Rig().forecast();

      expect(
        [for (final day in forecast.days) day.date.day],
        [26, 27, 28, 29, 30],
      );
      expect(forecast.days.first.date.weekday, DateTime.saturday);
    });

    test('the number of days can be chosen', () async {
      final forecast = await _Rig(days: 3).forecast();

      expect(forecast.days, hasLength(3));
    });

    test('have the lowest and highest reading of the day', () async {
      final days = (await _Rig().forecast()).days;

      expect(days[1].low, 12.9);
      expect(days[1].high, 17.6);
      expect(days[2].low, 13.4);
      expect(days[2].high, 16.4);
      expect(days[4].low, 13.3);
      expect(days[4].high, 19.9);
    });

    test('add up the rain that falls in each', () async {
      final days = (await _Rig().forecast()).days;

      expect(
        [for (final day in days) day.precipitation],
        [0, 0, closeTo(0.7, 1e-9), closeTo(0.7, 1e-9), 0],
      );
    });

    test('are named by their commonest daytime sky', () async {
      final days = (await _Rig().forecast()).days;

      // Clear most of the 27th, overcast on the 28th.
      expect(days[1].code, 0);
      expect(days[2].code, 3);
      expect(describeWeather(days[1].code), 'Clear sky');
    });

    test(
      'today also counts what the station measured since midnight',
      () async {
        final today = (await _Rig().forecast()).days.first;

        // The forecast holds only the evening: 13.5 to 15.7. The station had
        // reached 16.4 by the afternoon.
        expect(today.low, 13.5);
        expect(today.high, 16.4);
      },
    );

    test('today also counts the rain that has fallen', () async {
      final rig = _Rig();
      rig.fetcher.route(
        'parameter/7/station/71420',
        _series([(3, '0.4'), (9, '0.6'), (12, '0.0')]),
      );

      final today = (await rig.forecast()).days.first;

      expect(today.precipitation, closeTo(1.0, 1e-9));
      expect(weatherKind(today.code), isNot(isNull));
    });

    test('a wet day is wet even when most of its hours were dry', () async {
      // Two rainy hours (symbol 19, moderate rain) among many clear ones.
      final points = [
        for (var hour = 0; hour < 24; hour++)
          '{"time":"2026-10-01T${hour.toString().padLeft(2, '0')}:00:00Z",'
              '"intervalParametersStartTime":'
              '"${hour == 0 ? '2026-09-30T23' : '2026-10-01T${(hour - 1).toString().padLeft(2, '0')}'}:00:00Z",'
              '"data":{"air_temperature":10,"wind_speed":2,'
              '"wind_from_direction":90,"relative_humidity":50,"symbol_code":${hour == 10 || hour == 11 ? 19 : 1},'
              '"precipitation_amount_mean":${hour == 10 || hour == 11 ? 0.8 : 0}}}',
      ];
      final rig = _Rig(days: 1, now: DateTime.utc(2026, 10, 1, 0, 30));
      rig.fetcher
        ..route('metfcst', '{"timeSeries":[${points.join(',')}]}')
        ..route('station-set/all', const NetworkException('offline'));

      final day = (await rig.forecast()).days.single;

      expect(day.precipitation, closeTo(1.6, 1e-9));
      expect(day.code, 63, reason: 'moderate rain, though 22 hours were clear');
    });
  });

  group('when it cannot answer', () {
    test('out of its area is a network error, for the fallback', () async {
      final rig = _Rig();
      rig.fetcher.route(
        'metfcst',
        const NetworkException(
          'opendata-download-metfcst.smhi.se answered with status 404',
        ),
      );

      await expectLater(rig.forecast(), throwsA(isA<NetworkException>()));
    });

    test('an answer it cannot read is a network error saying so', () async {
      for (final body in ['nope', '{}', '{"timeSeries":[]}', '[1]']) {
        final rig = _Rig();
        rig.fetcher.route('metfcst', body);

        await expectLater(
          rig.forecast(),
          throwsA(
            isA<NetworkException>().having(
              (e) => e.message,
              'message',
              contains('could not read'),
            ),
          ),
          reason: body,
        );
      }
    });

    test(
      'a forecast with a point that has no temperature still reads',
      () async {
        final rig = _Rig(now: DateTime.utc(2026, 9, 26, 17));
        rig.fetcher.route(
          'metfcst',
          '{"timeSeries":['
              '{"time":"2026-09-26T16:00:00Z","data":{"symbol_code":1}},'
              '{"time":"2026-09-26T17:00:00Z","data":{"air_temperature":9,'
              '"wind_speed":2,"wind_from_direction":90,"relative_humidity":50,'
              '"symbol_code":3}}]}',
        );
        rig.fetcher.route('station-set/all', const NetworkException('offline'));

        final forecast = await rig.forecast();

        expect(forecast.days.single.low, 9);
      },
    );
  });

  group('swedishClock', () {
    test('is an hour ahead of UTC in winter', () {
      expect(
        swedishClock(DateTime.utc(2026, 1, 15, 12)),
        DateTime.utc(2026, 1, 15, 13),
      );
    });

    test('is two hours ahead in summer', () {
      expect(
        swedishClock(DateTime.utc(2026, 7, 1, 12)),
        DateTime.utc(2026, 7, 1, 14),
      );
    });

    test('changes at 01:00 UTC on the last Sunday of March', () {
      expect(
        swedishClock(DateTime.utc(2026, 3, 29, 0, 59)),
        DateTime.utc(2026, 3, 29, 1, 59),
      );
      expect(
        swedishClock(DateTime.utc(2026, 3, 29, 1)),
        DateTime.utc(2026, 3, 29, 3),
      );
    });

    test('changes back at 01:00 UTC on the last Sunday of October', () {
      expect(
        swedishClock(DateTime.utc(2026, 10, 25, 0, 59)),
        DateTime.utc(2026, 10, 25, 2, 59),
      );
      expect(
        swedishClock(DateTime.utc(2026, 10, 25, 1)),
        DateTime.utc(2026, 10, 25, 2),
      );
    });

    test('moves the date when the clock passes midnight', () {
      expect(
        swedishClock(DateTime.utc(2026, 9, 26, 22, 30)),
        DateTime.utc(2026, 9, 27, 0, 30),
      );
    });

    test('takes any kind of DateTime', () {
      expect(
        swedishClock(DateTime.utc(2026, 1, 15, 12).toLocal()),
        DateTime.utc(2026, 1, 15, 13),
      );
    });
  });

  group('apparentTemperature', () {
    test('is the temperature in still, dry, mild air, less a little', () {
      expect(
        apparentTemperature(temperature: 20, humidity: 0, windSpeed: 0),
        20 - 4,
      );
    });

    test('is lower in wind and higher in humid air', () {
      const base = 15.0;
      final calm = apparentTemperature(
        temperature: base,
        humidity: 50,
        windSpeed: 0,
      );

      expect(
        apparentTemperature(temperature: base, humidity: 50, windSpeed: 8),
        lessThan(calm),
      );
      expect(
        apparentTemperature(temperature: base, humidity: 90, windSpeed: 0),
        greaterThan(calm),
      );
    });
  });

  test('distanceKm is about 400 from Göteborg to Stockholm', () {
    expect(distanceKm(57.7089, 11.9746, 59.3293, 18.0686), closeTo(397, 5));
    expect(distanceKm(57.7, 12, 57.7, 12), 0);
  });

  group('smhiToWmo', () {
    test('gives every symbol a code that has words', () {
      for (var symbol = 1; symbol <= 27; symbol++) {
        final code = smhiToWmo(symbol);
        expect(
          describeWeather(code),
          isNot(startsWith('Weather ')),
          reason: 'symbol $symbol -> $code',
        );
      }
    });

    test('keeps the kinds of weather apart', () {
      expect(smhiToWmo(1), 0); // clear
      expect(smhiToWmo(6), 3); // overcast
      expect(smhiToWmo(7), 45); // fog
      expect(smhiToWmo(11), 95); // thunder
      expect(smhiToWmo(19), 63); // moderate rain
      expect(smhiToWmo(26), 73); // moderate snow
      expect(weatherKind(smhiToWmo(23)), weatherKind(73), reason: 'sleet');
    });

    test('takes what it does not know for overcast', () {
      expect(smhiToWmo(0), 3);
      expect(smhiToWmo(99), 3);
    });
  });
}
