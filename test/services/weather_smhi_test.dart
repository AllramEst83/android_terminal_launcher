import 'dart:io';

import 'package:android_terminal_launcher/services/network_exception.dart';
import 'package:android_terminal_launcher/services/weather.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_http_fetcher.dart';
import '../fakes/in_memory_local_store.dart';

const _place = Place(name: 'Somewhere', latitude: 10, longitude: 20);

Forecast _from(String source) => Forecast(
  place: _place,
  source: source,
  now: const Conditions(
    temperature: 1,
    feelsLike: 1,
    humidity: 1,
    code: 0,
    windSpeed: 1,
    windDirection: 1,
    precipitation: 0,
  ),
  days: const [],
);

class _Preferred implements ForecastSource {
  _Preferred(this.answer);

  /// A [Forecast] to give or an exception to throw.
  final Object answer;
  final asked = <Place>[];

  @override
  Future<Forecast> forecast(Place place) async {
    asked.add(place);
    final result = answer;
    if (result is Forecast) return result;
    throw result;
  }
}

void main() {
  late FakeHttpFetcher fetcher;
  setUp(() {
    fetcher = FakeHttpFetcher()
      ..route(
        'v1/forecast',
        File('test/fixtures/forecast_goteborg.json').readAsStringSync(),
      );
  });

  Weather weather(ForecastSource? preferred) => Weather(
    fetcher: fetcher,
    store: InMemoryLocalStore(),
    preferred: preferred,
  );

  test('with none, the forecast is Open-Meteo\'s, and says so', () async {
    final forecast = await weather(null).forecast(_place);

    expect(forecast.source, 'Open-Meteo');
    expect(forecast.station, isNull);
  });

  test(
    'a preferred source that answers is used, and Open-Meteo is not asked',
    () async {
      final preferred = _Preferred(_from('SMHI'));

      final forecast = await weather(preferred).forecast(_place);

      expect(forecast.source, 'SMHI');
      expect(preferred.asked, [_place]);
      expect(fetcher.requests, isEmpty);
    },
  );

  test('one that cannot answer hands over to Open-Meteo', () async {
    final preferred = _Preferred(const NetworkException('out of bounds'));

    final forecast = await weather(preferred).forecast(_place);

    expect(preferred.asked, hasLength(1));
    expect(forecast.source, 'Open-Meteo');
    expect(forecast.days, isNotEmpty);
  });

  test('a 404 is just out of area: no problem is recorded', () async {
    final preferred = _Preferred(
      const NetworkException('out of bounds', statusCode: 404),
    );

    final forecast = await weather(preferred).forecast(_place);

    expect(forecast.source, 'Open-Meteo');
    expect(forecast.problem, isNull);
  });

  test('any other failure is recorded on the fallback forecast', () async {
    final preferred = _Preferred(
      const NetworkException('smhi.se did not answer in time'),
    );

    final forecast = await weather(preferred).forecast(_place);

    expect(forecast.source, 'Open-Meteo');
    expect(forecast.problem, 'smhi.se did not answer in time');
    expect(forecast.days, isNotEmpty, reason: 'the fallback still answered');
  });

  test('a 5xx is a problem, not an out-of-area', () async {
    final preferred = _Preferred(
      const NetworkException(
        'smhi.se answered with status 503',
        statusCode: 503,
      ),
    );

    expect((await weather(preferred).forecast(_place)).problem, isNotNull);
  });

  test('a forecast that never had a problem has none', () async {
    expect((await weather(null).forecast(_place)).problem, isNull);
    expect(
      (await weather(_Preferred(_from('SMHI'))).forecast(_place)).problem,
      isNull,
    );
  });

  test('if Open-Meteo fails too, that is the error reported', () async {
    fetcher.route('v1/forecast', const NetworkException('open-meteo is down'));
    final preferred = _Preferred(const NetworkException('smhi is down'));

    await expectLater(
      weather(preferred).forecast(_place),
      throwsA(
        isA<NetworkException>().having(
          (e) => e.message,
          'message',
          'open-meteo is down',
        ),
      ),
    );
  });

  test('a bug in the preferred source is not hidden by the fallback', () async {
    final preferred = _Preferred(StateError('bug'));

    await expectLater(
      weather(preferred).forecast(_place),
      throwsA(isA<StateError>()),
    );
    expect(fetcher.requests, isEmpty);
  });
}
