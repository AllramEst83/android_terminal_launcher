import 'dart:convert';
import 'dart:io';

import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/services/network_exception.dart';
import 'package:android_terminal_launcher/services/weather.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_http_fetcher.dart';
import '../fakes/in_memory_local_store.dart';

/// Real answers from Open-Meteo for Göteborg, saved as-is.
String _geocode() =>
    File('test/fixtures/geocode_goteborg.json').readAsStringSync();
String _forecast() =>
    File('test/fixtures/forecast_goteborg.json').readAsStringSync();

const _gothenburg = Place(
  name: 'Gothenburg',
  region: 'Västra Götaland County',
  country: 'Sweden',
  latitude: 57.70716,
  longitude: 11.96679,
);

class _Rig {
  _Rig() {
    fetcher
      ..route('geocoding-api', _geocode())
      ..route('v1/forecast', _forecast());
    weather = Weather(fetcher: fetcher, store: store);
  }

  final fetcher = FakeHttpFetcher();
  final store = InMemoryLocalStore();
  late final Weather weather;
}

Matcher _unreadable() => throwsA(
  isA<NetworkException>().having(
    (e) => e.message,
    'message',
    contains('could not read'),
  ),
);

void main() {
  group('find', () {
    test('asks the geocoder for the best match, in English', () async {
      final rig = _Rig();

      await rig.weather.find('Göteborg');

      final url = rig.fetcher.requests.single;
      expect(url.scheme, 'https');
      expect(url.host, 'geocoding-api.open-meteo.com');
      expect(url.path, '/v1/search');
      expect(url.queryParameters['name'], 'Göteborg');
      expect(url.queryParameters['count'], '1');
      expect(url.queryParameters['language'], 'en');
    });

    test('reads the real answer into a place', () async {
      final place = await _Rig().weather.find('Göteborg');

      expect(place?.name, 'Gothenburg');
      expect(place?.region, 'Västra Götaland County');
      expect(place?.country, 'Sweden');
      expect(place?.latitude, 57.70716);
      expect(place?.longitude, 11.96679);
    });

    test('the label names the region and country', () async {
      final place = await _Rig().weather.find('Göteborg');

      expect(place?.label, 'Gothenburg, Västra Götaland County, Sweden');
    });

    test('an answer with no results means no such place', () async {
      final rig = _Rig()
        ..fetcher.route('geocoding-api', '{"generationtime_ms":0.5}');

      expect(await rig.weather.find('zzzz'), isNull);
    });

    test('an empty list of results means no such place', () async {
      final rig = _Rig()..fetcher.route('geocoding-api', '{"results":[]}');

      expect(await rig.weather.find('zzzz'), isNull);
    });

    test('region and country are optional', () async {
      final rig = _Rig()
        ..fetcher.route(
          'geocoding-api',
          '{"results":[{"name":"Nowhere","latitude":1,"longitude":2}]}',
        );

      final place = await rig.weather.find('nowhere');

      expect(place?.label, 'Nowhere');
      expect(place?.latitude, 1);
    });

    test('a result missing coordinates is skipped for the next one', () async {
      final rig = _Rig()
        ..fetcher.route(
          'geocoding-api',
          '{"results":[{"name":"Broken"},{"name":"Fine","latitude":5.5,"longitude":6.5}]}',
        );

      expect((await rig.weather.find('x'))?.name, 'Fine');
    });

    test('results that are all unusable are an unreadable answer', () async {
      final rig = _Rig()
        ..fetcher.route('geocoding-api', '{"results":[{"name":"Broken"}]}');

      await expectLater(rig.weather.find('x'), _unreadable());
    });

    test('unexpected answers are reported', () async {
      for (final body in ['<html>', '[1]', '{"results":"none"}']) {
        final rig = _Rig()..fetcher.route('geocoding-api', body);

        await expectLater(rig.weather.find('x'), _unreadable(), reason: body);
      }
    });

    test('a network failure passes through', () async {
      const failure = NetworkException('offline');
      final rig = _Rig()..fetcher.route('geocoding-api', failure);

      await expectLater(rig.weather.find('x'), throwsA(same(failure)));
    });
  });

  group('forecast', () {
    test('asks for metric current conditions and daily figures', () async {
      final rig = _Rig();

      await rig.weather.forecast(_gothenburg);

      final url = rig.fetcher.requests.single;
      expect(url.host, 'api.open-meteo.com');
      expect(url.path, '/v1/forecast');
      expect(url.queryParameters['latitude'], '57.70716');
      expect(url.queryParameters['longitude'], '11.96679');
      expect(url.queryParameters['timezone'], 'auto');
      expect(url.queryParameters['wind_speed_unit'], 'ms');
      expect(url.queryParameters['forecast_days'], '5');
      expect(url.queryParameters['current'], contains('temperature_2m'));
      expect(url.queryParameters['current'], contains('wind_direction_10m'));
      expect(url.queryParameters['daily'], contains('temperature_2m_max'));
    });

    test('the number of days can be chosen', () async {
      final rig = _Rig();
      final weather = Weather(fetcher: rig.fetcher, store: rig.store, days: 3);

      await weather.forecast(_gothenburg);

      expect(rig.fetcher.requests.single.queryParameters['forecast_days'], '3');
    });

    test('reads the real answer: current conditions', () async {
      final forecast = await _Rig().weather.forecast(_gothenburg);

      expect(forecast.place, same(_gothenburg));
      expect(forecast.now.temperature, 15.5);
      expect(forecast.now.feelsLike, 13.9);
      expect(forecast.now.humidity, 86);
      expect(forecast.now.code, 3);
      expect(forecast.now.windSpeed, 4.8);
      expect(forecast.now.windDirection, 231);
      expect(forecast.now.precipitation, 0);
    });

    test('reads the real answer: each day, today first', () async {
      final forecast = await _Rig().weather.forecast(_gothenburg);

      expect(forecast.days, hasLength(4));
      expect(forecast.days.first.date, DateTime(2026, 9, 25));
      expect(forecast.days.map((d) => d.code), [51, 51, 3, 51]);
      expect(forecast.days.map((d) => d.high), [16.6, 16.8, 18.1, 16.9]);
      expect(forecast.days.map((d) => d.low), [14.0, 14.4, 13.4, 13.2]);
      expect(forecast.days.map((d) => d.precipitation), [0.5, 0.1, 0.0, 0.2]);
    });

    test('whole-number values are accepted where decimals are usual', () async {
      final body = jsonDecode(_forecast()) as Map<String, Object?>;
      (body['current'] as Map)['temperature_2m'] = 15;
      final rig = _Rig()..fetcher.route('v1/forecast', jsonEncode(body));

      expect((await rig.weather.forecast(_gothenburg)).now.temperature, 15.0);
    });

    test('unexpected answers are reported', () async {
      Map<String, Object?> real() =>
          jsonDecode(_forecast()) as Map<String, Object?>;
      final broken = <String, String>{
        'not JSON': '<html>',
        'not an object': '[1]',
        'no current': jsonEncode(real()..remove('current')),
        'no daily': jsonEncode(real()..remove('daily')),
        'a missing figure': jsonEncode(
          real()..['current'] = {'temperature_2m': 1},
        ),
        'lists of different length': jsonEncode(
          real()
            ..['daily'] = {
              ...(real()['daily'] as Map),
              'weather_code': [1],
            },
        ),
        'no days': jsonEncode(
          real()
            ..['daily'] = {
              'time': [],
              'weather_code': [],
              'temperature_2m_max': [],
              'temperature_2m_min': [],
              'precipitation_sum': [],
            },
        ),
        'a date that is not a date': jsonEncode(
          real()
            ..['daily'] = {
              ...(real()['daily'] as Map),
              'time': ['a', 'b', 'c', 'd'],
            },
        ),
        'text where a number belongs': jsonEncode(
          real()
            ..['current'] = {
              ...(real()['current'] as Map),
              'temperature_2m': 'warm',
            },
        ),
      };

      for (final entry in broken.entries) {
        final rig = _Rig()..fetcher.route('v1/forecast', entry.value);

        await expectLater(
          rig.weather.forecast(_gothenburg),
          _unreadable(),
          reason: entry.key,
        );
      }
    });

    test('a network failure passes through', () async {
      const failure = NetworkException('offline');
      final rig = _Rig()..fetcher.route('v1/forecast', failure);

      await expectLater(
        rig.weather.forecast(_gothenburg),
        throwsA(same(failure)),
      );
    });
  });

  group('home', () {
    test('is not set at first', () async {
      expect(await _Rig().weather.home(), isNull);
    });

    test('is remembered, including across a restart', () async {
      final rig = _Rig();
      await rig.weather.setHome(_gothenburg);

      final restarted = Weather(fetcher: rig.fetcher, store: rig.store);
      final home = await restarted.home();

      expect(home?.label, _gothenburg.label);
      expect(home?.latitude, _gothenburg.latitude);
      expect(home?.longitude, _gothenburg.longitude);
    });

    test('a place without region or country is remembered too', () async {
      final rig = _Rig();
      await rig.weather.setHome(
        const Place(name: 'X', latitude: 1, longitude: 2),
      );

      final home = await rig.weather.home();

      expect(home?.region, isNull);
      expect(home?.label, 'X');
    });

    test('can be replaced and cleared', () async {
      final rig = _Rig();
      await rig.weather.setHome(_gothenburg);
      await rig.weather.setHome(
        const Place(name: 'Malmö', latitude: 55.6, longitude: 13),
      );
      expect((await rig.weather.home())?.name, 'Malmö');

      await rig.weather.clearHome();

      expect(await rig.weather.home(), isNull);
    });

    test('a damaged saved home counts as not set', () async {
      final rig = _Rig();
      for (final bad in [
        'garbage',
        5,
        <String, Object>{'name': 'X'},
      ]) {
        await rig.store.write(Weather.homeKey, bad);

        expect(await rig.weather.home(), isNull, reason: '$bad');
      }
    });

    test('an unreadable store counts as not set', () async {
      final rig = _Rig()..store.failure = const LocalStoreException('locked');

      expect(await rig.weather.home(), isNull);
    });

    test('a store that cannot save reports it', () async {
      final rig = _Rig()
        ..store.failure = const LocalStoreException('disk full');

      await expectLater(
        rig.weather.setHome(_gothenburg),
        throwsA(isA<LocalStoreException>()),
      );
    });
  });

  group('Place', () {
    test('survives a JSON round trip', () {
      final back = Place.fromJson(_gothenburg.toJson());

      expect(back.label, _gothenburg.label);
      expect(back.latitude, _gothenburg.latitude);
    });

    test('rejects shapes it cannot read', () {
      expect(() => Place.fromJson('x'), throwsFormatException);
      expect(() => Place.fromJson({'name': 'X'}), throwsFormatException);
      expect(
        () => Place.fromJson({
          'name': 'X',
          'latitude': 1,
          'longitude': 2,
          'country': 5,
        }),
        throwsFormatException,
      );
    });
  });
}
